import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthit/app/app_controller.dart';
import 'package:worthit/ui/worthit_app.dart';

class _UiController extends AppController {
  String? testError;
  int submissions = 0;

  @override
  String? get error => testError;

  @override
  Future<void> appraise() async {
    submissions++;
  }
}

void main() {
  Future<void> size(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 1000);
    await tester.pump();
  }

  testWidgets('uses separate phone, tablet and desktop work flows', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _UiController();
    addTearDown(controller.dispose);
    await size(tester, 390);
    await tester.pumpWidget(WorthitApp(controller: controller));
    expect(find.byKey(const ValueKey('phone-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('next-step')), findsOneWidget);

    await size(tester, 850);
    expect(find.byKey(const ValueKey('tablet-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('tablet-editor-tab')), findsOneWidget);
    expect(find.byKey(const ValueKey('tablet-estimate-tab')), findsOneWidget);

    await size(tester, 1440);
    expect(find.byKey(const ValueKey('desktop-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-rail')), findsOneWidget);
    expect(find.byKey(const ValueKey('result-panel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing and focus survive a change of device layout', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _UiController();
    addTearDown(controller.dispose);
    await size(tester, 1440);
    await tester.pumpWidget(WorthitApp(controller: controller));
    final product = find.byKey(const ValueKey('product-field'));
    await tester.tap(product);
    await tester.enterText(product, 'Folding commuter bicycle');
    final before = tester.widget<TextField>(product);
    final focus = before.focusNode;
    expect(focus!.hasFocus, isTrue);

    await size(tester, 390);
    final after = tester.widget<TextField>(product);
    expect(after.controller!.text, 'Folding commuter bicycle');
    expect(after.focusNode, same(focus));
    expect(focus.hasFocus, isTrue);
    expect(controller.draft.product, 'Folding commuter bicycle');
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone navigation keeps evidence and exposes estimate state', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _UiController();
    addTearDown(controller.dispose);
    await size(tester, 390);
    await tester.pumpWidget(WorthitApp(controller: controller));
    await tester.tap(find.byKey(const ValueKey('next-step')));
    await tester.pump();
    final evidence = find.byKey(const ValueKey('evidence-field'));
    await tester.enterText(evidence, 'Two comparable listings, with dates.');
    await tester.tap(find.byKey(const ValueKey('phone-details-tab')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('phone-evidence-tab')));
    await tester.pump();
    expect(
      tester.widget<TextField>(evidence).controller!.text,
      'Two comparable listings, with dates.',
    );
    await tester.tap(find.byKey(const ValueKey('phone-estimate-tab')));
    await tester.pump();
    expect(find.byKey(const ValueKey('result-panel')), findsOneWidget);
    expect(
      find.text('A fair price starts with good evidence.'),
      findsOneWidget,
    );
  });

  testWidgets('large type uses compact scrollable flow without overflow', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await size(tester, 1200);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    final controller = _UiController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(WorthitApp(controller: controller));
    expect(find.byKey(const ValueKey('phone-layout')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('next-step')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('errors are a live region with a working settings recovery', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await size(tester, 1440);
    final controller = _UiController()
      ..testError = 'The key was rejected. Update it and try again.';
    addTearDown(controller.dispose);
    await tester.pumpWidget(WorthitApp(controller: controller));
    final banner = find.byKey(const ValueKey('error-banner'));
    expect(tester.widget<Semantics>(banner).properties.liveRegion, isTrue);
    expect(find.text(controller.testError!), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('api-key-field')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('api-key-field')))
          .obscureText,
      isTrue,
    );
    expect(find.textContaining('this session'), findsWidgets);
  });

  testWidgets('keyboard shortcut submits and web research is opt in', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await size(tester, 1440);
    final controller = _UiController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(WorthitApp(controller: controller));
    await tester.tap(find.byKey(const ValueKey('product-field')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.submissions, 1);
    expect(controller.webSearch, isFalse);
    expect(find.textContaining('search fees'), findsOneWidget);
  });

  testWidgets(
    'invalid asking price blocks keyboard submission until corrected',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await size(tester, 1440);
      final controller = _UiController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(WorthitApp(controller: controller));
      final price = find.byKey(const ValueKey('askingPrice-field'));
      await tester.enterText(
        find.byKey(const ValueKey('currency-field')),
        'eur',
      );
      expect(controller.draft.currency, 'EUR');
      await tester.enterText(price, '-20');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(controller.submissions, 0);
      expect(find.textContaining('positive amount'), findsOneWidget);
      await tester.enterText(price, '120');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(controller.submissions, 1);
      expect(controller.draft.askingPrice, 120);
    },
  );

  testWidgets('clearing the session key clears the obscured input too', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await size(tester, 390);
    final controller = _UiController()..setApiKey('fake-test-key');
    addTearDown(controller.dispose);
    await tester.pumpWidget(WorthitApp(controller: controller));
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear key'));
    await tester.pump();
    expect(controller.apiKey, isEmpty);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('api-key-field')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('starting fresh clears invalid price text and its error', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await size(tester, 1440);
    final controller = _UiController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(WorthitApp(controller: controller));
    final price = find.byKey(const ValueKey('askingPrice-field'));
    await tester.enterText(price, 'not a price');
    await tester.pump();
    expect(find.textContaining('positive amount'), findsOneWidget);
    controller.clearDraft();
    await tester.pump();
    expect(tester.widget<TextField>(price).controller!.text, isEmpty);
    expect(find.textContaining('positive amount'), findsNothing);
  });

  testWidgets('narrow phone and large text keep each destination usable', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    final controller = _UiController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(WorthitApp(controller: controller));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('phone-evidence-tab')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('phone-estimate-tab')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('api-key-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
