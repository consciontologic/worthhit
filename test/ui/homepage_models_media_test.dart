import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/api/open_router_client.dart';
import 'package:worthhit/app/app_controller.dart';
import 'package:worthhit/domain/product_media.dart';
import 'package:worthhit/platform/media_picker.dart';
import 'package:worthhit/ui/worthhit_app.dart';

class _Picker implements MediaPicker {
  Set<String>? accepted;
  @override
  Future<List<ProductMedia>> pick({
    required Set<String> allowedMimeTypes,
    int existingCount = 0,
    int existingBytes = 0,
  }) async {
    accepted = allowedMimeTypes;
    final video = allowedMimeTypes.contains('video/mp4');
    return [
      ProductMedia.fromBytes(
        name: video ? 'item.mp4' : 'item.png',
        mimeType: video ? 'video/mp4' : 'image/png',
        bytes: video
            ? Uint8List.fromList([
                0,
                0,
                0,
                16,
                102,
                116,
                121,
                112,
                105,
                115,
                111,
                109,
                0,
                0,
                0,
                0,
              ])
            : base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/RZkAAAAASUVORK5CYII=',
              ),
      ),
    ];
  }

  @override
  void cancel() {}
  @override
  void dispose() {}
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    AppController controller, {
    double scale = 1,
    double width = 390,
    double height = 900,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(controller.dispose);
    await tester.pumpWidget(WorthhitApp(controller: controller));
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('homepage model dropdown is usable at 320px and $scale scale', (
      tester,
    ) async {
      final controller = AppController()
        ..models = [
          ModelInfo(id: 'test/text', name: 'Text only', contextLength: 8192),
          ModelInfo(
            id: 'test/media:free',
            name: 'Photo and video model',
            inputModalities: ['text', 'image', 'video'],
            supportedParameters: ['tools'],
            contextLength: 32768,
            maxCompletionTokens: 2048,
          ),
        ];
      await mount(tester, controller, width: 320, height: 568, scale: scale);
      await tester.enterText(
        find.byKey(const ValueKey('product-field')),
        'Keep my camera',
      );
      await tester.tap(find.byKey(const ValueKey('homepage-models')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a free model'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('model-search')),
        'Photo',
      );
      await tester.pumpAndSettle();
      expect(find.text('Images supported'), findsOneWidget);
      expect(find.text('Video supported'), findsOneWidget);
      final choice = find.text('Photo and video model');
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(controller.selectedModel?.id, 'test/media:free');
      expect(controller.draft.product, 'Keep my camera');
      expect(find.text('Choose a free model'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'media buttons and paid research follow actual model capabilities',
    (tester) async {
      final picker = _Picker();
      final controller = AppController(mediaPicker: picker);
      await mount(tester, controller);
      final image = find.byKey(const ValueKey('add-image'));
      final video = find.byKey(const ValueKey('add-video'));
      expect(tester.widget<OutlinedButton>(image).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(video).onPressed, isNull);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('web-search-toggle')),
            )
            .onChanged,
        isNull,
      );
      controller.selectModel(
        ModelInfo(
          id: 'test/image',
          name: 'Image',
          inputModalities: ['text', 'image'],
          supportedParameters: ['tools'],
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(image);
      await tester.tap(image);
      await tester.pumpAndSettle();
      expect(picker.accepted, productImageMimeTypes);
      expect(controller.attachments.single.name, 'item.png');
      expect(tester.widget<OutlinedButton>(video).onPressed, isNull);
      expect(controller.webSearch, isFalse);
      final toggle = find.byKey(const ValueKey('web-search-toggle'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(controller.webSearch, isTrue);
      expect(find.textContaining('search fees'), findsWidgets);
      controller.selectModel(
        ModelInfo(
          id: 'test/media:free',
          name: 'Media',
          inputModalities: ['text', 'image', 'video'],
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(video);
      await tester.tap(video);
      await tester.pumpAndSettle();
      expect(picker.accepted, {'video/mp4'});
      expect(controller.attachments, hasLength(2));
      controller.selectModel(ModelInfo(id: 'test/text', name: 'Text'));
      await tester.pumpAndSettle();
      expect(controller.attachments, hasLength(2));
      expect(tester.widget<OutlinedButton>(image).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(video).onPressed, isNull);
      await tester.ensureVisible(find.byTooltip('Remove item.png'));
      await tester.tap(find.byTooltip('Remove item.png'));
      await tester.pumpAndSettle();
      expect(controller.attachments.single.name, 'item.mp4');
      expect(tester.takeException(), isNull);
    },
  );
}
