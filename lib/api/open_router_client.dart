import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/product_media.dart';

enum ApiFailureKind {
  network,
  timeout,
  cancelled,
  auth,
  quota,
  unavailable,
  schema,
  policy,
}

/// Safe to display. Upstream messages, bodies, request content and keys never
/// enter this object.
class ApiFailure implements Exception {
  const ApiFailure(
    this.kind,
    this.safeMessage, {
    this.httpStatus,
    this.upstreamCode,
    this.retryAt,
    this.diagnosticCode,
  });

  final ApiFailureKind kind;
  final String safeMessage;
  final int? httpStatus;
  final int? upstreamCode;
  final DateTime? retryAt;

  /// A fixed client-side classification, never a value copied from a response.
  final String? diagnosticCode;

  @override
  String toString() => safeMessage;
}

class ModelInfo {
  ModelInfo({
    required this.id,
    required this.name,
    this.contextLength = 0,
    this.description = '',
    this.maxCompletionTokens,
    Iterable<String> inputModalities = const ['text'],
    Map<String, String> pricing = const {'prompt': '0', 'completion': '0'},
    Iterable<String> supportedParameters = const [],
  }) : supportedParameters = Set.unmodifiable(supportedParameters),
       inputModalities = Set.unmodifiable(inputModalities),
       pricing = Map.unmodifiable(pricing);

  final String id;
  final String name;
  final int contextLength;
  final Set<String> supportedParameters;
  final Set<String> inputModalities;
  final Map<String, String> pricing;
  final String description;
  final int? maxCompletionTokens;

  bool get supportsStructuredOutputs =>
      supportedParameters.contains('structured_outputs');
  bool get supportsTools => supportedParameters.contains('tools');
  bool get acceptsImages => mediaUnavailableReason('image') == null;
  bool get acceptsVideo => mediaUnavailableReason('video') == null;
  Set<String> get allowedMediaMimeTypes => {
    if (acceptsImages) ...productImageMimeTypes,
    if (acceptsVideo) 'video/mp4',
  };

  String? mediaUnavailableReason(String modality) {
    if (!const {'image', 'video'}.contains(modality) ||
        !inputModalities.contains(modality)) {
      return 'This model does not advertise this media input.';
    }
    final applicable = modality == 'image'
        ? const {'image', 'image_token'}
        : const {'image', 'image_token', 'audio', 'input_audio_cache', 'video'};
    for (final required in ['prompt', 'completion']) {
      if (!OpenRouterClient._exactZero(pricing[required])) {
        return 'Free model pricing could not be confirmed.';
      }
    }
    for (final entry in pricing.entries) {
      if ((!OpenRouterClient._optionalInputFees.contains(entry.key) ||
              applicable.contains(entry.key)) &&
          !OpenRouterClient._exactZero(entry.value)) {
        return 'Free media pricing could not be confirmed. Choose another model.';
      }
    }
    if (modality == 'video' && !id.endsWith(':free')) {
      return 'Video requires a verified free model variant.';
    }
    return null;
  }

  String get capabilitySignature => jsonEncode({
    'id': id,
    'context': contextLength,
    'output': maxCompletionTokens,
    'input': inputModalities.toList()..sort(),
    'parameters': supportedParameters.toList()..sort(),
    'pricing': {
      for (final key in pricing.keys.toList()..sort()) key: pricing[key],
    },
  });
}

class CatalogSnapshot {
  CatalogSnapshot({
    required List<ModelInfo> models,
    required this.fetchedAt,
    List<String> issues = const [],
    this.isStale = false,
  }) : models = List.unmodifiable(models),
       issues = List.unmodifiable(issues);

  final List<ModelInfo> models;
  final DateTime fetchedAt;
  final List<String> issues;
  final bool isStale;
}

class EndpointReport {
  EndpointReport({required List<String> providers, required this.checkedAt})
    : providers = List.unmodifiable(providers);

  /// Advertised provider names, not successful inference health checks.
  final List<String> providers;
  final DateTime checkedAt;
}

