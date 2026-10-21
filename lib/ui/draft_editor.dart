import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../domain/appraisal.dart';
import '../l10n/app_strings.dart';
import 'worthhit_theme.dart';
import 'selectable_surface.dart';
import 'worthhit_icons.dart';
import 'product_media_controls.dart';

/// A single retained form; layout changes never replace its editors or focus.
class DraftEditor extends StatefulWidget {
  const DraftEditor({
    super.key,
    required this.controller,
    required this.compact,
    required this.onSubmit,
  });
  final AppController controller;
  final bool compact;
  final VoidCallback onSubmit;
  @override
  State<DraftEditor> createState() => DraftEditorState();
}

class DraftEditorState extends State<DraftEditor> {
  final _fields = <String, TextEditingController>{};
  final _focus = <String, FocusNode>{};
  final _scroll = ScrollController();
  AppraisalInput? _lastDraft;

  bool validateForSubmit() => true;

  @override
  void initState() {
    super.initState();
    for (final name in ['product', 'currency', 'details']) {
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
  }

  void _sync() {
    final draft = widget.controller.draft;
    if (identical(_lastDraft, draft)) return;
    _lastDraft = draft;
    final values = {
      'product': draft.product,
      'currency': draft.currency,
      'details': draft.details,
    };
    for (final entry in values.entries) {
      final field = _fields[entry.key]!;
      if (field.text != entry.value) {
        field.value = TextEditingValue(
          text: entry.value,
          selection: TextSelection.collapsed(offset: entry.value.length),
        );
      }
    }
  }

  void _update(String name, String value) {
    final draft = widget.controller.draft;
    widget.controller.updateDraft(switch (name) {
      'product' => draft.copyWith(product: value),
      'currency' => draft.copyWith(currency: value),
      _ => draft.copyWith(details: value),
    });
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

  Widget _field(
    String name,
    String label,
    String hint, {
    int lines = 1,
    int? maxLength,
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
                  (old, next) => next.copyWith(text: next.text.toUpperCase()),
                ),
              ]
            : null,
        textDirection: name == 'currency' ? TextDirection.ltr : null,
        textCapitalization: name == 'currency'
            ? TextCapitalization.characters
            : TextCapitalization.sentences,
        onChanged: (value) => _update(name, value),
        decoration: InputDecoration(
          hintText: AppStrings.of(context).text(hint),
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
                    DropdownMenuItem(value: 'Good', child: AppText('Good')),
                    DropdownMenuItem(value: 'Fair', child: AppText('Fair')),
                    DropdownMenuItem(
                      value: 'For parts',
                      child: AppText('For parts / repair'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      widget.controller.updateDraft(
                        draft.copyWith(condition: value),
                      );
                    }
                  },
                  decoration: InputDecoration(
                    semanticCounterText: AppStrings.of(context)
                        .text('Item condition'),
                  ),
                ),
              ],
            ),
            _field('currency', 'Currency', 'TRY, USD, EUR…', maxLength: 3),
          ),
          const SizedBox(height: 16),
          _field(
            'details',
            'Notes (optional)',
            'Anything else about the item: age, wear, accessories, location…',
            lines: 2,
            maxLength: 4000,
          ),
          const SizedBox(height: 16),
          ProductMediaControls(controller: widget.controller),
          const SizedBox(height: 16),
          Material(
            color: WorthhitPalette.of(context).soft,
            borderRadius: BorderRadius.circular(2),
            child: SwitchListTile.adaptive(
              key: const ValueKey('web-search-toggle'),
              value: widget.controller.webSearch,
              onChanged:
                  widget.controller.busy ||
                      (!widget.controller.webSearch &&
                          !(widget.controller.selectedModel?.supportsTools ??
                              false))
                  ? null
                  : widget.controller.setWebSearch,
              contentPadding: const EdgeInsets.all(12),
              title: const AppText(
                'Research the web too',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const AppText(
                r'Adds OpenRouter search fees, even with a free model (about $0.007 per search; pricing may change). Off by default.',
              ),
              activeTrackColor: WorthhitPalette.of(context).lime,
            ),
          ),
          const SizedBox(height: 8),
          AppText(
            widget.controller.webSearch
                ? 'Live web search enabled; search fees apply.'
                : 'No live web search. The estimate will be labeled as unverified.',
            style: const TextStyle(fontSize: 12),
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
          child: SizedBox(
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
                onPressed: widget.controller.busy ? null : widget.onSubmit,
                icon: const Icon(WorthhitIcons.arrow_forward, size: 20),
                label: const AppText('Find a fair price'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
