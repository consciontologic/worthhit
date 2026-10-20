import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthit/app/app_controller.dart';
import 'package:worthit/domain/appraisal.dart';
import 'package:worthit/ui/result_panel.dart';
import 'package:worthit/ui/worthit_theme.dart';

void main() {
  Future<void> mount(WidgetTester tester, AppController controller) =>
      tester.pumpWidget(
        MaterialApp(
          theme: worthitTheme(),
          home: Scaffold(
            body: ResultPanel(controller: controller, onEdit: () {}),
          ),
        ),
      );

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
        'Check date: 2026-10-20 (UTC). Saved reports do not refresh automatically.',
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
    expect(find.text('Checking the evidence…'), findsOneWidget);
    await tester.tap(find.text('Cancel price check'));
    expect(controller.busy, isFalse);
    expect(controller.statusText, contains('cancelled'));
  });
}
