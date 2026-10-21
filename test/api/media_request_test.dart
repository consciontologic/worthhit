import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:worthhit/api/open_router_client.dart';

import '../domain/product_media_test.dart' as media;
import 'open_router_client_test.dart' as fixture;

Map<String, dynamic> model({
  String id = 'vendor/test:free',
  List<String> input = const ['text', 'image', 'video'],
  Map<String, dynamic>? pricing,
}) => fixture.modelJson(id: id, pricing: pricing)
  ..['architecture'] = {
    'input_modalities': input,
    'output_modalities': ['text'],
  }
  ..['description'] = 'A product vision model.'
  ..['top_provider'] = {'max_completion_tokens': 2048};

void main() {
  test(
    'catalog capabilities and output limit survive cache with guarded media',
    () async {
      final client = OpenRouterClient(
        clientFactory: () =>
            MockClient((_) async => fixture.catalog([model()])),
      );
      final restored = OpenRouterClient();
      addTearDown(client.dispose);
      addTearDown(restored.dispose);
      final selected = (await client.refreshCatalog()).models.single;
      expect(selected.acceptsImages, isTrue);
      expect(selected.acceptsVideo, isTrue);
      expect(selected.allowedMediaMimeTypes, {
        'image/png',
        'image/jpeg',
        'image/webp',
        'image/gif',
        'video/mp4',
      });
      expect(selected.maxCompletionTokens, 2048);
      expect(selected.description, 'A product vision model.');
      restored.seedCatalog(client.exportCatalog()!);
      expect(
        restored.snapshot!.models.single.capabilitySignature,
        selected.capabilitySignature,
      );
      expect(() => selected.inputModalities.clear(), throwsUnsupportedError);
    },
  );

  test(
    'optional paid or unresolved media does not authorize attachments',
    () async {
      for (final price in ['0.1', '-1', '1e-999']) {
        final client = OpenRouterClient(
          clientFactory: () => MockClient(
            (_) async => fixture.catalog([
              model(
                pricing: {'prompt': '0', 'completion': '0', 'image': price},
              ),
            ]),
          ),
        );
        addTearDown(client.dispose);
        final selected = (await client.refreshCatalog()).models.single;
        expect(selected.acceptsImages, isFalse);
        expect(selected.acceptsVideo, isFalse);
        expect(selected.mediaUnavailableReason('image'), isNotNull);
      }
    },
  );

  test('video requires a genuine free variant and text-only output', () async {
    final client = OpenRouterClient(
      clientFactory: () => MockClient(
        (_) async => fixture.catalog([
          model(id: 'vendor/no-suffix'),
          model(id: 'vendor/mixed:free')
            ..['architecture'] = {
              'input_modalities': ['text', 'image'],
              'output_modalities': ['text', 'image'],
            },
        ]),
      ),
    );
    addTearDown(client.dispose);
    final selected = (await client.refreshCatalog()).models.single;
    expect(selected.id, 'vendor/no-suffix');
    expect(selected.acceptsImages, isTrue);
    expect(selected.acceptsVideo, isFalse);
  });

  test(
    'malformed optional media prices are quarantined and never treated as zero',
    () async {
      final client = OpenRouterClient(
        clientFactory: () => MockClient(
          (_) async => fixture.catalog([
            model(),
            model(
              id: 'vendor/bad:free',
              pricing: {'prompt': '0', 'completion': '0', 'image': 0},
            ),
            model(
              id: 'vendor/bad2:free',
              pricing: {'prompt': '0', 'completion': '0', 'video': 'free'},
            ),
          ]),
        ),
      );
      addTearDown(client.dispose);
      expect((await client.refreshCatalog()).models.map((m) => m.id), [
        'vendor/test:free',
      ]);
    },
  );

  test(
    'request appends local media only to final user turn with zero price caps',
    () async {
      Map<String, dynamic>? body;
      var posts = 0;
      final client = OpenRouterClient(
        clientFactory: () => MockClient((request) async {
          if (request.method == 'GET') return fixture.catalog([model()]);
          posts++;
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return fixture.completion();
        }),
      );
      addTearDown(client.dispose);
      final selected = (await client.refreshCatalog()).models.single;
      final photo = media.image(length: 256 * 1024);
      final clip = media.video();
      await client.complete(
        apiKey: 'test-key',
        model: selected,
        messages: fixture.messages,
        schema: fixture.schema,
        attachments: [photo, clip],
      );
      expect(posts, 1);
      expect(body!['model'], selected.id);
      final messages = body!['messages'] as List;
      expect(messages.first['content'], fixture.messages.first['content']);
      expect(messages.last['content'], [
        {'type': 'text', 'text': fixture.messages.last['content']},
        photo.toContentPart(),
        clip.toContentPart(),
      ]);
      expect(body!['provider']['allow_fallbacks'], false);
      expect(body!['provider']['max_price'], containsPair('image', 0));
      expect(body!['provider']['max_price'], containsPair('request', 0));
      expect(body!['max_tokens'], 2048);
      expect(body!.containsKey('plugins'), false);
      expect(body!.containsKey('tools'), false);
    },
  );

  test(
    'incompatible capability changes and oversized text reject before POST',
    () async {
      var changed = false;
      var posts = 0;
      final client = OpenRouterClient(
        clientFactory: () => MockClient((request) async {
          if (request.method == 'GET') {
            return fixture.catalog([
              model(input: changed ? ['text'] : ['text', 'image', 'video']),
            ]);
          }
          posts++;
          return fixture.completion();
        }),
      );
      addTearDown(client.dispose);
      final original = (await client.refreshCatalog()).models.single;
      changed = true;
      final current = (await client.refreshCatalog()).models.single;
      for (final selected in [original, current]) {
        await expectLater(
          client.complete(
            apiKey: 'test-key',
            model: selected,
            messages: fixture.messages,
            schema: fixture.schema,
            attachments: [media.image()],
          ),
          throwsA(fixture.failure(ApiFailureKind.policy)),
        );
      }
      await expectLater(
        client.complete(
          apiKey: 'test-key',
          model: current,
          messages: [
            {'role': 'user', 'content': 'x' * (128 * 1024)},
          ],
          schema: fixture.schema,
        ),
        throwsA(fixture.failure(ApiFailureKind.schema)),
      );
      expect(posts, 0);
    },
  );

  test(
    'attachment limits and non-user final turns reject before POST',
    () async {
      var posts = 0;
      final client = OpenRouterClient(
        clientFactory: () => MockClient((request) async {
          if (request.method == 'GET') return fixture.catalog([model()]);
          posts++;
          return fixture.completion();
        }),
      );
      addTearDown(client.dispose);
      final selected = (await client.refreshCatalog()).models.single;
      await expectLater(
        client.complete(
          apiKey: 'test-key',
          model: selected,
          messages: fixture.messages,
          schema: fixture.schema,
          attachments: List.generate(5, (_) => media.image()),
        ),
        throwsA(fixture.failure(ApiFailureKind.policy)),
      );
      await expectLater(
        client.complete(
          apiKey: 'test-key',
          model: selected,
          messages: [
            {'role': 'system', 'content': 'Product'},
          ],
          schema: fixture.schema,
          attachments: [media.image()],
        ),
        throwsA(fixture.failure(ApiFailureKind.schema)),
      );
      expect(posts, 0);
    },
  );
}
