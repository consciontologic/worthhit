import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/app/app_controller.dart';
import 'package:worthhit/ui/worthhit_app.dart';

class _Controller extends AppController {
  int submissions = 0;
  @override
  Future<void> appraise({String responseLanguage = 'en'}) async {
    submissions++;
  }
}

void main() {
  for (final width in [320.0, 850.0, 1440.0]) {
    testWidgets('one form estimates without evidence or steps at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _Controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(WorthhitApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('evidence-field')), findsNothing);
      expect(find.byKey(const ValueKey('location-field')), findsNothing);
      expect(find.byKey(const ValueKey('askingPrice-field')), findsNothing);
      expect(find.byKey(const ValueKey('next-step')), findsNothing);
      expect(find.byKey(const ValueKey('phone-evidence-tab')), findsNothing);
      final product = find.byKey(const ValueKey('product-field'));
      final currency = find.byKey(const ValueKey('currency-field'));
      final notes = find.byKey(const ValueKey('details-field'));
      await tester.enterText(product, 'Sony WH-1000XM4');
      await tester.ensureVisible(currency);
      await tester.enterText(currency, 'eur');
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'Used at home, no box. Any kind of note.');
      expect(controller.draft.product, 'Sony WH-1000XM4');
      expect(controller.draft.currency, 'EUR');
      expect(controller.draft.condition, 'Good');
      expect(
        controller.draft.details,
        'Used at home, no box. Any kind of note.',
      );
      final submit = find.byKey(
        ValueKey(width < 700 ? 'submit-check' : 'appraisal-submit'),
      );
      await tester.tap(submit);
      await tester.pump();
      expect(controller.submissions, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
