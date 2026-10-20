import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../domain/appraisal.dart';
import 'worthit_theme.dart';

class ResultPanel extends StatelessWidget {
  const ResultPanel({
    super.key,
    required this.controller,
    required this.onEdit,
  });

  final AppController controller;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('result-panel'),
    padding: const EdgeInsets.all(26),
    child: SelectionArea(
      child: controller.busy
          ? _working(context)
          : controller.result == null
          ? _empty(context)
          : _result(context, controller.result!),
    ),
  );

  Widget _empty(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.receipt_long_outlined, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your price check',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      const SizedBox(height: 38),
      Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: WorthitColors.lime,
          border: Border.all(color: WorthitColors.ink, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: WorthitColors.ink, offset: Offset(5, 5)),
          ],
        ),
        child: const Icon(Icons.balance_outlined, size: 48),
      ),
      const SizedBox(height: 30),
      Text(
        'A fair price starts with good evidence.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 14),
      const Text(
        'Describe the item and bring comparable prices. We’ll put the range, '
        'the reasons, and the unknowns in one place.',
      ),
      const SizedBox(height: 30),
      const Divider(),
      const SizedBox(height: 16),
      _explanation(
        context,
        Icons.compare_arrows,
        'Comparable, not just similar',
        'Model, condition, market, and date matter.',
      ),
      const SizedBox(height: 18),
      _explanation(
        context,
        Icons.visibility_outlined,
        'See where the price comes from',
        'Source excerpts stay attached to the estimate.',
      ),
      const SizedBox(height: 18),
      _explanation(
        context,
        Icons.handshake_outlined,
        'A calmer way to negotiate',
        'Use the facts. Leave pressure and guesswork out.',
      ),
      const SizedBox(height: 28),
      OutlinedButton.icon(
        onPressed: controller.loadExample,
        icon: const Icon(Icons.play_arrow_outlined),
        label: const Text('Explore a synthetic example'),
      ),
      const SizedBox(height: 16),
      const Text(
        'An estimate is a starting point, not a guaranteed sale price.',
        style: TextStyle(fontSize: 12, color: WorthitColors.muted, height: 1.5),
      ),
    ],
  );

  Widget _explanation(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(description),
          ],
        ),
      ),
    ],
  );

  Widget _working(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Checking the evidence…',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 18),
        Text(controller.statusText),
        const SizedBox(height: 28),
        const LinearProgressIndicator(minHeight: 7),
        const SizedBox(height: 22),
        const Text(
          'Comparing the item, checking the sources, and keeping uncertainty '
          'visible. Your draft stays here if the request fails.',
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: controller.cancel,
          icon: const Icon(Icons.close),
          label: const Text('Cancel price check'),
        ),
      ],
    ),
  );

  Widget _result(BuildContext context, AppraisalResult result) {
    final ready = result.status == AppraisalStatus.ready;
    final title = switch (result.status) {
      AppraisalStatus.ready => 'Here’s the price picture.',
      AppraisalStatus.needsDetails => 'A few details first.',
      AppraisalStatus.insufficientEvidence => 'We need stronger evidence.',
      AppraisalStatus.blocked => 'This item can’t be appraised.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.isExample) ...[
          const StatusNotice(
            message:
                'Synthetic example — invented listings and prices for '
                'demonstration. Not market evidence.',
          ),
          const SizedBox(height: 20),
        ],
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
          'Check date: '
          '${controller.draft.asOf.toUtc().toIso8601String().split('T').first} '
          '(UTC). Saved reports do not refresh automatically.',
          style: const TextStyle(fontSize: 12, color: WorthitColors.muted),
        ),
        const SizedBox(height: 12),
        if (result.itemSummary.isNotEmpty) ...[
          Text(
            result.itemSummary,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
        ],
        Text(result.reason),
        if (ready &&
            result.low != null &&
            result.median != null &&
            result.high != null) ...[
          const SizedBox(height: 26),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: WorthitColors.lime,
              border: Border.all(color: WorthitColors.ink, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: WorthitColors.ink, offset: Offset(4, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Observed comparable range',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  '${_number(result.low!)} – ${_number(result.high!)}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${result.currency} · median ${_number(result.median!)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'An evidence-based estimate, not a guaranteed transaction '
                  'price. Asking prices may differ from final sales.',
                ),
              ],
            ),
          ),
        ],
        if (result.factors.isNotEmpty)
          _list(context, 'What moves the price', result.factors),
        if (result.cautions.isNotEmpty)
          _list(context, 'Keep in mind', result.cautions),
        if (result.questions.isNotEmpty)
          _list(context, 'What to check next', result.questions),
        if (result.comparables.isNotEmpty) ...[
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 18),
          Text('The evidence', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'Source descriptions are supplied or reported by the model. '
            'Open and verify a listing before relying on it.',
            style: TextStyle(fontSize: 12, color: WorthitColors.muted),
          ),
          for (final comparable in result.comparables)
            _comparable(context, comparable),
        ],
        if (result.rejectedReasons.isNotEmpty) ...[
          const SizedBox(height: 24),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Evidence left out'),
            children: [
              for (final reason in result.rejectedReasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(reason),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 28),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Refine the details'),
            ),
            OutlinedButton.icon(
              onPressed: controller.exportReport,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export report'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'A fair deal also depends on inspection, safe payment, and clear '
          'terms. This check cannot verify authenticity or a seller’s identity.',
          style: TextStyle(
            fontSize: 12,
            color: WorthitColors.muted,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _list(BuildContext context, String title, List<String> items) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 26),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(Icons.remove, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      );

  Widget _comparable(BuildContext context, Comparable comparable) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(comparable.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '${_number(comparable.amount)} ${comparable.currency} · '
          '${_kind(comparable.kind)} · ${_basis(comparable.priceBasis)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${comparable.condition} · ${comparable.eventDate == null ? 'Date '
                    'not supplied' : comparable.eventDate!.toIso8601String().split('T').first}',
          style: const TextStyle(fontSize: 12, color: WorthitColors.muted),
        ),
        if (comparable.supportQuote.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('“${comparable.supportQuote}”'),
        ],
        const SizedBox(height: 8),
        Text(
          comparable.url,
          style: const TextStyle(
            decoration: TextDecoration.underline,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        const Divider(height: 1),
      ],
    ),
  );

  String _number(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  String _kind(String value) => switch (value) {
    'sold' => 'Sold',
    'asking' => 'Asking price',
    'retail' => 'Retail price',
    _ => 'Unspecified source',
  };

  String _basis(String value) => switch (value) {
    'item_only' => 'item only',
    'delivered' => 'includes delivery',
    _ => 'delivery costs unclear',
  };
}