class CompletionEnvelope {
  CompletionEnvelope({
    required this.content,
    required this.actualModel,
    Set<String> citedUrls = const {},
    Map<String, String> citations = const {},
  }) : citedUrls = Set.unmodifiable(citedUrls),
       citations = Map.unmodifiable(citations);

  final String content;
  final String actualModel;
  final Set<String> citedUrls;

  /// Provider annotation excerpts, not prose inferred from the model's answer.
  final Map<String, String> citations;
}

/// A client-only API boundary. Every operation owns its transport and abort
/// signal, so cancel also stops response bodies and prevents late publication.
/// There are no content retries, model substitutions, or provider fallbacks.
class OpenRouterClient {
  OpenRouterClient({
    http.Client Function()? clientFactory,
    DateTime Function()? now,
    Duration metadataTimeout = const Duration(seconds: 20),
    Duration completionTimeout = const Duration(seconds: 90),
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _now = now ?? DateTime.now,
       _metadataTimeout = _boundedTimeout(metadataTimeout, 20),
       _completionTimeout = _boundedTimeout(completionTimeout, 90);

  static final _modelsUri = Uri.parse('https://openrouter.ai/api/v1/models');
  static final _completionUri = Uri.parse(
    'https://openrouter.ai/api/v1/chat/completions',
  );
  static final _modelId = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._:-]*$',
  );
  static final _zeroPrice = RegExp(r'^[+]?0+(?:\.0+)?(?:[eE][+-]?[0-9]+)?$');
  static final _decimalPrice = RegExp(
    r'^[+]?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$',
  );
  static const _optionalInputFees = {
    'image',
    'image_token',
    'image_output',
    'audio',
    'audio_output',
    'input_audio_cache',
    'video',
    'file',
    'web_search',
  };
  static const _catalogBytes = 5 * 1024 * 1024;
  static const _completionBytes = 512 * 1024;
  static const _requestBytes = 128 * 1024;
  static const _catalogLifetime = Duration(hours: 1);
  static const _maxCatalogPages = 5;
  static const _maxCatalogRows = 10000;

  final http.Client Function() _clientFactory;
  final DateTime Function() _now;
  final Duration _metadataTimeout;
  final Duration _completionTimeout;
  final Set<_Operation> _operations = {};
  CatalogSnapshot? _snapshot;
  List<Map<String, dynamic>> _acceptedRows = [];
  Future<CatalogSnapshot>? _refreshing;
  DateTime? _cooldownUntil;
  bool _disposed = false;

  CatalogSnapshot? get snapshot {
    final current = _snapshot;
    if (current == null) return null;
    if (!current.isStale &&
        _now().difference(current.fetchedAt) >= _catalogLifetime) {
      _snapshot = CatalogSnapshot(
        models: current.models,
        fetchedAt: current.fetchedAt,
        issues: current.issues,
        isStale: true,
      );
    }
    return _snapshot;
  }

  Future<CatalogSnapshot> refreshCatalog() {
    if (_disposed) return Future.error(_cancelled);
    final pending = _refreshing;
    if (pending != null) return pending;
    final future = _refreshCatalog();
    _refreshing = future;
    // Both callbacks consume completion. The returned future is the only one
    // carrying the error to callers, avoiding an unobserved whenComplete error.
    unawaited(
      future.then<void>(
        (_) => _refreshing = null,
        onError: (Object _, StackTrace _) => _refreshing = null,
      ),
    );
    return future;
  }

