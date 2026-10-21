import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/app/app_controller.dart';
import 'package:worthhit/domain/appraisal.dart';
import 'package:worthhit/l10n/app_strings.dart';
import 'package:worthhit/ui/result_panel.dart';
import 'package:worthhit/ui/worthhit_theme.dart';

void main() {
  Future<void> mount(WidgetTester tester, AppController controller) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: worthhitTheme(),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: AppStrings.localizationsDelegates,
        home: Scaffold(
          body: ResultPanel(controller: controller, onEdit: () {}),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'model estimate shows uncertainty and local calculation clearly',
    (tester) async {
      final controller = AppController()
        ..result = const AppraisalResult(
          status: AppraisalStatus.estimated,
          reason: 'A provisional estimate.',
          currency: 'USD',
          low: 64,
          median: 80,
          high: 96,
          estimate: ModelEstimate(
            referenceAmount: 100,
            conditionAdjustmentPercent: -20,
            uncertaintyPercent: 20,
            rationale: 'Wear reduces the reference value.',
          ),
        );
      addTearDown(controller.dispose);
      await mount(tester, controller);
      expect(find.text('Estimated fair price'), findsOneWidget);
      expect(find.text('Estimated price range'), findsOneWidget);
      expect(find.text('USD · fair price 80'), findsOneWidget);
      expect(find.text('Not verified against current sales'), findsOneWidget);
      expect(find.text('Observed comparable range'), findsNothing);
      await tester.ensureVisible(find.text('How the estimate was calculated'));
      await tester.tap(find.text('How the estimate was calculated'));
      await tester.pumpAndSettle();
      expect(find.textContaining('condition adjustment -20%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty report keeps explanations in selectable contextual help', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await mount(tester, controller);
    expect(
      find.text(
        'Verified sales and model estimates are clearly distinguished.',
      ),
      findsNothing,
    );
    expect(
      find.text(
        'An estimate is a starting point, not a guaranteed sale price.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('How it works'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Verified sales and model estimates are clearly distinguished.',
      ),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(AlertDialog),
        matching: find.byType(SelectionArea),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready estimates keep observed range and source facts visible', (
    tester,
  ) async {
    final controller = AppController()
      ..draft = AppraisalInput(asOf: DateTime.utc(2026, 10, 20))
      ..result = AppraisalResult(
        status: AppraisalStatus.ready,
        reason: 'Three exact model matches were admitted.',
        itemSummary: 'Used headphones, good condition',
        currency: 'USD',
        low: 120,
        median: 135,
        high: 150,
        comparables: [
          Comparable(
            url: 'https://example.com/sold/1',
            title: 'A supplied completed sale',
            kind: 'sold',
            amount: 120,
            currency: 'USD',
            eventDate: DateTime.utc(2026, 10, 10),
            condition: 'Good',
            match: 'exact',
            priceBasis: 'item_only',
            supportQuote: 'Sold for 120 USD on 2026-10-10.',
          ),
        ],
        cautions: const ['Supplied evidence was not independently verified.'],
      );
    addTearDown(controller.dispose);
    await mount(tester, controller);
    expect(find.text('Observed comparable range'), findsOneWidget);
    expect(find.text('120 – 150'), findsOneWidget);
    expect(find.text('USD · median 135'), findsOneWidget);
    expect(
      find.text(
        'Check date: Oct 20, 2026 (UTC). Saved reports do not refresh automatically.',
      ),
      findsOneWidget,
    );
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.text('https://example.com/sold/1'), findsOneWidget);
    expect(find.textContaining('Sold · item only'), findsOneWidget);
    expect(
      find.text('Supplied evidence was not independently verified.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final status in [
    AppraisalStatus.needsDetails,
    AppraisalStatus.insufficientEvidence,
    AppraisalStatus.blocked,
  ]) {
    testWidgets('$status asks or explains without inventing a price range', (
      tester,
    ) async {
      final controller = AppController()
        ..result = AppraisalResult(
          status: status,
          reason: 'More reliable evidence is required.',
          questions: const ['What is the exact model?'],
        );
      addTearDown(controller.dispose);
      await mount(tester, controller);
      expect(find.text('Observed comparable range'), findsNothing);
      expect(find.text('More reliable evidence is required.'), findsOneWidget);
      expect(find.text('What is the exact model?'), findsOneWidget);
      expect(find.text('Refine the details'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('synthetic result is clearly labelled and cancellation works', (
    tester,
  ) async {
    final controller = AppController()
      ..isExample = true
      ..result = const AppraisalResult(
        status: AppraisalStatus.insufficientEvidence,
        reason: 'Illustrative evidence only.',
      );
    addTearDown(controller.dispose);
    await mount(tester, controller);
    expect(find.textContaining('Synthetic example'), findsOneWidget);

    controller.busy = true;
    await mount(tester, controller);
    expect(find.text('Estimating a fair price…'), findsOneWidget);
    await tester.tap(find.text('Cancel price check'));
    expect(controller.busy, isFalse);
    expect(controller.statusText, contains('cancelled'));
  });
  testWidgets(
    'translated report labels preserve exact source quotations and canonical condition',
    (tester) async {
      const quote = 'Sold for 120 USD on 2026-10-10.';
      final controller = AppController()
        ..draft = AppraisalInput(asOf: DateTime.utc(2026, 10, 20))
        ..result = AppraisalResult(
          status: AppraisalStatus.ready,
          reason: 'Three exact model matches were admitted.',
          currency: 'USD',
          low: 120,
          median: 135,
          high: 150,
          comparables: [
            Comparable(
              url: 'https://example.com/sold/1',
              title: 'Source title',
              kind: 'sold',
              amount: 120,
              currency: 'USD',
              eventDate: DateTime.utc(2026, 10, 10),
              condition: 'Good',
              match: 'exact',
              priceBasis: 'item_only',
              supportQuote: quote,
            ),
          ],
        );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: AppStrings.localizationsDelegates,
          theme: worthhitTheme(brightness: Brightness.dark),
          home: Scaffold(
            body: ResultPanel(controller: controller, onEdit: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('“$quote”'), findsOneWidget);
      expect(find.text('https://example.com/sold/1'), findsOneWidget);
      expect(find.text('Observed comparable range'), findsNothing);
      expect(controller.result!.comparables.single.condition, 'Good');
      expect(controller.result!.comparables.single.supportQuote, quote);
      expect(tester.takeException(), isNull);
    },
  );
}
