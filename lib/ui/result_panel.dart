import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../domain/appraisal.dart';
import '../l10n/app_strings.dart';
import 'worthhit_theme.dart';
import 'selectable_surface.dart';
import 'worthhit_icons.dart';

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
    padding: const EdgeInsets.all(20),
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
          const Icon(WorthhitIcons.receipt_long_outlined, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              'Your price check',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: AppText(
              'A few details. A useful price range.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ContextHelp(
            title: 'How it works',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText(
                  'Enter a product, currency and condition. Add any notes or photos. Worthhit estimates a range and explains its assumptions.',
                ),
                const SizedBox(height: 20),
                _explanation(
                  context,
                  WorthhitIcons.compare_arrows,
                  'Your product, in context',
                  'The product model and condition shape the estimate.',
                ),
                const SizedBox(height: 16),
                _explanation(
                  context,
                  WorthhitIcons.visibility_outlined,
                  'See where the price comes from',
                  'Verified sales and model estimates are clearly distinguished.',
                ),
                const SizedBox(height: 16),
                _explanation(
                  context,
                  WorthhitIcons.handshake_outlined,
                  'Practical checks',
                  'Use the facts. Leave pressure and guesswork out.',
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: controller.loadExample,
        icon: const Icon(WorthhitIcons.play_arrow_outlined),
        label: const AppText('Try an example'),
      ),
      const SizedBox(height: 16),
      AppText(
        'An estimate is a starting point, not a guaranteed sale price.',
        style: TextStyle(
          fontSize: 12,
          color: WorthhitPalette.of(context).muted,
          height: 1.5,
        ),
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
            AppText(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            AppText(description),
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
        AppText(
          'Estimating a fair price…',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 18),
        Text(AppStrings.of(context).safeMessage(controller.statusText)),
        const SizedBox(height: 20),
        const LinearProgressIndicator(minHeight: 7),
        const SizedBox(height: 22),
        const AppText(
          'Researching when enabled, calculating a range, and keeping uncertainty visible. Your draft stays here if the request fails.',
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: controller.cancel,
          icon: const Icon(WorthhitIcons.close),
          label: const AppText('Cancel price check'),
        ),
      ],
    ),
  );

  Widget _result(BuildContext context, AppraisalResult result) {
    final ready =
        result.status == AppraisalStatus.ready ||
        result.status == AppraisalStatus.estimated;
    final title = switch (result.status) {
      AppraisalStatus.ready => 'The price picture.',
      AppraisalStatus.estimated => 'Estimated fair price',
      AppraisalStatus.needsDetails => 'A few details first.',
      AppraisalStatus.insufficientEvidence =>
        'A reliable range isn’t available yet.',
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
        AppText(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        AppText(
          'Check date: {date} (UTC). Saved reports do not refresh automatically.',
          params: {
            'date': AppStrings.of(context).utcDate(controller.draft.asOf),
          },
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (result.itemSummary.isNotEmpty) ...[
          Text(
            result.itemSummary,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
        ],
        Text(AppStrings.of(context).safeMessage(result.reason)),
        if (controller.resultUsedMedia && controller.attachments.isEmpty) ...[
          const SizedBox(height: 12),
          const StatusNotice(
            message: 'This saved result used images or videos. Files are not stored; add them again for a new check.',
          ),
        ],
        if (ready &&
            result.low != null &&
            result.median != null &&
            result.high != null) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: WorthhitPalette.of(context).lime,
              border: Border.all(
                color: WorthhitPalette.of(context).ink,
                width: 2,
              ),
              borderRadius: BorderRadius.zero,
              boxShadow: [
                BoxShadow(
                  color: WorthhitPalette.of(context).line,
                  offset: const Offset(4, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  result.isEstimate
                      ? 'Estimated price range'
                      : 'Observed comparable range',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: WorthhitPalette.of(context).onLime,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${AppStrings.of(context).number(result.low!)} – ${AppStrings.of(context).number(result.high!)}',
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.headlineMedium!
                      .copyWith(color: WorthhitPalette.of(context).onLime),
                ),
                const SizedBox(height: 8),
                AppText(
                  result.isEstimate
                      ? '{currency} · fair price {amount}'
                      : '{currency} · median {amount}',
                  params: {
                    'currency': result.currency ?? controller.draft.currency,
                    'amount': AppStrings.of(context).number(result.median!),
                  },
                  style: Theme.of(context).textTheme.titleMedium!
                      .copyWith(color: WorthhitPalette.of(context).onLime),
                ),
                const SizedBox(height: 12),
                AppText(
                  result.isEstimate
                      ? 'Not verified against current sales. This is a starting estimate, not a guaranteed transaction price.'
                      : 'An evidence-based estimate, not a guaranteed transaction price. Asking prices may differ from final sales.',
                  style: TextStyle(color: WorthhitPalette.of(context).onLime),
                ),
              ],
            ),
          ),
        ],
        if (result.isEstimate) ...[
          const SizedBox(height: 16),
          const AppText(
            'Not verified against current sales',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          if (result.estimate != null) Text(result.estimate!.rationale),
          if (result.estimate != null)
            ExpansionTile(
              title: const AppText('How the estimate was calculated'),
              tilePadding: EdgeInsets.zero,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppText(
                    'Reference {amount} {currency}; condition adjustment {adjustment}%; uncertainty ±{uncertainty}%. Rounded estimate, not a confidence interval.',
                    params: {
                      'amount': AppStrings.of(context)
                          .number(result.estimate!.referenceAmount),
                      'currency': result.currency ?? controller.draft.currency,
                      'adjustment': AppStrings.of(context)
                          .number(result.estimate!.conditionAdjustmentPercent),
                      'uncertainty': AppStrings.of(context)
                          .number(result.estimate!.uncertaintyPercent),
                    },
                  ),
                ),
              ],
            ),
        ],
        if (result.factors.isNotEmpty)
          _list(context, 'What moves the price', result.factors),
        if (result.cautions.isNotEmpty)
          _list(context, 'Keep in mind', result.cautions),
        if (result.questions.isNotEmpty)
          _list(context, 'What to check next', result.questions),
        if (result.comparables.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 18),
          AppText(
            'The evidence',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          AppText(
            'Source descriptions are supplied or reported by the model. '
            'Open and verify a listing before relying on it.',
            style: TextStyle(
              fontSize: 12,
              color: WorthhitPalette.of(context).muted,
            ),
          ),
          for (final comparable in result.comparables)
            _comparable(context, comparable),
        ],
        if (result.rejectedReasons.isNotEmpty) ...[
          const SizedBox(height: 24),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const AppText('Evidence left out'),
            trailing: const Icon(WorthhitIcons.expand_more, size: 18),
            children: [
              for (final reason in result.rejectedReasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(AppStrings.of(context).safeMessage(reason)),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(WorthhitIcons.edit_outlined),
              label: const AppText('Refine the details'),
            ),
            OutlinedButton.icon(
              onPressed: controller.exportReport,
              icon: const Icon(WorthhitIcons.download_outlined),
              label: const AppText('Export report'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppText(
          'A fair deal also depends on inspection, safe payment, and clear '
          'terms. This check cannot verify authenticity or a seller’s identity.',
          style: TextStyle(
            fontSize: 12,
            color: WorthhitPalette.of(context).muted,
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
          const SizedBox(height: 20),
          AppText(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(WorthhitIcons.remove, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(AppStrings.of(context).safeMessage(item)),
                  ),
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
        AppText(
          '{amount} {currency} · {kind} · {basis}',
          params: {
            'amount': AppStrings.of(context).number(comparable.amount),
            'currency': comparable.currency,
            'kind': AppStrings.of(context).text(_kind(comparable.kind)),
            'basis': AppStrings.of(context).text(_basis(comparable.priceBasis)),
          },
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        AppText(
          '{condition} · {date}',
          params: {
            'condition': AppStrings.of(context).text(comparable.condition),
            'date': comparable.eventDate == null
                ? AppStrings.of(context).text('Date not supplied')
                : AppStrings.of(context).utcDate(comparable.eventDate!),
          },
          style: TextStyle(
            fontSize: 12,
            color: WorthhitPalette.of(context).muted,
          ),
        ),
        if (comparable.supportQuote.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('“${comparable.supportQuote}”'),
        ],
        const SizedBox(height: 8),
        Text(
          comparable.url,
          textDirection: TextDirection.ltr,
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
