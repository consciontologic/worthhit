import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/api/open_router_client.dart';
import 'package:worthhit/app/app_controller.dart';
import 'package:worthhit/domain/appraisal.dart';
import 'package:worthhit/domain/product_media.dart';
import 'package:worthhit/platform/local_store.dart';
import 'package:worthhit/platform/media_picker.dart';

import 'app_controller_test.dart' show DownloadStore, FakeApi;
import 'domain/appraisal_v2_test.dart' show estimatedResponse;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ProductMedia photo() => ProductMedia.fromBytes(
    id: 'test-image',
    name: 'secret-camera.png',
    mimeType: 'image/png',
    bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
  );
  final visualModel = ModelInfo(
    id: 'fixture/model:free',
    name: 'Visual',
    inputModalities: ['text', 'image'],
    supportedParameters: ['structured_outputs', 'tools'],
  );
  AppController create({FakePicker? picker, FakeApi? api, MemoryStore? store}) {
    final client = api ?? FakeApi();
    client.responseContent = jsonEncode(estimatedResponse());
    return AppController(
        api: client,
        store: store ?? MemoryStore(),
        mediaPicker: picker,
      )
      ..updateDraft(
        AppraisalInput(
          product: 'Test camera',
          condition: 'Good',
          currency: 'USD',
          details: 'No packaging.',
        ),
      )
      ..setApiKey('synthetic-key')
      ..selectModel(visualModel);
  }

  test(
    'simple request estimates without manual evidence or paid search',
    () async {
      final api = FakeApi();
      final controller = create(api: api);
      addTearDown(controller.dispose);
      await controller.appraise();
      expect(api.completionCalls, 1);
      expect(api.capturedWebSearch, isFalse);
      expect(api.capturedSchema!['properties']['version']['enum'], [
        'worthit.v2',
      ]);
      expect(controller.result?.status, AppraisalStatus.estimated);
      expect(controller.result?.median, 160);
      expect(controller.error, isNull);
      expect(
        api.capturedMessages!.first['content'],
        contains('No live web search'),
      );
    },
  );

  test(
    'hidden legacy anchors and evidence never enter the new user prompt',
    () async {
      final api = FakeApi();
      final controller = create(api: api);
      addTearDown(controller.dispose);
      controller.updateDraft(
        controller.draft.copyWith(
          location: 'HIDDEN-MARKET',
          evidence: 'HIDDEN-EVIDENCE',
          askingPrice: 98765,
        ),
      );
      await controller.appraise();
      final prompt = api.capturedMessages!.last['content'] as String;
      expect(prompt, isNot(contains('HIDDEN')));
      expect(prompt, isNot(contains('98765')));
      expect(prompt, contains('No packaging.'));
      expect(
        controller.draft.evidence,
        'HIDDEN-EVIDENCE',
        reason: 'Legacy data is retained, not silently erased.',
      );
    },
  );

  test(
    'new requests reject legacy response schemas instead of downgrading',
    () async {
      final api = FakeApi();
      final controller = create(api: api);
      addTearDown(controller.dispose);
      api.responseContent = jsonEncode(
        {
          ...estimatedResponse(status: 'insufficient_evidence'),
          'version': 'worthit.v1',
        }..remove('estimate'),
      );
      await controller.appraise();
      expect(controller.result, isNull);
      expect(controller.error, contains('invalid or unsupported appraisal'));
      expect(controller.store.read('worthit.last-report.v1'), isNull);
    },
  );

  test('export clearly identifies an unverified model estimate', () async {
    final store = DownloadStore();
    final controller = create(store: store);
    addTearDown(controller.dispose);
    await controller.appraise();
    await controller.exportReport();
    final report = jsonDecode(store.lastDownload!) as Map<String, dynamic>;
    expect(report['notice'], contains('model-based estimate'));
    expect(report['notice'], contains('not verified against current sales'));
    expect(report['notice'], isNot(contains('estimate from evidence')));
  });

  test(
    'editing a synthetic example starts a real request with no fake sources',
    () async {
      final api = FakeApi();
      final controller = create(api: api);
      addTearDown(controller.dispose);
      await controller.loadExample();
      controller.updateDraft(
        controller.draft.copyWith(product: 'Test camera', currency: 'USD'),
      );
      expect(controller.isExample, isFalse);
      expect(controller.draft.evidence, isEmpty);
      await controller.appraise();
      expect(api.completionCalls, 1);
      expect(
        api.capturedMessages!.last['content'],
        isNot(contains('synthetic-lamp')),
      );
    },
  );

  test('media is sent once, stays in this tab and is not serialized', () async {
    final file = photo();
    final picker = FakePicker()..files = [file];
    final api = FakeApi();
    final store = MemoryStore();
    final controller = create(picker: picker, api: api, store: store);
    addTearDown(controller.dispose);
    await controller.pickMedia(allowedMimeTypes: {'image/png'});
    expect(controller.attachments, [file]);
    expect(picker.allowed, {'image/png'});
    await controller.appraise();
    expect(api.capturedAttachments, [file]);
    expect(controller.attachments, [file]);
    expect(store.values.values.join(), isNot(contains(file.base64Data)));
    expect(store.values.values.join(), isNot(contains(file.name)));
    expect(controller.resultUsedMedia, isTrue);
    final restored = AppController(api: FakeApi(), store: store);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.attachments, isEmpty);
    expect(restored.resultUsedMedia, isTrue);
    expect(restored.webSearch, isFalse);
  });

  test(
    'incompatible model refuses before dispatch and preserves files',
    () async {
      final file = photo();
      final api = FakeApi();
      final controller = create(api: api, picker: FakePicker()..files = [file]);
      addTearDown(controller.dispose);
      await controller.pickMedia();
      controller.selectModel(api.model);
      await controller.appraise();
      expect(api.completionCalls, 0);
      expect(controller.error, contains('attached'));
      expect(controller.attachments, [file]);
    },
  );

  test('late picker result cannot restore files after a new draft', () async {
    final picker = FakePicker()..pending = Completer<List<ProductMedia>>();
    final controller = create(picker: picker);
    addTearDown(controller.dispose);
    final pending = controller.pickMedia();
    expect(controller.pickingMedia, isTrue);
    controller.clearDraft();
    picker.pending!.complete([photo()]);
    await pending;
    expect(controller.attachments, isEmpty);
    expect(controller.pickingMedia, isFalse);
    expect(picker.cancellations, greaterThan(0));
  });

  test(
    'pending media blocks appraisal and model switch invalidates picker',
    () async {
      final picker = FakePicker()..pending = Completer<List<ProductMedia>>();
      final api = FakeApi();
      final controller = create(picker: picker, api: api);
      addTearDown(controller.dispose);
      final pending = controller.pickMedia();
      await controller.appraise();
      expect(api.completionCalls, 0);
      expect(controller.error, contains('loading'));
      controller.selectModel(api.model);
      picker.pending!.complete([photo()]);
      await pending;
      expect(controller.attachments, isEmpty);
      expect(controller.pickingMedia, isFalse);
    },
  );

  test(
    'picker failure preserves prior media and reveals a safe error',
    () async {
      final picker = FakePicker()..files = [photo()];
      final controller = create(picker: picker);
      addTearDown(controller.dispose);
      await controller.pickMedia();
      picker.failure = const MediaFailure(
        'The selected files could not be read.',
      );
      await controller.pickMedia();
      expect(controller.attachments.length, 1);
      expect(controller.mediaError, 'The selected files could not be read.');
      controller.removeMedia(controller.attachments.single.id);
      expect(controller.attachments, isEmpty);
      expect(controller.mediaError, isNull);
    },
  );
}

class FakePicker implements MediaPicker {
  List<ProductMedia> files = [];
  Set<String>? allowed;
  Completer<List<ProductMedia>>? pending;
  MediaFailure? failure;
  int cancellations = 0;
  @override
  Future<List<ProductMedia>> pick({
    required Set<String> allowedMimeTypes,
    int existingCount = 0,
    int existingBytes = 0,
  }) async {
    allowed = allowedMimeTypes;
    if (failure != null) throw failure!;
    return pending == null ? files : await pending!.future;
  }

  @override
  void cancel() {
    cancellations++;
  }

  @override
  void dispose() {}
}
