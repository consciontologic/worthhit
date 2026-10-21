import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/app/app_controller.dart';
import 'package:worthhit/platform/local_store.dart';
import 'package:worthhit/ui/worthhit_app.dart';

void main() {
  for (final width in [390.0, 850.0, 1440.0]) {
    testWidgets('neutral item editing works at $width without buy/sell modes', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore();
      final controller = AppController(store: store);
      addTearDown(controller.dispose);
      await tester.pumpWidget(WorthhitApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Buy well'), findsNothing);
      expect(find.text('Sell fairly'), findsNothing);
      final product = find.byKey(const ValueKey('product-field'));
      await tester.enterText(product, 'Studio headphones');
      final notes = find.byKey(const ValueKey('details-field'));
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'London, UK');
      final currency = find.byKey(const ValueKey('currency-field'));
      await tester.ensureVisible(currency);
      await tester.enterText(currency, 'GBP');
      await tester.pump();

      expect(controller.draft.product, 'Studio headphones');
      expect(controller.draft.details, 'London, UK');
      expect(controller.draft.currency, 'GBP');
      expect(controller.draft.validate(), isNull);
      expect(controller.draft.toJson(), isNot(contains('goal')));
      expect(store.values['worthit.draft.v1'], isNot(contains('"goal"')));
      expect(controller.result, isNull);
      expect(controller.busy, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