  Future<CatalogSnapshot> _refreshCatalog() async {
    final operation = _begin(_metadataTimeout);
    try {
      final rows = <Object?>[];
      final visited = <String>{};
      var remainingBytes = _catalogBytes;
      var uri = _modelsUri;
      for (var page = 0; page < _maxCatalogPages; page++) {
        if (!visited.add(uri.toString())) throw _badSchema;
        final response = await _send(
          operation,
          'GET',
          uri,
          maxBytes: remainingBytes,
        );
        remainingBytes -= response.bytes.length;
        final envelope = _decodeEnvelope(response, accountRequest: false);
        final data = envelope['data'];
        if (data is! List || rows.length + data.length > _maxCatalogRows) {
          throw _badSchema;
        }
        rows.addAll(data);
        final next = _nextPage(envelope, uri);
        if (next == null) break;
        if (page == _maxCatalogPages - 1 || remainingBytes <= 0) {
          throw _badSchema;
        }
        uri = next;
      }
      final admitted = _admit(rows);
      operation.ensureActive();
      final result = CatalogSnapshot(
        models: admitted.models,
        fetchedAt: _now().toUtc(),
        issues: admitted.issues,
      );
      _acceptedRows = admitted.rows;
      _snapshot = result;
      return result;
    } catch (error) {
      final old = _snapshot;
      if (old != null) {
        _snapshot = CatalogSnapshot(
          models: old.models,
          fetchedAt: old.fetchedAt,
          issues: [
            ...old.issues.take(19),
            'Refresh failed. The previous model list is shown for reference.',
          ],
          isStale: true,
        );
      }
      throw _safeFailure(error, operation);
    } finally {
      _finish(operation);
    }
  }

  /// Imports a bounded, versioned cache through the same admission checks as
  /// network data. Restored metadata never authorizes inference until refreshed.
  void seedCatalog(String source) {
    if (_disposed) throw _cancelled;
    if (utf8.encode(source).length > _catalogBytes) throw _badSchema;
    try {
      final root = jsonDecode(source);
      if (root is! Map<String, dynamic> ||
          root['version'] != 1 ||
          root['fetchedAt'] is! String ||
          root['data'] is! List) {
        throw _badSchema;
      }
      final fetchedAt = DateTime.tryParse(root['fetchedAt'] as String);
      if (fetchedAt == null || fetchedAt.isAfter(_now())) throw _badSchema;
      final admitted = _admit(root['data'] as List);
      // A partial cache is not silently repaired; preserve existing state.
      if (admitted.rows.length != (root['data'] as List).length) {
        throw _badSchema;
      }
      final result = CatalogSnapshot(
        models: admitted.models,
        fetchedAt: fetchedAt.toUtc(),
        issues: ['Saved model list. Refresh to confirm current free pricing.'],
        isStale: true,
      );
      _acceptedRows = admitted.rows;
      _snapshot = result;
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw _badSchema;
    }
  }

  String? exportCatalog() {
    final current = _snapshot;
    if (current == null) return null;
    return jsonEncode({
      'version': 1,
      'fetchedAt': current.fetchedAt.toUtc().toIso8601String(),
      'data': _acceptedRows,
    });
  }

  Future<EndpointReport> inspectEndpoints(ModelInfo model) async {
    if (!_validId(model.id)) throw _badSchema;
    final operation = _begin(_metadataTimeout);
    try {
      final uri = _modelsUri.replace(
        path: '${_modelsUri.path}/${model.id}/endpoints',
      );
      final response = await _send(
        operation,
        'GET',
        uri,
        maxBytes: 1024 * 1024,
      );
      final envelope = _decodeEnvelope(response, accountRequest: false);
      final data = envelope['data'];
      if (data is! Map<String, dynamic> || data['endpoints'] is! List) {
        throw _badSchema;
      }
      if (data['id'] != null && data['id'] != model.id) throw _badSchema;
      final providers = <String>{};
      for (final row in data['endpoints'] as List) {
        if (row is! Map<String, dynamic>) continue;
        final name = row['provider_name'];
        if (name is String && name.trim().isNotEmpty && name.length <= 200) {
          providers.add(name.trim());
        }
      }
      operation.ensureActive();
      return EndpointReport(
        providers: providers.toList()..sort(),
        checkedAt: _now().toUtc(),
      );
    } catch (error) {
      throw _safeFailure(error, operation);
    } finally {
      _finish(operation);
    }
  }

