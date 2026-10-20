import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../api/open_router_client.dart';
import '../domain/appraisal.dart';
import '../platform/local_store.dart';

class AppController extends ChangeNotifier {
  AppController({OpenRouterClient? api, LocalStore? store})
    : api = api ?? OpenRouterClient(),
      store = store ?? createLocalStore();
  final OpenRouterClient api;
  final LocalStore store;
  AppraisalInput draft = AppraisalInput();
  AppraisalResult? result;
  List<ModelInfo> models = [];
  ModelInfo? selectedModel;
  String apiKey = '';
  bool busy = false, catalogLoading = false, webSearch = false;
  String? error, persistenceError;
  String statusText =
      'Your key stays in this tab. Your draft stays on this device.';
  bool isExample = false, updateAvailable = false;
  bool _disposed = false;
  bool _checkingUpdate = false;
  Timer? _updateTimer;
  Future<void>? _catalogRefresh;
  int _attempt = 0;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    try {
      final saved = store.read('worthit.draft.v1');
      if (saved != null) {
        if (saved.length > 100000) {
          throw const FormatException('Oversized draft');
        }
        final data = jsonDecode(saved) as Map<String, dynamic>;
        draft = AppraisalInput.fromJson(data['input'] as Map<String, dynamic>);
        isExample = data['example'] == true || _hasSyntheticEvidence(draft);
      }
      final report = store.read('worthit.last-report.v1');
      if (report != null) {
        if (report.length > 150000) {
          throw const FormatException('Oversized report');
        }
        final data = jsonDecode(report) as Map<String, dynamic>;
        final previousInput = AppraisalInput.fromJson(
          data['input'] as Map<String, dynamic>,
        );
        final previousResult = AppraisalResult.fromJson(
          data['result'] as Map<String, dynamic>,
        );
        if (jsonEncode(previousInput.toJson()) == jsonEncode(draft.toJson())) {
          result = previousResult;
          isExample = isExample || data['example'] == true;
        }
      }
      final catalog = store.read('worthit.catalog.v1');
      if (catalog != null) {
        api.seedCatalog(catalog);
        models = api.snapshot?.models ?? [];
      }
    } catch (_) {
      persistenceError = 'Saved data could not be read. It has not been erased. You can start a new check or export your work.';
    }
    _changed();
    await refreshModels();
    if (_disposed) return;
    _updateTimer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_checkForUpdate()),
    );
    await _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    if (_disposed || _checkingUpdate || updateAvailable) return;
    _checkingUpdate = true;
    try {
      final waiting = await store.hasWaitingUpdate();
      if (_disposed) return;
      if (waiting) {
        updateAvailable = true;
        _updateTimer?.cancel();
        _changed();
      }
    } catch (_) {
      // PWA support varies; a later check may recover without gating appraisal.
    } finally {
      _checkingUpdate = false;
    }
  }

  bool _hasSyntheticEvidence(AppraisalInput value) =>
      value.evidence.contains('https://example.com/synthetic-lamp-');

  bool _save() {
    try {
      store.write(
        'worthit.draft.v1',
        jsonEncode({'input': draft.toJson(), 'example': isExample}),
      );
      persistenceError = null;
      return true;
    } catch (_) {
      persistenceError = 'This browser could not save your draft. Keep this tab open or download a report before leaving.';
      return false;
    }
  }

  void updateDraft(AppraisalInput value) {
    if (jsonEncode(value.toJson()) == jsonEncode(draft.toJson())) return;
    if (busy) cancel();
    draft = value;
    result = null;
    error = null;
    isExample = _hasSyntheticEvidence(value);
    _save();
    _changed();
  }

  void setApiKey(String value) {
    if (busy) cancel();
    apiKey = value.trim();
    error = null;
    _changed();
  }

  void setWebSearch(bool value) {
    if (busy) cancel();
    webSearch = value;
    _changed();
  }

  void selectModel(ModelInfo? value) {
    if (busy) cancel();
    selectedModel = value;
    error = null;
    _changed();
  }

  Future<void> refreshModels() {
    if (_disposed) return Future<void>.value();
    final pending = _catalogRefresh;
    if (pending != null) return pending;
    // Publish the shared future before notifying listeners so a reentrant
    // caller also joins the current refresh.
    final completion = Completer<void>();
    _catalogRefresh = completion.future;
    completion.complete(_refreshModels());
    return completion.future;
  }

  Future<void> _refreshModels() async {
    catalogLoading = true;
    _changed();
    try {
      final fresh = await api.refreshCatalog();
      if (_disposed) return;
      models = fresh.models;
      if (selectedModel != null) {
        final matches = models.where((m) => m.id == selectedModel!.id);
        if (matches.isEmpty ||
            !setEquals(
              matches.first.supportedParameters,
              selectedModel!.supportedParameters,
            )) {
          selectedModel = null;
          statusText =
              'Your selected model changed. Choose from the refreshed list.';
        } else {
          selectedModel = matches.first;
        }
      }
      if (selectedModel == null) {
        statusText =
            '${models.length} free text models available. Choose one in Connection.';
      }
      final cached = api.exportCatalog();
      if (cached != null) {
        try {
          store.write('worthit.catalog.v1', cached);
        } catch (_) {
          persistenceError = 'The model list could not be saved. Refresh it next time you visit.';
        }
      }
    } on ApiFailure catch (failure) {
      if (_disposed) return;
      error = failure.safeMessage;
      models = api.snapshot?.models ?? models;
    } catch (_) {
      if (_disposed) return;
      error =
          'The model list could not be refreshed. Try Refresh models again.';
    } finally {
      catalogLoading = false;
      _catalogRefresh = null;
      _changed();
    }
  }

  Future<void> inspectSelected() async {
    if (_disposed) return;
    final selected = selectedModel;
    if (selected == null) {
      error = 'Choose a model first.';
      _changed();
      return;
    }
    try {
      statusText = 'Checking the selected model’s provider metadata…';
      _changed();
      final info = await api.inspectEndpoints(selected);
      if (_disposed || selectedModel?.id != selected.id) return;
      statusText = info.providers.isEmpty
          ? 'No provider metadata is available. This is not an inference test.'
          : '${info.providers.join(', ')}. Metadata only; availability is not guaranteed.';
    } on ApiFailure catch (failure) {
      if (_disposed || selectedModel?.id != selected.id) return;
      error = failure.safeMessage;
    } catch (_) {
      if (_disposed || selectedModel?.id != selected.id) return;
      error = 'Provider metadata could not be checked. Your draft is safe.';
    }
    _changed();
  }

  Future<void> appraise({String responseLanguage = 'en'}) async {
    if (busy) return;
    error = null;
    if (isExample || _hasSyntheticEvidence(draft)) {
      error = 'Replace the synthetic example evidence with real listing excerpts before requesting an appraisal.';
      _changed();
      return;
    }
    final validation = draft.validate() ?? blockedItemReason(draft);
    if (validation != null) {
      error = validation;
      _changed();
      return;
    }
    if (apiKey.isEmpty || selectedModel == null) {
      error =
          'Open Connection, add your OpenRouter key and choose a free model.';
      _changed();
      return;
    }
    if (!webSearch && draft.evidence.trim().isEmpty) {
      error = 'Paste dated comparable listing excerpts in Evidence, or explicitly enable paid web research. A description alone is not price evidence.';
      _changed();
      return;
    }
    final id = ++_attempt;
    final input = draft.copyWith(asOf: DateTime.now().toUtc());
    final model = selectedModel!;
    final key = apiKey;
    final search = webSearch;
    busy = true;
    isExample = false;
    statusText = search
        ? 'Researching one bounded web search and checking the evidence…'
        : 'Reading your supplied evidence…';
    _save();
    _changed();
    try {
      if (api.snapshot?.isStale != false) {
        await refreshModels();
        if (id != _attempt || _disposed) return;
        if (selectedModel?.id != model.id) {
          error = 'The catalog changed. Choose a model and try again.';
          return;
        }
      }
      final system = await rootBundle.loadString(
        'assets/appraisal_system_v1.txt',
      );
      if (id != _attempt || _disposed) return;
      final response = await api.complete(
        apiKey: key,
        model: selectedModel!,
        messages: [
          {
            'role': 'system',
            'content':
                '$system\n\n${_responseLanguageInstruction(responseLanguage)}',
          },
          {'role': 'user', 'content': buildUserPrompt(input)},
        ],
        schema: appraisalSchema(),
        webSearch: search,
      );
      if (id != _attempt || _disposed) return;
      result = parseAppraisal(
        response.content,
        input: input,
        citedUrls: response.citedUrls,
        citations: response.citations,
      );
      draft = input;
      statusText = result!.status == AppraisalStatus.ready
          ? 'Estimate calculated from the accepted comparable evidence.'
          : 'Evidence reviewed. See what is needed before estimating a price.';
      _save();
      try {
        store.write(
          'worthit.last-report.v1',
          jsonEncode({
            'input': input.toJson(),
            'result': result!.toJson(),
            'model': response.actualModel,
            'example': false,
          }),
        );
      } catch (_) {
        persistenceError = 'Your result is visible but could not be saved. Download it before leaving.';
      }
    } on ApiFailure catch (failure) {
      if (id == _attempt) error = failure.safeMessage;
    } on FormatException {
      if (id == _attempt) error = 'The model returned an invalid or unsupported appraisal. No price was accepted. Choose another model or retry explicitly.';
    } catch (_) {
      if (id == _attempt) error = 'The check could not finish. Your draft is safe. Review the connection and try again.';
    } finally {
      if (id == _attempt) {
        busy = false;
        _changed();
      }
    }
  }

  void cancel() {
    _attempt++;
    api.cancel();
    busy = false;
    statusText =
        'Check cancelled. Your draft is safe; no request was replayed.';
    _changed();
  }

  void clearDraft() {
    cancel();
    draft = AppraisalInput();
    result = null;
    error = null;
    isExample = false;
    _save();
    try {
      store.remove('worthit.last-report.v1');
    } catch (_) {
      persistenceError = 'The saved report could not be removed. Clear site data in your browser to remove it.';
    }
    _changed();
  }

  Future<void> loadExample() async {
    cancel();
    final date = DateTime.now().toUtc();
    final rows = <Map<String, dynamic>>[], snippets = <String>[];
    final day = date.toIso8601String().substring(0, 10);
    for (var i = 0; i < 3; i++) {
      final amount = [100, 120, 140][i];
      final url = 'https://example.com/synthetic-lamp-${i + 1}';
      final quote =
          'Arc desk lamp, Good condition, original cable, London UK, item only. Sold for GBP $amount on $day.';
      snippets.add('$url\n$quote');
      rows.add({
        'url': url,
        'title': 'Arc desk lamp — synthetic example ${i + 1}',
        'kind': 'sold',
        'amount': amount,
        'currency': 'GBP',
        'event_date': day,
        'condition': 'Good',
        'match': 'exact',
        'price_basis': 'item_only',
        'support_quote': quote,
      });
    }
    draft = AppraisalInput(
      product: 'Arc desk lamp',
      condition: 'Good',
      location: 'London, UK',
      currency: 'GBP',
      details: 'Fully working. Original cable included. No visible defects.',
      evidence: snippets.join('\n\n'),
      goal: 'buy',
      asOf: date,
    );
    result = parseAppraisal(
      jsonEncode({
        'version': 'worthit.v1',
        'status': 'ready',
        'reason':
            'Synthetic example. These are invented demonstration listings.',
        'currency': 'GBP',
        'item_summary': 'Arc desk lamp · Good condition',
        'comparables': rows,
        'factors': ['Three invented sales demonstrate the calculation.'],
        'cautions': ['Example only. This is not a real market appraisal.'],
        'questions': <String>[],
      }),
      input: draft,
    );
    isExample = true;
    error = null;
    statusText = 'Synthetic example — no API request was made.';
    _save();
    try {
      store.write(
        'worthit.last-report.v1',
        jsonEncode({
          'input': draft.toJson(),
          'result': result!.toJson(),
          'example': true,
        }),
      );
    } catch (_) {
      persistenceError = 'The example could not be saved. Your real data was not sent anywhere.';
    }
    _changed();
  }

  Future<void> exportReport() async {
    try {
      store.download(
        'worthhit-report.json',
        const JsonEncoder.withIndent('  ').convert({
          'format': 'worthit.report.v1',
          'example': isExample,
          'input': draft.toJson(),
          'result': result?.toJson(),
          'notice':
              'An estimate from evidence, not a guaranteed transaction price.',
        }),
      );
    } catch (_) {
      error = 'The report could not be downloaded. You can still select and copy it.';
      _changed();
    }
  }

  Future<void> applyUpdate() async {
    if (busy) {
      error = 'Finish or cancel the check before updating.';
      _changed();
      return;
    }
    if (!_save()) {
      _changed();
      return;
    }
    try {
      await store.applyUpdate();
    } catch (_) {
      error = 'The update could not be activated. Your saved draft is safe.';
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _attempt++;
    _updateTimer?.cancel();
    api.dispose();
    apiKey = '';
    super.dispose();
  }
}

// Only this fixed allowlist can contribute to the trusted system directive.
// Never interpolate raw locale text, user content or translated UI copy here.
String _responseLanguageInstruction(String code) {
  const languages = {
    'en': 'English',
    'tr': 'Turkish',
    'de': 'German',
    'fr': 'French',
    'es': 'Spanish',
    'pt': 'Portuguese',
    'ar': 'Arabic',
    'zh': 'Simplified Chinese',
  };
  final language = languages[code] ?? languages['en']!;
  return 'RESPONSE LANGUAGE\n'
      'Write explanatory prose in $language. '
      'Translate only reason, item_summary, factors, cautions and questions. '
      'Keep JSON keys, version identifiers, schema enums, ISO currency codes '
      'and ISO dates unchanged. Keep source titles, URLs, evidence and '
      'support_quote verbatim in their original language. Never translate or '
      'rewrite quotations to fit evidence admission. All safety, evidence '
      'and output requirements above still apply.';
}
