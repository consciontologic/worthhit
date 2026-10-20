import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worthhit/api/open_router_client.dart';

Map<String, dynamic> modelJson({
  String id = 'vendor/test:free',
  Map<String, dynamic>? pricing,
  List<String> parameters = const ['structured_outputs', 'tools'],
}) => {
  'id': id,
  'name': 'Test model',
  'context_length': 8192,
  'architecture': {
    'input_modalities': ['text'],
    'output_modalities': ['text'],
  },
  'supported_parameters': parameters,
  'pricing': pricing ?? {'prompt': '0', 'completion': '0', 'request': '0'},
};

http.Response catalog(List<Object?> models, {Object? links}) =>
    http.Response(jsonEncode({'data': models, 'links': ?links}), 200);

http.Response completion({
  String actualModel = 'vendor/test:free',
  Object? content = '{"status":"insufficient_evidence"}',
  String finishReason = 'stop',
  List<Object?>? annotations,
  Object? toolCalls,
}) => http.Response(
  jsonEncode({
    'model': actualModel,
    'choices': [
      {
        'finish_reason': finishReason,
        'message': {
          'content': content,
          'annotations': ?annotations,
          'tool_calls': ?toolCalls,
        },
      },
    ],
  }),
  200,
);

const messages = [
  {'role': 'system', 'content': 'Appraise using the supplied evidence.'},
  {'role': 'user', 'content': 'Second-hand chair.'},
];
const schema = {
  'type': 'object',
  'properties': {
    'status': {'type': 'string'},
  },
  'required': ['status'],
  'additionalProperties': false,
};

TypeMatcher<ApiFailure> failure(ApiFailureKind kind) => isA<ApiFailure>()
    .having((e) => e.kind, 'kind', kind)
    .having((e) => e.safeMessage, 'safe message', isNot(contains('SECRET')));

Future<CompletionEnvelope> estimate(
  OpenRouterClient client, {
  bool webSearch = false,
}) => client.complete(
  apiKey: 'test-key',
  model: client.snapshot!.models.first,
  messages: messages,
  schema: schema,
  webSearch: webSearch,
);

