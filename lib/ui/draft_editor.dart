import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../domain/appraisal.dart';
import '../l10n/app_strings.dart';
import 'worthhit_theme.dart';
import 'selectable_surface.dart';
import 'worthhit_icons.dart';

/// Kept under one GlobalKey while the shell changes its navigation pattern.
/// Controllers and focus nodes belong to this state, not to device layouts.
class DraftEditor extends StatefulWidget {
  const DraftEditor({
    super.key,
    required this.controller,
    required this.compact,
    required this.step,
    required this.onSubmit,
  });

  final AppController controller;
  final bool compact;
  final int step;
  final VoidCallback onSubmit;

  @override
  State<DraftEditor> createState() => DraftEditorState();
}

class DraftEditorState extends State<DraftEditor> {
  final _fields = <String, TextEditingController>{};
  final _focus = <String, FocusNode>{};
  final _scroll = ScrollController();
  String? _priceError;
  AppraisalInput? _lastDraft;
  bool _editing = false;
  AppStrings? _strings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = AppStrings.of(context);
    if (!identical(next, _strings)) {
      _strings = next;
      if (_priceError == null && widget.controller.draft.askingPrice != null) {
        final field = _fields['askingPrice']!;
        final text = next.formatAmount(widget.controller.draft.askingPrice!);
        field.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    }
  }

  bool validateForSubmit() {
    if (_priceError == null) return true;
    _focus['askingPrice']!.requestFocus();
    return false;
  }

