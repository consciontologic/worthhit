import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../domain/appraisal.dart';
import 'worthit_theme.dart';

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
      'askingPrice': draft.askingPrice?.toString() ?? '',
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
        final parsed = double.tryParse(value.trim());
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
      Text(label, style: Theme.of(context).textTheme.titleMedium),
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
        textCapitalization: name == 'currency'
            ? TextCapitalization.characters
            : TextCapitalization.sentences,
        onChanged: (value) => _update(name, value),
        decoration: InputDecoration(
          hintText: hint,
          helperText: helper,
          helperMaxLines: 3,
          errorText: name == 'askingPrice' ? _priceError : null,
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
    return SingleChildScrollView(
      controller: _scroll,
      padding: EdgeInsets.all(widget.compact ? 20 : 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Offstage(
            offstage: widget.compact && widget.step != 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.compact) ...[
                  Text(
                    'Good deals.\nLess guesswork.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                ],
                Text(
                  'What’s the item?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text(
                  'The specific model and its condition make the difference.',
                ),
                const SizedBox(height: 24),
                _field(
                  'product',
                  'Product',
                  'e.g. Sony WH-1000XM4 headphones',
                  maxLength: 300,
                ),
                const SizedBox(height: 20),
                Text(
                  'I’m looking to',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _goal('buy', 'Buy well', Icons.shopping_bag_outlined),
                    _goal('sell', 'Sell fairly', Icons.sell_outlined),
                  ],
                ),
                const SizedBox(height: 20),
                _pair(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Condition',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey('condition-${draft.condition}'),
                        initialValue:
                            const [
                              'Like new',
                              'Good',
                              'Fair',
                              'For parts',
                            ].contains(draft.condition)
                            ? draft.condition
                            : 'Good',
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'Like new',
                            child: Text('Like new'),
                          ),
                          DropdownMenuItem(value: 'Good', child: Text('Good')),
                          DropdownMenuItem(value: 'Fair', child: Text('Fair')),
                          DropdownMenuItem(
                            value: 'For parts',
                            child: Text('For parts / repair'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _write(draft.copyWith(condition: value));
                          }
                        },
                        decoration: const InputDecoration(
                          semanticCounterText: 'Item condition',
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
                  ),
                ),
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
                _field(
                  'details',
                  'The honest details',
                  'Age, wear, repairs, missing parts, accessories, warranty…',
                  lines: 3,
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
                  const SizedBox(height: 20),
                ],
                Text(
                  'Bring the evidence.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Recent, similar items in the same market tell a better story '
                  'than the original price.',
                ),
                const SizedBox(height: 20),
                _field(
                  'evidence',
                  'Comparable listings or sold prices',
                  'Paste source links and excerpts. Include price, currency, '
                      'date, condition, and whether each item actually sold.',
                  lines: 5,
                  maxLength: 20000,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Use public listing information. Leave out names, phone '
                  'numbers, addresses, and private messages.',
                  style: TextStyle(
                    color: WorthitColors.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Material(
                  color: WorthitColors.soft,
                  borderRadius: BorderRadius.circular(6),
                  child: SwitchListTile.adaptive(
                    key: const ValueKey('web-search-toggle'),
                    value: widget.controller.webSearch,
                    onChanged: widget.controller.busy
                        ? null
                        : widget.controller.setWebSearch,
                    contentPadding: const EdgeInsets.all(12),
                    title: const Text(
                      'Research the web too',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Adds OpenRouter search fees, even with a free model '
                      '(about \$0.007 per search; pricing may change). '
                      'Off by default.',
                    ),
                    activeTrackColor: WorthitColors.lime,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'A useful estimate needs enough comparable evidence. '
                  'If it’s missing, Worthit will ask instead of making up a price.',
                ),
              ],
            ),
          ),
          if (!widget.compact) ...[
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.controller.busy || _priceError != null
                    ? null
                    : widget.onSubmit,
                icon: const Icon(Icons.arrow_forward, size: 20),
                label: const Text('Find a fair price'),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Ctrl / Command + Enter to check',
                style: TextStyle(fontSize: 12, color: WorthitColors.muted),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _goal(String value, String label, IconData icon) {
    final selected = widget.controller.draft.goal == value;
    return Semantics(
      selected: selected,
      child: OutlinedButton.icon(
        onPressed: () => _write(widget.controller.draft.copyWith(goal: value)),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? WorthitColors.lime : Colors.white,
          side: BorderSide(color: WorthitColors.ink, width: selected ? 2 : 1.5),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}