void main() {
  group('catalogue admission and schema drift', () {
    test(
      'exact zero fees and text output are required; bad rows isolate',
      () async {
        final client = OpenRouterClient(
          clientFactory: () => MockClient((request) async {
            expect(request.headers.containsKey('authorization'), isFalse);
            expect(request.followRedirects, isFalse);
            return catalog([
              modelJson(),
              modelJson(id: 'vendor/no-suffix'),
              modelJson(
                id: 'vendor/tiny:free',
                pricing: {'prompt': '1e-999', 'completion': '0'},
              ),
              modelJson(
                id: 'vendor/new-fee:free',
                pricing: {
                  'prompt': '0',
                  'completion': '0',
                  'unknown_fee': '0.001',
                },
              ),
              modelJson(
                id: 'vendor/unknown-fee:free',
                pricing: {'prompt': '0', 'completion': '0', 'future_fee': null},
              ),
              modelJson(
                id: 'vendor/missing-price:free',
                pricing: {'prompt': '0'},
              ),
              modelJson(id: 'openrouter/auto'),
              modelJson(id: 'openrouter/free'),
              {...modelJson(id: 'vendor/bad'), 'context_length': 'many'},
              {
                ...modelJson(id: 'vendor/image'),
                'architecture': {
                  'input_modalities': ['text'],
                  'output_modalities': ['image'],
                },
              },
              'broken',
            ]);
          }),
        );
        addTearDown(client.dispose);
        final result = await client.refreshCatalog();
        expect(result.models.map((m) => m.id), [
          'vendor/no-suffix',
          'vendor/test:free',
        ]);
        expect(result.issues, isNotEmpty);
        expect(result.models.last.supportsStructuredOutputs, isTrue);
        expect(result.models.last.supportsTools, isTrue);
        expect(() => result.models.clear(), throwsUnsupportedError);
      },
    );

    test(
      'all numeric prices, underflow and nested prices fail closed',
      () async {
        final client = OpenRouterClient(
          clientFactory: () => MockClient((_) async {
            final zero = modelJson(
              id: 'vendor/numeric',
              pricing: {'prompt': 0, 'completion': 0},
            );
            final tiny = jsonEncode(modelJson(id: 'vendor/underflow'))
                .replaceFirst('"prompt":"0"', '"prompt":1e-999');
            return http.Response(
              '{"data":[${jsonEncode(modelJson())},${jsonEncode(zero)},$tiny,'
              '${jsonEncode(modelJson(id: 'vendor/tiered', pricing: {
                'prompt': '0',
                'completion': '0',
                'tiers': {'below_1k': '0', 'above_1k': '1'},
              }))}]}',
              200,
            );
          }),
        );
        addTearDown(client.dispose);
        expect((await client.refreshCatalog()).models.map((m) => m.id), [
          'vendor/test:free',
        ]);
      },
    );

    test('conflicting duplicate prices quarantine the whole model', () async {
      final client = OpenRouterClient(
        clientFactory: () => MockClient(
          (_) async => catalog([
            modelJson(),
            modelJson(pricing: {'prompt': '0.01', 'completion': '0'}),
            modelJson(id: 'vendor/valid'),
          ]),
        ),
      );
      addTearDown(client.dispose);
      expect((await client.refreshCatalog()).models.map((m) => m.id), [
        'vendor/valid',
      ]);
    });

    test(
      'deduplicates concurrent refreshes and preserves last good on error',
      () async {
        var calls = 0;
        final pending = Completer<http.Response>();
        var time = DateTime.utc(2026, 10, 20);
        final client = OpenRouterClient(
          now: () => time,
          clientFactory: () => MockClient((_) {
            calls++;
            return calls == 1
                ? pending.future
                : Future.value(http.Response('SECRET broken response', 502));
          }),
        );
        addTearDown(client.dispose);
        final first = client.refreshCatalog();
        final second = client.refreshCatalog();
        pending.complete(catalog([modelJson()]));
        expect(identical(await first, await second), isTrue);
        expect(calls, 1);
        final fetchedAt = client.snapshot!.fetchedAt;
        time = time.add(const Duration(minutes: 10));
        await expectLater(
          client.refreshCatalog(),
          throwsA(failure(ApiFailureKind.unavailable)),
        );
        expect(client.snapshot!.fetchedAt, fetchedAt);
        expect(client.snapshot!.models.single.id, 'vendor/test:free');
        expect(client.snapshot!.isStale, isTrue);
      },
    );

    test(
      'cache round-trip validates raw fee evidence and ages honestly',
      () async {
        var time = DateTime.utc(2026, 10, 20);
        final client = OpenRouterClient(
          now: () => time,
          clientFactory: () => MockClient((_) async => catalog([modelJson()])),
        );
        final restored = OpenRouterClient(now: () => time);
        addTearDown(client.dispose);
        addTearDown(restored.dispose);
        await client.refreshCatalog();
        final exported = client.exportCatalog()!;
        restored.seedCatalog(exported);
        expect(restored.snapshot!.models.single.id, 'vendor/test:free');
        expect(restored.snapshot!.fetchedAt, client.snapshot!.fetchedAt);
        expect(restored.snapshot!.isStale, isTrue);
        time = time.add(const Duration(hours: 1));
        expect(client.snapshot!.isStale, isTrue);
        expect(
          () => restored.seedCatalog(
            exported.replaceFirst('"prompt":"0"', '"prompt":"1"'),
          ),
          throwsA(failure(ApiFailureKind.schema)),
        );
        expect(restored.snapshot!.models.single.id, 'vendor/test:free');
        expect(
          () => restored.seedCatalog(
            '{"version":1,"fetchedAt":"2099-01-01","data":[]}',
          ),
          throwsA(failure(ApiFailureKind.schema)),
        );
      },
    );

    test(
      'pagination follows only the exact catalogue origin and path',
      () async {
        var calls = 0;
        final client = OpenRouterClient(
          clientFactory: () => MockClient((request) async {
            calls++;
            return calls == 1
                ? catalog(
                    [modelJson()],
                    links: {'next': '/api/v1/models?offset=1'},
                  )
                : catalog([modelJson(id: 'vendor/second')]);
          }),
        );
        addTearDown(client.dispose);
        expect((await client.refreshCatalog()).models, hasLength(2));
        expect(calls, 2);
        for (final target in [
          'https://other.example/api/v1/models',
          'https://openrouter.ai/api/v1/chat/completions',
          'http://openrouter.ai/api/v1/models',
          'https://user@openrouter.ai/api/v1/models',
        ]) {
          var badCalls = 0;
          final invalid = OpenRouterClient(
            clientFactory: () => MockClient((_) async {
              badCalls++;
              return catalog([modelJson()], links: {'next': target});
            }),
          );
          addTearDown(invalid.dispose);
          await expectLater(
            invalid.refreshCatalog(),
            throwsA(failure(ApiFailureKind.schema)),
          );
          expect(badCalls, 1);
        }
      },
    );

    test(
      'pagination cycles, excessive pages and malformed envelopes fail',
      () async {
        for (final body in [
          '{"data":{} }',
          '{"data":[]}',
          '{"error":{"code":403,"message":"SECRET"}}',
          jsonEncode({
            'data': [modelJson()],
            'links': {'next': '/api/v1/models'},
          }),
        ]) {
          final client = OpenRouterClient(
            clientFactory: () =>
                MockClient((_) async => http.Response(body, 200)),
          );
          addTearDown(client.dispose);
          await expectLater(
            client.refreshCatalog(),
            throwsA(isA<ApiFailure>()),
          );
        }
        var calls = 0;
        final many = OpenRouterClient(
          clientFactory: () => MockClient((_) async {
            calls++;
            return catalog(
              [modelJson(id: 'vendor/m$calls')],
              links: {'next': '/api/v1/models?offset=$calls'},
            );
          }),
        );
        addTearDown(many.dispose);
        await expectLater(
          many.refreshCatalog(),
          throwsA(failure(ApiFailureKind.schema)),
        );
        expect(calls, lessThanOrEqualTo(5));
      },
    );
  });

  group('completion safety', () {
    test('request pins free prices and model; sends native schema only when advertised', () async {
      late Map<String, dynamic> sent;
      final client = OpenRouterClient(
        clientFactory: () => MockClient((request) async {
          if (request.method == 'GET') return catalog([modelJson()]);
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.headers['authorization'], 'Bearer test-key');
          return completion();
        }),
      );
      addTearDown(client.dispose);
      await client.refreshCatalog();
      final result = await estimate(client);
      expect(result.content, '{"status":"insufficient_evidence"}');
      expect(sent['model'], 'vendor/test:free');
      expect(sent['stream'], isFalse);
      expect(sent['provider'], {
        'allow_fallbacks': false,
        'require_parameters': true,
        'max_price': {'prompt': 0, 'completion': 0},
      });
      expect(sent['response_format']['json_schema']['strict'], isTrue);
      expect(sent['response_format']['json_schema']['schema'], schema);
      expect(sent.containsKey('tools'), isFalse);
      expect(sent.containsKey('plugins'), isFalse);
      expect(sent.containsKey('models'), isFalse);
    });

    test('plain JSON instructions replace unsupported response_format before sending', () async {
      final requests = <Map<String, dynamic>>[];
      final client = OpenRouterClient(
        clientFactory: () => MockClient((request) async {
          if (request.method == 'GET') {
            return catalog([modelJson(parameters: [])]);
          }
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          return completion();
        }),
      );
      addTearDown(client.dispose);
      await client.refreshCatalog();
      await estimate(client);
      expect(requests, hasLength(1));
      expect(requests.single.containsKey('response_format'), isFalse);
      expect(jsonEncode(requests.single['messages']), contains('JSON'));
      expect(
        jsonEncode(requests.single['messages']),
        contains('additionalProperties'),
      );
      expect(messages.length, 2);
    });

    test('web search is explicit, engine-pinned and bounded', () async {
      late Map<String, dynamic> sent;
      final client = OpenRouterClient(
        clientFactory: () => MockClient((request) async {
          if (request.method == 'GET') return catalog([modelJson()]);
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return completion(
            annotations: [
              {
                'type': 'url_citation',
                'url_citation': {
                  'url': 'https://market.example/item',
                  'content': 'Sold for 125 EUR; good condition.',
                },
              },
              {
                'type': 'url_citation',
                'url_citation': {
                  'url': 'javascript:alert(1)',
                  'content': 'bad',
                },
              },
            ],
          );
        }),
      );
      addTearDown(client.dispose);
      await client.refreshCatalog();
      final result = await estimate(client, webSearch: true);
      expect(sent['tools'], [
        {
          'type': 'openrouter:web_search',
          'parameters': {
            'engine': 'exa',
            'mode': 'instant',
            'max_uses': 1,
            'max_results': 5,
            'max_total_results': 5,
            'max_characters': 3000,
          },
        },
      ]);
      expect(sent['max_tool_calls'], 1);
      expect(result.citedUrls, {'https://market.example/item'});
      expect(
        result.citations['https://market.example/item'],
        contains('125 EUR'),
      );
    });

    test(
      'unsupported tools, stale cache and unadmitted models never send content',
      () async {
        var posts = 0;
        var time = DateTime.utc(2026, 10, 20);
        final client = OpenRouterClient(
          now: () => time,
          clientFactory: () => MockClient((request) async {
            if (request.method == 'POST') posts++;
            return catalog([modelJson(parameters: [])]);
          }),
        );
        addTearDown(client.dispose);
        await client.refreshCatalog();
        await expectLater(
          estimate(client, webSearch: true),
          throwsA(failure(ApiFailureKind.policy)),
        );
        await expectLater(
          client.complete(
            apiKey: 'test-key',
            model: ModelInfo(id: 'vendor/unadmitted', name: 'Unknown'),
            messages: messages,
            schema: schema,
          ),
          throwsA(failure(ApiFailureKind.policy)),
        );
        time = time.add(const Duration(hours: 2));
        await expectLater(
          estimate(client),
          throwsA(failure(ApiFailureKind.policy)),
        );
        expect(posts, 0);
      },
    );

    test('rejects substitution, truncation, tool requests, non-JSON and empty output', () async {
      for (final response in [
        completion(actualModel: 'vendor/paid'),
        completion(finishReason: 'length'),
        completion(finishReason: 'tool_calls'),
        completion(content: 'Here is your price: 250'),
        completion(content: ''),
        completion(content: null),
      ]) {
        var posts = 0;
        final client = OpenRouterClient(
          clientFactory: () => MockClient((request) async {
            if (request.method == 'GET') return catalog([modelJson()]);
            posts++;
            return response;
          }),
        );
        addTearDown(client.dispose);
        await client.refreshCatalog();
        await expectLater(
          estimate(client),
          throwsA(failure(ApiFailureKind.schema)),
        );
        expect(posts, 1);
      }
    });

    test('completion failures expose only fixed diagnostic codes', () async {
      for (final (response, diagnostic) in [
        (completion(actualModel: 'vendor/SECRET'), 'model_mismatch'),
        (completion(finishReason: 'length'), 'incomplete_completion'),
        (
          http.Response(
            '{"model":"vendor/test:free","choices":[],"extra":"SECRET"}',
            200,
          ),
          'choice_shape',
        ),
        (completion(content: null), 'empty_content'),
        (completion(content: 'SECRET not JSON'), 'invalid_json'),
        (http.Response('SECRET invalid outer JSON', 200), 'invalid_json'),
        (completion(content: '[]'), 'invalid_json'),
        (completion(toolCalls: ['SECRET']), 'unresolved_tool_calls'),
        (completion(toolCalls: 'SECRET'), 'unresolved_tool_calls'),
      ]) {
        var posts = 0;
        final client = OpenRouterClient(
          clientFactory: () => MockClient((request) async {
            if (request.method == 'GET') return catalog([modelJson()]);
            posts++;
            return response;
          }),
        );
        addTearDown(client.dispose);
        await client.refreshCatalog();
        await expectLater(
          estimate(client),
          throwsA(
            failure(ApiFailureKind.schema).having(
              (error) => error.diagnosticCode,
              'safe static diagnostic',
              diagnostic,
            ),
          ),
        );
        expect(posts, 1);
      }
    });

    test('an empty tool_calls list is a completed normal response', () async {
      final client = OpenRouterClient(
        clientFactory: () => MockClient(
          (request) async => request.method == 'GET'
              ? catalog([modelJson()])
              : completion(toolCalls: <Object?>[]),
        ),
      );
      addTearDown(client.dispose);
      await client.refreshCatalog();
      final result = await estimate(client);
      expect(result.content, '{"status":"insufficient_evidence"}');
      expect(result.actualModel, 'vendor/test:free');
    });

    test(
      'HTTP 200 upstream errors stay errors and never trigger retry',
      () async {
        var posts = 0;
        final client = OpenRouterClient(
          clientFactory: () => MockClient((request) async {
            if (request.method == 'GET') return catalog([modelJson()]);
            posts++;
            return http.Response(
              '{"error":{"code":429,"message":"SECRET prompt echoed"}}',
              200,
            );
          }),
        );
        addTearDown(client.dispose);
        await client.refreshCatalog();
        await expectLater(
          estimate(client),
          throwsA(
            failure(ApiFailureKind.quota)
                .having((e) => e.httpStatus, 'HTTP', 200)
                .having((e) => e.upstreamCode, 'upstream', 429),
          ),
        );
        expect(posts, 1);
      },
    );

    test(
      'classifies errors without exposing bodies or retrying content',
      () async {
        for (final entry in {
          400: ApiFailureKind.schema,
          401: ApiFailureKind.auth,
          402: ApiFailureKind.quota,
          403: ApiFailureKind.policy,
          408: ApiFailureKind.timeout,
          429: ApiFailureKind.quota,
          502: ApiFailureKind.unavailable,
          503: ApiFailureKind.unavailable,
        }.entries) {
          final client = OpenRouterClient(
            clientFactory: () => MockClient(
              (request) async => request.method == 'GET'
                  ? catalog([modelJson()])
                  : http.Response('SECRET raw body', entry.key),
            ),
          );
          addTearDown(client.dispose);
          await client.refreshCatalog();
          await expectLater(estimate(client), throwsA(failure(entry.value)));
        }
      },
    );

    test(
      'Retry-After seconds and HTTP date apply local account cooldown',
      () async {
        for (final retryAfter in ['120', 'Tue, 20 Oct 2026 00:02:00 GMT']) {
          var time = DateTime.utc(2026, 10, 20);
          var posts = 0;
          final client = OpenRouterClient(
            now: () => time,
            clientFactory: () => MockClient((request) async {
              if (request.method == 'GET') return catalog([modelJson()]);
              posts++;
              return posts == 1
                  ? http.Response(
                      '{"error":{"code":429}}',
                      429,
                      headers: {'retry-after': retryAfter},
                    )
                  : completion();
            }),
          );
          addTearDown(client.dispose);
          await client.refreshCatalog();
          await expectLater(
            estimate(client),
            throwsA(
              failure(ApiFailureKind.quota).having(
                (e) => e.retryAt,
                'retry time',
                DateTime.utc(2026, 10, 20, 0, 2),
              ),
            ),
          );
          await expectLater(
            estimate(client),
            throwsA(failure(ApiFailureKind.quota)),
          );
          expect(posts, 1);
          time = time.add(const Duration(minutes: 2));
          await estimate(client);
          expect(posts, 2);
        }
      },
    );
  });

  group('transport bounds and cancellation', () {
    test('catalogue and completion response sizes are bounded', () async {
      for (final isCatalog in [true, false]) {
        final client = OpenRouterClient(
          clientFactory: () => MockClient((request) async {
            if (!isCatalog && request.method == 'GET') {
              return catalog([modelJson()]);
            }
            return http.Response(' ' * (5 * 1024 * 1024 + 1), 200);
          }),
        );
        addTearDown(client.dispose);
        if (!isCatalog) await client.refreshCatalog();
        await expectLater(
          isCatalog ? client.refreshCatalog() : estimate(client),
          throwsA(failure(ApiFailureKind.schema)),
        );
      }
    });

    test('network failures are sanitized', () async {
      final client = OpenRouterClient(
        clientFactory: () => MockClient((_) async {
          throw http.ClientException('SECRET request data');
        }),
      );
      addTearDown(client.dispose);
      await expectLater(
        client.refreshCatalog(),
        throwsA(failure(ApiFailureKind.network)),
      );
    });

    test('cancel aborts a stalled request, completes promptly, and rejects late data', () async {
      final pending = Completer<http.StreamedResponse>();
      late http.AbortableRequest request;
      late StreamClient transport;
      final client = OpenRouterClient(
        clientFactory: () => transport = StreamClient((sent) {
          request = sent as http.AbortableRequest;
          return pending.future;
        }),
      );
      addTearDown(client.dispose);
      final future = client.refreshCatalog();
      final checked = expectLater(
        future,
        throwsA(failure(ApiFailureKind.cancelled)),
      );
      client.cancel();
      await checked;
      await request.abortTrigger;
      expect(transport.closed, isTrue);
      pending.complete(
        http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'data': [modelJson()],
              }),
            ),
          ),
          200,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(client.snapshot, isNull);
    });

    test(
      'deadline aborts the body stream, not just the response headers',
      () async {
        late http.AbortableRequest request;
        final body = StreamController<List<int>>();
        addTearDown(body.close);
        final client = OpenRouterClient(
          metadataTimeout: const Duration(milliseconds: 20),
          clientFactory: () => StreamClient((sent) async {
            request = sent as http.AbortableRequest;
            return http.StreamedResponse(body.stream, 200);
          }),
        );
        addTearDown(client.dispose);
        await expectLater(
          client.refreshCatalog(),
          throwsA(failure(ApiFailureKind.timeout)),
        );
        await request.abortTrigger;
        expect(body.hasListener, isFalse);
      },
    );

    test('deadline is not extended by stalled stream cancellation', () async {
      final cancellation = Completer<void>();
      final body = StreamController<List<int>>(
        onCancel: () => cancellation.future,
      );
      final client = OpenRouterClient(
        metadataTimeout: const Duration(milliseconds: 20),
        clientFactory: () => StreamClient((_) async {
          return http.StreamedResponse(body.stream, 200);
        }),
      );
      addTearDown(client.dispose);
      try {
        await expectLater(
          client.refreshCatalog().timeout(const Duration(milliseconds: 100)),
          throwsA(failure(ApiFailureKind.timeout)),
        );
      } finally {
        cancellation.complete();
        await body.close();
      }
    });

    test(
      'chunked oversized bodies abort without a Content-Length header',
      () async {
        late http.AbortableRequest request;
        var cancelled = false;
        final body = StreamController<List<int>>(
          onCancel: () => cancelled = true,
        );
        final client = OpenRouterClient(
          clientFactory: () => StreamClient((sent) async {
            request = sent as http.AbortableRequest;
            scheduleMicrotask(() {
              body.add(List.filled(3 * 1024 * 1024, 32));
              body.add(List.filled(3 * 1024 * 1024, 32));
            });
            return http.StreamedResponse(body.stream, 200);
          }),
        );
        addTearDown(client.dispose);
        await expectLater(
          client.refreshCatalog(),
          throwsA(failure(ApiFailureKind.schema)),
        );
        await request.abortTrigger;
        expect(cancelled, isTrue);
        await body.close();
      },
    );

    test(
      'endpoint reports are metadata and malformed rows are ignored',
      () async {
        final client = OpenRouterClient(
          clientFactory: () => MockClient((request) async {
            expect(request.headers.containsKey('authorization'), isFalse);
            expect(
              request.url.path,
              '/api/v1/models/vendor/test:free/endpoints',
            );
            return http.Response(
              jsonEncode({
                'data': {
                  'id': 'vendor/test:free',
                  'endpoints': [
                    {'provider_name': 'Example provider'},
                    {'provider_name': 'Example provider'},
                    {'provider_name': 5},
                    'bad row',
                  ],
                },
              }),
              200,
            );
          }),
        );
        addTearDown(client.dispose);
        final report = await client.inspectEndpoints(
          ModelInfo(id: 'vendor/test:free', name: 'Test'),
        );
        expect(report.providers, ['Example provider']);
        expect(() => report.providers.clear(), throwsUnsupportedError);
      },
    );
  });
}

class StreamClient extends http.BaseClient {
  StreamClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);

  @override
  void close() => closed = true;
}
