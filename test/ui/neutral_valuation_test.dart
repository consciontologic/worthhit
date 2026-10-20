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
      final location = find.byKey(const ValueKey('location-field'));
      await tester.ensureVisible(location);
      await tester.enterText(location, 'London, UK');
      final price = find.byKey(const ValueKey('askingPrice-field'));
      await tester.ensureVisible(price);
      await tester.enterText(price, '125');
      await tester.pump();

      expect(controller.draft.product, 'Studio headphones');
      expect(controller.draft.location, 'London, UK');
      expect(controller.draft.askingPrice, 125);
      expect(controller.draft.validate(), isNull);
      expect(controller.draft.toJson(), isNot(contains('goal')));
      expect(store.values['worthit.draft.v1'], isNot(contains('"goal"')));
      expect(controller.result, isNull);
      expect(controller.busy, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