  Future<CompletionEnvelope> complete({
    required String apiKey,
    required ModelInfo model,
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> schema,
    bool webSearch = false,
    List<ProductMedia> attachments = const [],
  }) async {
    if (_disposed) throw _cancelled;
    final current = snapshot;
    final selected = current?.models.where((m) => m.id == model.id).firstOrNull;
    if (current == null || current.isStale || selected == null) {
      throw const ApiFailure(
        ApiFailureKind.policy,
        'Refresh the free model list before requesting an estimate.',
      );
    }
    if (selected.capabilitySignature != model.capabilitySignature) {
      throw const ApiFailure(
        ApiFailureKind.policy,
        'This model changed. Select it again from the refreshed model list.',
      );
    }
    if (apiKey.trim().isEmpty ||
        apiKey.length > 512 ||
        apiKey.contains(RegExp(r'[\s\x00-\x1f\x7f]'))) {
      throw const ApiFailure(
        ApiFailureKind.auth,
        'Enter a valid OpenRouter API key.',
      );
    }
    if (webSearch && !selected.supportsTools) {
      throw const ApiFailure(
        ApiFailureKind.policy,
        'This model does not advertise tool support. Select another free model to search.',
      );
    }
    final retryAt = _cooldownUntil;
    if (retryAt != null && _now().isBefore(retryAt)) {
      throw ApiFailure(
        ApiFailureKind.quota,
        'OpenRouter asked this session to wait. Retry after the displayed time.',
        retryAt: retryAt,
      );
    }
    if (messages.isEmpty || messages.length > 32 || schema.isEmpty) {
      throw _badSchema;
    }
    for (final message in messages) {
      if (!const {'system', 'user', 'assistant'}.contains(message['role']) ||
          message['content'] is! String) {
        throw _badSchema;
      }
    }
    try {
      validateProductMedia(attachments);
    } on MediaFailure catch (failure) {
      throw ApiFailure(ApiFailureKind.policy, failure.safeMessage);
    }
    for (final file in attachments) {
      final reason = selected.mediaUnavailableReason(file.kind.name);
      if (reason != null) throw ApiFailure(ApiFailureKind.policy, reason);
    }
    if (attachments.isNotEmpty && messages.last['role'] != 'user') {
      throw _badSchema;
    }
    // Only explicitly supported optional parameters are used. There is never a
    // second request that silently strips a rejected response_format or tool.
    final outgoingMessages = messages
        .map(
          (m) => <String, dynamic>{'role': m['role'], 'content': m['content']},
        )
        .toList();
    final body = <String, dynamic>{
      'model': selected.id,
      'messages': outgoingMessages,
      'stream': false,
      'max_tokens':
          selected.maxCompletionTokens != null &&
              selected.maxCompletionTokens! < 4096
          ? selected.maxCompletionTokens
          : 4096,
      'provider': {
        'allow_fallbacks': false,
        'require_parameters': true,
        'max_price': {
          'prompt': 0,
          'completion': 0,
          'request': 0,
          'image': 0,
          'audio': 0,
        },
      },
      if (selected.supportedParameters.contains('temperature'))
        'temperature': 0,
      if (selected.supportsStructuredOutputs)
        'response_format': {
          'type': 'json_schema',
          'json_schema': {
            'name': 'worthhit_appraisal',
            'strict': true,
            'schema': schema,
          },
        },
      if (webSearch) ...{
        'tools': [
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
        ],
        'max_tool_calls': 1,
      },
    };
    if (!selected.supportsStructuredOutputs) {
      outgoingMessages.insert(0, {
        'role': 'system',
        'content':
            'Return exactly one JSON object matching this schema. '
            'No Markdown, commentary, or code fences. '
            '${jsonEncode(schema)}',
      });
    }
    late String encoded;
    try {
      encoded = jsonEncode(body);
    } catch (_) {
      throw _badSchema;
    }
    if (utf8.encode(encoded).length > _requestBytes) throw _badSchema;
    // Keep the original text/schema budget independent from bounded media.
    // Only the final user turn receives files; no remote URL is accepted.
    if (attachments.isNotEmpty) {
      final last = outgoingMessages.last;
      last['content'] = [
        {'type': 'text', 'text': last['content']},
        ...attachments.map((file) => file.toContentPart()),
      ];
      encoded = jsonEncode(body);
      final maxMediaBytes = ((maxProductMediaTotalBytes + 2) ~/ 3) * 4;
      if (utf8.encode(encoded).length > _requestBytes + maxMediaBytes + 4096) {
        throw _badSchema;
      }
    }

    final operation = _begin(_completionTimeout);
    try {
      final response = await _send(
        operation,
        'POST',
        _completionUri,
        maxBytes: _completionBytes,
        apiKey: apiKey,
        body: encoded,
      );
      final envelope = _decodeEnvelope(response, accountRequest: true);
      if (envelope['model'] != selected.id) {
        throw _completionSchema('model_mismatch');
      }
      final choices = envelope['choices'];
      if (choices is! List || choices.length != 1) {
        throw _completionSchema('choice_shape');
      }
      final choice = choices.single;
      if (choice is! Map<String, dynamic>) {
        throw _completionSchema('choice_shape');
      }
      if (choice['finish_reason'] == 'content_filter') {
        throw const ApiFailure(
          ApiFailureKind.policy,
          'The provider declined this request. Review the item and try an allowed product.',
        );
      }
      if (choice['finish_reason'] != 'stop') {
        throw _completionSchema('incomplete_completion');
      }
      final message = choice['message'];
      if (message is! Map<String, dynamic>) {
        throw _completionSchema('choice_shape');
      }
      final toolCalls = message['tool_calls'];
      if (toolCalls != null && (toolCalls is! List || toolCalls.isNotEmpty)) {
        throw _completionSchema('unresolved_tool_calls');
      }
      final content = message['content'];
      if (content is! String || content.trim().isEmpty) {
        throw _completionSchema('empty_content');
      }
      try {
        if (jsonDecode(content) is! Map<String, dynamic>) {
          throw _completionSchema('invalid_json');
        }
      } catch (_) {
        throw _completionSchema('invalid_json');
      }
      final urls = <String>{};
      final citations = <String, String>{};
      final annotations = message['annotations'];
      if (annotations is List) {
        for (final entry in annotations.take(100)) {
          if (entry is! Map<String, dynamic> ||
              entry['type'] != 'url_citation') {
            continue;
          }
          final citation = entry['url_citation'];
          if (citation is! Map<String, dynamic>) continue;
          final url = citation['url'];
          if (url is! String || !_safeCitationUrl(url)) continue;
          urls.add(url);
          final excerpt = citation['content'];
          if (excerpt is String && excerpt.trim().isNotEmpty) {
            citations[url] = excerpt.length <= 12000
                ? excerpt
                : excerpt.substring(0, 12000);
          }
        }
      }
      operation.ensureActive();
      return CompletionEnvelope(
        content: content,
        actualModel: selected.id,
        citedUrls: urls,
        citations: citations,
      );
    } catch (error) {
      throw _safeFailure(error, operation);
    } finally {
      _finish(operation);
    }
  }