  @override
  void initState() {
    super.initState();
    for (final name in [
      'product',
      'location',
      'currency',
      'askingPrice',
      'details',
      'evidence',
    ]) {
      _fields[name] = TextEditingController();
      _focus[name] = FocusNode(debugLabel: name);
    }
    _sync();
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(covariant DraftEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _sync();
    }
    if (oldWidget.compact == widget.compact &&
        oldWidget.step != widget.step &&
        _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  void _sync() {
    final draft = widget.controller.draft;
    if (identical(_lastDraft, draft)) return;
    _lastDraft = draft;
    final values = {
      'product': draft.product,
      'location': draft.location,
      'currency': draft.currency,
      'askingPrice': draft.askingPrice == null
          ? ''
          : (_strings?.formatAmount(draft.askingPrice!) ??
                draft.askingPrice!.toString()),
      'details': draft.details,
      'evidence': draft.evidence,
    };
    for (final entry in values.entries) {
      final field = _fields[entry.key]!;
      if (entry.key == 'askingPrice') {
        // Keep unfinished decimal input during editing. A new draft or example
        // must still replace invalid local text and clear its validation error.
        if (_editing) continue;
        _priceError = null;
      }
      if (field.text != entry.value) {
        field.value = TextEditingValue(
          text: entry.value,
          selection: TextSelection.collapsed(offset: entry.value.length),
        );
      }
    }
  }

  void _write(AppraisalInput draft) {
    _editing = true;
    try {
      widget.controller.updateDraft(draft);
    } finally {
      _editing = false;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    for (final controller in _fields.values) {
      controller.dispose();
    }
    for (final node in _focus.values) {
      node.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _update(String name, String value) {
    final draft = widget.controller.draft;
    switch (name) {
      case 'product':
        _write(draft.copyWith(product: value));
      case 'location':
        _write(draft.copyWith(location: value));
      case 'currency':
        _write(draft.copyWith(currency: value));
      case 'askingPrice':
        final parsed = AppStrings.of(context).parseAmount(value);
        setState(() {
          _priceError =
              value.trim().isNotEmpty &&
                  (parsed == null || !parsed.isFinite || parsed < 0)
              ? 'Enter a positive amount, or leave this blank.'
              : null;
        });
        if (_priceError == null) {
          _write(draft.copyWith(askingPrice: parsed));
        }
      case 'details':
        _write(draft.copyWith(details: value));
      case 'evidence':
        _write(draft.copyWith(evidence: value));
    }
  }

  Widget _field(
    String name,
    String label,
    String hint, {
    int lines = 1,
    int? maxLength,
    TextInputType? keyboard,
    String? helper,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(label, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      TextField(
        key: ValueKey('$name-field'),
        controller: _fields[name],
        focusNode: _focus[name],
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 4,
        maxLength: maxLength,
        inputFormatters: name == 'currency'
            ? [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      newValue.copyWith(text: newValue.text.toUpperCase()),
                ),
              ]
            : null,
        keyboardType: keyboard,
        textDirection: name == 'currency' || name == 'askingPrice'
            ? TextDirection.ltr
            : null,
        textCapitalization: name == 'currency'
            ? TextCapitalization.characters
            : TextCapitalization.sentences,
        onChanged: (value) => _update(name, value),
        decoration: InputDecoration(
          hintText: AppStrings.of(context).text(hint),
          suffixIcon: helper == null
              ? null
              : ContextHelp(title: label, child: AppText(helper)),
          errorText: name == 'askingPrice' && _priceError != null
              ? AppStrings.of(context).text(_priceError!)
              : null,
          errorMaxLines: 3,
          counterText: '',
        ),
      ),
    ],
  );

  Widget _pair(Widget a, Widget b) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
      final width = constraints.maxWidth < 450 || largeText
          ? constraints.maxWidth
          : (constraints.maxWidth - 16) / 2;
      return Wrap(
        spacing: 16,
        runSpacing: 20,
        children: [
          SizedBox(width: width, child: a),
          SizedBox(width: width, child: b),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final draft = widget.controller.draft;
    final form = SingleChildScrollView(
      controller: _scroll,
      padding: EdgeInsets.all(widget.compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Offstage(
            offstage: widget.compact && widget.step != 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        'What’s the item?',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const ContextHelp(
                      title: 'Item guidance',
                      child: AppText(
                        'The specific model and its condition make the difference.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(
                  'product',
                  'Product',
                  'e.g. Sony WH-1000XM4 headphones',
                  maxLength: 300,
                ),
                const SizedBox(height: 16),
                _pair(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Condition',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey('condition-${draft.condition}'),
                        initialValue:
                            [
                              'Like new',
                              'Good',
                              'Fair',
                              'For parts',
                            ].contains(draft.condition)
                            ? draft.condition
                            : 'Good',
                        isExpanded: true,
                        icon: const Icon(WorthhitIcons.expand_more, size: 18),
                        items: const [
                          DropdownMenuItem(
                            value: 'Like new',
                            child: AppText('Like new'),
                          ),
                          DropdownMenuItem(
                            value: 'Good',
                            child: AppText('Good'),
                          ),
                          DropdownMenuItem(
                            value: 'Fair',
                            child: AppText('Fair'),
                          ),
                          DropdownMenuItem(
                            value: 'For parts',
                            child: AppText('For parts / repair'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _write(draft.copyWith(condition: value));
                          }
                        },
                        decoration: InputDecoration(
                          semanticCounterText: AppStrings.of(context)
                              .text('Item condition'),
                        ),
                      ),
                    ],
                  ),
                  _field(
                    'askingPrice',
                    'Asking price (optional)',
                    'Amount only',
                    keyboard: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    maxLength: 16,
                    helper: 'Use a decimal separator, without digit grouping.',
                  ),
                ),
                const SizedBox(height: 16),
                _pair(
                  _field(
                    'location',
                    'Market / location',
                    'e.g. Istanbul, Türkiye',
                    maxLength: 160,
                  ),
                  _field(
                    'currency',
                    'Currency',
                    'TRY, USD, EUR…',
                    maxLength: 3,
                  ),
                ),
                const SizedBox(height: 16),
                _field(
                  'details',
                  'Item details',
                  'Age, wear, repairs, missing parts, accessories, warranty…',
                  lines: 2,
                  maxLength: 4000,
                ),
              ],
            ),
          ),
          Offstage(
            offstage: widget.compact && widget.step != 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.compact) ...[
                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        'The evidence',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const ContextHelp(
                      title: 'Evidence guidance',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            'Recent, similar items in the same market tell a better story '
                            'than the original price.',
                          ),
                          SizedBox(height: 12),
                          AppText(
                            'A useful estimate needs enough comparable evidence. '
                            'If it’s missing, Worthhit will ask instead of making up a price.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(
                  'evidence',
                  'Comparable listings or sold prices',
                  'Paste source links and excerpts. Include price, currency, '
                      'date, condition, and whether each item actually sold.',
                  lines: 5,
                  maxLength: 20000,
                ),
                const SizedBox(height: 12),
                AppText(
                  'Use public listing information. Leave out names, phone '
                  'numbers, addresses, and private messages.',
                  style: TextStyle(
                    color: WorthhitPalette.of(context).muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Material(
                  color: WorthhitPalette.of(context).soft,
                  borderRadius: BorderRadius.circular(2),
                  child: SwitchListTile.adaptive(
                    key: const ValueKey('web-search-toggle'),
                    value: widget.controller.webSearch,
                    onChanged: widget.controller.busy
                        ? null
                        : widget.controller.setWebSearch,
                    contentPadding: const EdgeInsets.all(12),
                    title: const AppText(
                      'Research the web too',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const AppText(
                      'Adds OpenRouter search fees, even with a free model '
                      '(about \$0.007 per search; pricing may change). '
                      'Off by default.',
                    ),
                    activeTrackColor: WorthhitPalette.of(context).lime,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
    if (widget.compact) return form;
    return Column(
      children: [
        Expanded(child: form),
        Container(
          key: const ValueKey('editor-actions'),
          width: double.infinity,
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 8),
          decoration: BoxDecoration(
            color: WorthhitPalette.of(context).surface,
            border: Border(
              top: BorderSide(color: WorthhitPalette.of(context).line),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: SelectableTooltip(
                  message: AppStrings.of(context)
                      .text('Ctrl / Command + Enter to check'),
                  child: FilledButton.icon(
                    key: const ValueKey('appraisal-submit'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    onPressed: widget.controller.busy || _priceError != null
                        ? null
                        : widget.onSubmit,
                    icon: const Icon(WorthhitIcons.arrow_forward, size: 20),
                    label: const AppText('Find a fair price'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