  void cancel() {
    for (final operation in _operations.toList()) {
      operation.stop(_cancelled);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancel();
  }

  _Operation _begin(Duration timeout) {
    if (_disposed) throw _cancelled;
    final operation = _Operation(_clientFactory(), timeout);
    _operations.add(operation);
    return operation;
  }

  void _finish(_Operation operation) {
    operation.close();
    _operations.remove(operation);
  }

  Future<_WireResponse> _send(
    _Operation operation,
    String method,
    Uri uri, {
    required int maxBytes,
    String? apiKey,
    String? body,
  }) async {
    operation.ensureActive();
    final request = http.AbortableRequest(
      method,
      uri,
      abortTrigger: operation.aborted.future,
    )..followRedirects = false;
    request.headers['Accept'] = 'application/json';
    if (apiKey != null) request.headers['Authorization'] = 'Bearer $apiKey';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = body;
    }
    final response = await operation.race(operation.client.send(request));
    operation.ensureActive();
    if (response.contentLength != null && response.contentLength! > maxBytes) {
      operation.stop(_badSchema);
      throw _badSchema;
    }
    final bytes = BytesBuilder(copy: false);
    final result = Completer<Uint8List>();
    late StreamSubscription<List<int>> subscription;
    subscription = response.stream.listen(
      (chunk) {
        if (bytes.length + chunk.length > maxBytes) {
          operation.stop(_badSchema);
        } else {
          bytes.add(chunk);
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      },
      onDone: () {
        if (!result.isCompleted) result.complete(bytes.takeBytes());
      },
      cancelOnError: true,
    );
    try {
      final bodyBytes = await operation.race(result.future);
      operation.ensureActive();
      return _WireResponse(response.statusCode, response.headers, bodyBytes);
    } finally {
      // Stream cancellation itself may await platform cleanup. Keep that wait
      // inside the same deadline; an abort must still return promptly to the UI.
      await operation.race(subscription.cancel());
    }
  }

  Map<String, dynamic> _decodeEnvelope(
    _WireResponse response, {
    required bool accountRequest,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bytes));
    } catch (_) {
      if (response.status >= 200 && response.status < 300) {
        throw accountRequest ? _completionSchema('invalid_json') : _badSchema;
      }
    }
    final map = decoded is Map<String, dynamic> ? decoded : null;
    final upstreamError = map?['error'];
    final upstreamCode = upstreamError is Map<String, dynamic>
        ? _statusCode(upstreamError['code'])
        : null;
    if (response.status < 200 ||
        response.status >= 300 ||
        upstreamError != null) {
      final code = response.status >= 200 && response.status < 300
          ? (upstreamCode ?? 502)
          : response.status;
      final kind = switch (code) {
        400 || 404 || 413 || 422 => ApiFailureKind.schema,
        401 => ApiFailureKind.auth,
        402 || 429 => ApiFailureKind.quota,
        403 => ApiFailureKind.policy,
        408 || 504 => ApiFailureKind.timeout,
        _ => ApiFailureKind.unavailable,
      };
      DateTime? retryAt;
      if (code == 429) {
        retryAt = _retryAt(response.headers['retry-after']);
        if (accountRequest) {
          if (_cooldownUntil == null || retryAt.isAfter(_cooldownUntil!)) {
            _cooldownUntil = retryAt;
          }
        }
      }
      throw ApiFailure(
        kind,
        switch (kind) {
          ApiFailureKind.auth =>
            'OpenRouter rejected the API key. Check the key and retry.',
          ApiFailureKind.quota => 'OpenRouter reports a rate or credit limit. Check your account before retrying.',
          ApiFailureKind.policy => 'OpenRouter declined this request under its access or content policy.',
          ApiFailureKind.schema => 'OpenRouter could not accept this request. Refresh the model list or choose another model.',
          ApiFailureKind.timeout => 'OpenRouter did not finish in time. Your input is preserved for an explicit retry.',
          _ => 'OpenRouter is temporarily unavailable. Your input is preserved for an explicit retry.',
        },
        httpStatus: response.status,
        upstreamCode: upstreamCode,
        retryAt: retryAt,
      );
    }
    if (map == null) {
      throw accountRequest ? _completionSchema('choice_shape') : _badSchema;
    }
    return map;
  }

  DateTime _retryAt(String? raw) {
    final now = _now().toUtc();
    final seconds = raw == null ? null : int.tryParse(raw.trim());
    if (seconds != null && seconds >= 0 && seconds <= 315360000) {
      return now.add(Duration(seconds: seconds));
    }
    // HTTP IMF-fixdate parser, available on web without dart:io HttpDate.
    final match = raw == null
        ? null
        : RegExp(
            r'^[A-Za-z]{3}, (\d{2}) ([A-Za-z]{3}) (\d{4}) '
            r'(\d{2}):(\d{2}):(\d{2}) GMT$',
          ).firstMatch(raw.trim());
    if (match != null) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final month = months.indexOf(match[2]!) + 1;
      if (month > 0) {
        final date = DateTime.utc(
          int.parse(match[3]!),
          month,
          int.parse(match[1]!),
          int.parse(match[4]!),
          int.parse(match[5]!),
          int.parse(match[6]!),
        );
        if (!date.isBefore(now)) return date;
      }
    }
    return now.add(const Duration(seconds: 60));
  }

  static Uri? _nextPage(Map<String, dynamic> root, Uri current) {
    final links = root['links'];
    if (links == null) return null;
    if (links is! Map<String, dynamic>) throw _badSchema;
    final next = links['next'];
    if (next == null) return null;
    if (next is! String || next.isEmpty || next.length > 2048) throw _badSchema;
    final uri = current.resolve(next);
    if (uri.origin != _modelsUri.origin ||
        uri.path != _modelsUri.path ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw _badSchema;
    }
    return uri;
  }

  static _Admission _admit(List<Object?> rows) {
    if (rows.isEmpty || rows.length > _maxCatalogRows) throw _badSchema;
    final models = <String, ModelInfo>{};
    final accepted = <String, Map<String, dynamic>>{};
    final seen = <String>{};
    final duplicates = <String>{};
    var rejected = 0;
    for (final value in rows) {
      if (value is! Map<String, dynamic>) {
        rejected++;
        continue;
      }
      final id = value['id'];
      if (id is! String) {
        rejected++;
        continue;
      }
      if (!seen.add(id)) {
        // Duplicate entries are ambiguous even when one was already rejected.
        duplicates.add(id);
        models.remove(id);
        accepted.remove(id);
        continue;
      }
      final model = _parseModel(value);
      if (model == null) {
        rejected++;
        continue;
      }
      models[id] = model;
      accepted[id] = {
        'id': model.id,
        'name': model.name,
        'context_length': model.contextLength,
        'supported_parameters': model.supportedParameters.toList()..sort(),
        'architecture': value['architecture'],
        'pricing': value['pricing'],
        'description': model.description,
        if (model.maxCompletionTokens != null)
          'top_provider': {'max_completion_tokens': model.maxCompletionTokens},
      };
    }
    if (models.isEmpty) {
      throw const ApiFailure(
        ApiFailureKind.schema,
        'No models with verified zero pricing are currently available. Refresh later.',
      );
    }
    final ordered = models.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return _Admission(ordered, ordered.map((m) => accepted[m.id]!).toList(), [
      if (rejected > 0)
        '$rejected model records were excluded because free text inference could not be confirmed.',
      if (duplicates.isNotEmpty)
        '${duplicates.length} duplicate model identifiers were excluded.',
    ]);
  }

  static ModelInfo? _parseModel(Map<String, dynamic> row) {
    final id = row['id'];
    final name = row['name'];
    final context = row['context_length'];
    final parameters = row['supported_parameters'];
    final architecture = row['architecture'];
    final pricing = row['pricing'];
    final description = row['description'];
    final provider = row['top_provider'];
    final outputLimit = provider is Map<String, dynamic>
        ? provider['max_completion_tokens']
        : null;
    if (id is! String ||
        !_validId(id) ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 300 ||
        context is! int ||
        context < 1 ||
        context > 100000000 ||
        architecture is! Map<String, dynamic> ||
        architecture['input_modalities'] is! List ||
        (architecture['input_modalities'] as List).any((m) => m is! String) ||
        !(architecture['input_modalities'] as List).contains('text') ||
        architecture['output_modalities'] is! List ||
        (architecture['output_modalities'] as List).length != 1 ||
        !(architecture['output_modalities'] as List).contains('text') ||
        pricing is! Map<String, dynamic> ||
        !pricing.containsKey('prompt') ||
        !pricing.containsKey('completion') ||
        pricing.entries.any(
          (entry) => _optionalInputFees.contains(entry.key)
              ? !_validOptionalPrice(entry.value)
              : !_exactZero(entry.value),
        ) ||
        (description != null &&
            (description is! String || description.length > 20000)) ||
        (provider != null && provider is! Map<String, dynamic>) ||
        (outputLimit != null &&
            (outputLimit is! int ||
                outputLimit < 1 ||
                outputLimit > 100000000)) ||
        (parameters != null &&
            (parameters is! List || parameters.any((p) => p is! String)))) {
      return null;
    }
    return ModelInfo(
      id: id,
      name: name.trim(),
      contextLength: context,
      description: description is String ? description : '',
      maxCompletionTokens: outputLimit as int?,
      inputModalities: (architecture['input_modalities'] as List)
          .cast<String>(),
      pricing: pricing.cast<String, String>(),
      supportedParameters: parameters == null
          ? const []
          : (parameters as List).cast<String>(),
    );
  }

  // Trust only decimal strings. On JavaScript targets JSON 1e-999 underflows
  // to a number that also satisfies `is int`; numeric zero cannot prove that
  // the original price was zero. Provider-style strings retain that evidence.
  static bool _exactZero(Object? fee) =>
      fee is String && fee.length <= 128 && _zeroPrice.hasMatch(fee);

  static bool _validOptionalPrice(Object? fee) =>
      fee is String &&
      fee.length <= 128 &&
      (fee == '-1' || _decimalPrice.hasMatch(fee));

  static bool _validId(String id) =>
      id.length <= 200 &&
      _modelId.hasMatch(id) &&
      !id.toLowerCase().startsWith('openrouter/') &&
      !id.endsWith(':online');

  static bool _safeCitationUrl(String value) {
    if (value.length > 2048) return false;
    final uri = Uri.tryParse(value);
    return uri != null &&
        const {'http', 'https'}.contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  static int? _statusCode(Object? value) =>
      value is int && value >= 100 && value <= 599
      ? value
      : value is String && RegExp(r'^[1-5][0-9]{2}$').hasMatch(value)
      ? int.parse(value)
      : null;

  static Duration _boundedTimeout(Duration value, int maxSeconds) =>
      value > Duration.zero && value <= Duration(seconds: maxSeconds)
      ? value
      : Duration(seconds: maxSeconds);

  static ApiFailure _safeFailure(Object error, _Operation operation) {
    if (operation.failure != null) return operation.failure!;
    if (error is ApiFailure) return error;
    if (error is http.RequestAbortedException) return _cancelled;
    if (error is TimeoutException) return _timedOut;
    if (error is FormatException) return _badSchema;
    return const ApiFailure(
      ApiFailureKind.network,
      'Could not reach OpenRouter. Check your connection and retry explicitly.',
    );
  }

  static ApiFailure _completionSchema(String diagnosticCode) => ApiFailure(
    ApiFailureKind.schema,
    _badSchema.safeMessage,
    diagnosticCode: diagnosticCode,
  );

  static const _cancelled = ApiFailure(
    ApiFailureKind.cancelled,
    'Request cancelled. Your input is preserved.',
  );
  static const _timedOut = ApiFailure(
    ApiFailureKind.timeout,
    'OpenRouter did not finish in time. Your input is preserved for an explicit retry.',
  );
  static const _badSchema = ApiFailure(
    ApiFailureKind.schema,
    'OpenRouter returned unsupported or incomplete data. No estimate was accepted.',
  );
}

class _Admission {
  const _Admission(this.models, this.rows, this.issues);
  final List<ModelInfo> models;
  final List<Map<String, dynamic>> rows;
  final List<String> issues;
}

class _WireResponse {
  const _WireResponse(this.status, this.headers, this.bytes);
  final int status;
  final Map<String, String> headers;
  final Uint8List bytes;
}

class _Operation {
  _Operation(this.client, Duration timeout) {
    _timer = Timer(timeout, () => stop(OpenRouterClient._timedOut));
  }

  final http.Client client;
  final Completer<void> aborted = Completer<void>();
  final Completer<ApiFailure> _stopped = Completer<ApiFailure>();
  late final Timer _timer;
  ApiFailure? failure;
  bool _closed = false;

  void ensureActive() {
    if (failure != null) throw failure!;
  }

  Future<T> race<T>(Future<T> work) =>
      Future.any([work, _stopped.future.then<T>((failure) => throw failure)]);

  void stop(ApiFailure reason) {
    if (failure != null || _closed) return;
    failure = reason;
    aborted.complete();
    _stopped.complete(reason);
    close();
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _timer.cancel();
    client.close();
  }
}
