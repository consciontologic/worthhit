import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/app/app_controller.dart';
import 'package:worthhit/app/app_identity.dart';
import 'package:worthhit/l10n/app_strings.dart';
import 'package:worthhit/ui/worthhit_app.dart';
import 'package:worthhit/app/preferences_controller.dart';
import 'package:worthhit/platform/local_store.dart';

class _UiController extends AppController {
  String? testError;
  int submissions = 0;
  String? submittedLanguage;

  @override
  String? get error => testError;

  @override
  Future<void> appraise({String responseLanguage = 'en'}) async {
    submittedLanguage = responseLanguage;
    submissions++;
  }
}

void main() {
  Future<void> size(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 1000);
    await tester.pump();
  }

  testWidgets('desktop exposes version and information footer at the bottom', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _UiController();
    addTearDown(controller.dispose);
    await size(tester, 1440);
    await tester.pumpWidget(WorthhitApp(controller: controller));
    await tester.pumpAndSettle();
    final footer = find.byKey(const ValueKey('app-footer'));
    expect(footer, findsOneWidget);
    expect(find.text('v$appVersion'), findsOneWidget);
    expect(find.byTooltip('GitHub'), findsOneWidget);
    expect(find.byTooltip('About'), findsOneWidget);
    expect(find.byTooltip('Terms and conditions'), findsOneWidget);
    expect(find.byTooltip('Liability'), findsOneWidget);
    expect(tester.getRect(footer).bottom, 1000);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 850.0]) {
    testWidgets('compact $width navigation keeps information in the drawer', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _UiController();
      addTearDown(controller.dispose);
      await size(tester, width);
      await tester.pumpWidget(WorthhitApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app-footer')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('navigation-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sidebar-app-footer')), findsOneWidget);
      expect(find.text('v$appVersion'), findsOneWidget);
      expect(find.byTooltip('GitHub'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('footer-info-menu')));
      await tester.pumpAndSettle();
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Terms and conditions'), findsOneWidget);
      expect(find.text('Liability'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('uses separate phone, tablet and desktop work flows', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _UiController();
    addTearDown(controller.dispose);
    await size(tester, 390);
    await tester.pumpWidget(WorthhitApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('phone-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('submit-check')), findsOneWidget);

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

  testWidgets(
    'phone controls preserve workspace and accessible touch targets',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _UiController();
      addTearDown(controller.dispose);
      await size(tester, 390);
      await tester.pumpWidget(WorthhitApp(controller: controller));
      await tester.pumpAndSettle();
      for (final destination in ['details', 'estimate']) {
        await tester.tap(find.byKey(ValueKey('phone-$destination-tab')));
        await tester.pump();
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(
          tester.getSize(find.byWidget(scaffold.bottomNavigationBar!)).height,
          lessThanOrEqualTo(104),
        );
        for (final key in ['details', 'estimate']) {
          final target = find.byKey(ValueKey('phone-$key-tab'));
          expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
          expect(tester.getSize(target).width, greaterThanOrEqualTo(44));
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('tablet controls leave space for the item and remain touchable', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _UiController();
    addTearDown(controller.dispose);
    await size(tester, 850);
    await tester.pumpWidget(WorthhitApp(controller: controller));
    await tester.pumpAndSettle();
    for (final key in ['tablet-editor-tab', 'tablet-estimate-tab']) {
      final target = find.byKey(ValueKey(key));
      expect(tester.getSize(target).height, inInclusiveRange(44, 48));
    }
    expect(
      tester.getSize(find.byKey(const ValueKey('editor-actions'))).height,
      lessThanOrEqualTo(64),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('appraisal-submit'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet icon-only edit action has an accessible button name', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      final controller = _UiController();
      addTearDown(controller.dispose);
      await size(tester, 850);
      await tester.pumpWidget(WorthhitApp(controller: controller));
      await tester.pumpAndSettle();
      final button = find.descendant(
        of: find.byTooltip('Edit price check'),
        matching: find.byType(IconButton),
      );
      final node = tester.getSemantics(find.byTooltip('Edit price check'));
      // Flutter exposes icon-button names through the tooltip semantic field.
      // The same exported node must carry both the name and the button action.
      expect(node.getSemanticsData().tooltip, 'Edit price check');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      await tester.tap(find.byKey(const ValueKey('tablet-estimate-tab')));
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('product-field')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final language in ['ar', 'zh']) {
    testWidgets('$language compact actions retain bundled font fallbacks', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _UiController();
      final preferences = PreferencesController(store: MemoryStore())
        ..setLocale(Locale(language));
      addTearDown(controller.dispose);
      addTearDown(preferences.dispose);
      await size(tester, 390);
      await tester.pumpWidget(
        WorthhitApp(controller: controller, preferences: preferences),
      );
      await tester.pumpAndSettle();
      for (final width in [390.0, 850.0, 1440.0]) {
        await size(tester, width);
        await tester.pumpAndSettle();
        final actions = width < 700
            ? {'submit-check': 'Estimate'}
            : {
                'appraisal-submit': 'Find a fair price',
                if (width < 1100) ...{
                  'tablet-editor-tab': 'Edit item',
                  'tablet-estimate-tab': 'Price picture',
                },
              };
        for (final action in actions.entries) {
          final button = find.byKey(ValueKey(action.key));
          final label = AppStrings.of(tester.element(button))
              .text(action.value);
          final rendered = tester
              .widgetList<RichText>(
                find.descendant(of: button, matching: find.byType(RichText)),
              )
              .singleWhere((widget) => widget.text.toPlainText() == label);
          expect(rendered.text.style?.fontFamily, 'WorthhitSans');
          expect(
            rendered.text.style?.fontFamilyFallback,
            containsAll(['WorthhitArabic', 'WorthhitChinese']),
            reason: '$language $width ${action.key} must work offline',
          );
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('item guidance is available without crowding the form', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _UiController();
    addTearDown(controller.dispose);
    await size(tester, 390);
    await tester.pumpWidget(WorthhitApp(controller: controller));
    await tester.pumpAndSettle();
    const guidance =
        'The specific model and its condition make the difference.';
    expect(find.text(guidance), findsNothing);
    await tester.tap(find.byTooltip('Item guidance'));
    await tester.pumpAndSettle();
    expect(find.text(guidance), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('product-field')), findsOneWidget);
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
    await tester.pumpWidget(WorthhitApp(controller: controller));
    await tester.pumpAndSettle();
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

  testWidgets('phone navigation keeps notes and exposes estimate state', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _UiController();
    addTearDown(controller.dispose);
    await size(tester, 390);
    await tester.pumpWidget(WorthhitApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('phone-details-tab')));
    await tester.pump();
    final notes = find.byKey(const ValueKey('details-field'));
    await tester.enterText(notes, 'Used at home, with its charging cable.');
    await tester.tap(find.byKey(const ValueKey('phone-estimate-tab')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('phone-details-tab')));
    await tester.pump();
    expect(
      tester.widget<TextField>(notes).controller!.text,
      'Used at home, with its charging cable.',
    );
    await tester.tap(find.byKey(const ValueKey('phone-estimate-tab')));
    await tester.pump();
    expect(find.byKey(const ValueKey('result-panel')), findsOneWidget);
    expect(find.text('A few details. A useful price range.'), findsOneWidget);
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
    await tester.pumpWidget(WorthhitApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('phone-layout')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('phone-details-tab')));
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
    await tester.pumpWidget(WorthhitApp(controller: controller));
    await tester.pumpAndSettle();
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
    await tester.pumpWidget(WorthhitApp(controller: controller));
    await tester.pumpAndSettle();
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
    'currency normalizes and arbitrary notes never block submission',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await size(tester, 1440);
      final controller = _UiController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(WorthhitApp(controller: controller));
      await tester.pumpAndSettle();
      final currency = find.byKey(const ValueKey('currency-field'));
      await tester.enterText(currency, 'eur');
      final notes = find.byKey(const ValueKey('details-field'));
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'I saw one for -20, but I am not sure.');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(controller.submissions, 1);
      expect(controller.draft.currency, 'EUR');
      expect(controller.draft.details, 'I saw one for -20, but I am not sure.');
      expect(controller.draft.askingPrice, isNull);
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
    await tester.pumpWidget(WorthhitApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Clear key'));
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

  testWidgets(
    'starting fresh clears optional notes and preserves the simple form',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await size(tester, 1440);
      final controller = _UiController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(WorthhitApp(controller: controller));
      await tester.pumpAndSettle();
      final notes = find.byKey(const ValueKey('details-field'));
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'Anything about the product');
      controller.clearDraft();
      await tester.pump();
      expect(tester.widget<TextField>(notes).controller!.text, isEmpty);
      expect(find.byKey(const ValueKey('askingPrice-field')), findsNothing);
    },
  );

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
    await tester.pumpWidget(WorthhitApp(controller: controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('phone-details-tab')));
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
  testWidgets('theme and language changes retain field state and focus', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await size(tester, 1440);
    final controller = _UiController();
    final preferences = PreferencesController(store: MemoryStore());
    addTearDown(controller.dispose);
    addTearDown(preferences.dispose);
    await tester.pumpWidget(
      WorthhitApp(controller: controller, preferences: preferences),
    );
    await tester.pumpAndSettle();
    final product = find.byKey(const ValueKey('product-field'));
    await tester.enterText(product, 'Saved product');
    final focus = tester.widget<TextField>(product).focusNode!;
    preferences.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(product)).brightness, Brightness.dark);
    preferences.setLocale(const Locale('tr'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(product).controller!.text, 'Saved product');
    expect(tester.widget<TextField>(product).focusNode, same(focus));
    expect(focus.hasFocus, isTrue);
    expect(find.text('Ürün'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Arabic layout keeps stable navigation and arbitrary localized notes',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await size(tester, 390);
      final controller = _UiController();
      final preferences = PreferencesController(store: MemoryStore())
        ..setLocale(const Locale('ar'));
      addTearDown(controller.dispose);
      addTearDown(preferences.dispose);
      await tester.pumpWidget(
        WorthhitApp(controller: controller, preferences: preferences),
      );
      await tester.pumpAndSettle();
      final product = find.byKey(const ValueKey('product-field'));
      expect(Directionality.of(tester.element(product)), TextDirection.rtl);
      await tester.tap(find.byKey(const ValueKey('phone-estimate-tab')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('phone-details-tab')));
      await tester.pump();
      preferences.setLocale(const Locale('tr'));
      await tester.pumpAndSettle();
      final notes = find.byKey(const ValueKey('details-field'));
      await tester.ensureVisible(notes);
      await tester.enterText(
        notes,
        '120,50 gibi bir fiyat gördüm; emin değilim.',
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(controller.submittedLanguage, 'tr');
      expect(
        controller.draft.details,
        '120,50 gibi bir fiyat gördüm; emin değilim.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings exposes appearance and language choices', (
    tester,
  ) async {
    final controller = _UiController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(WorthhitApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('theme-selector')), findsOneWidget);
    expect(find.byKey(const ValueKey('language-selector')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'system appearance follows device brightness and manual choice wins',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final controller = _UiController();
      final preferences = PreferencesController(store: MemoryStore());
      addTearDown(controller.dispose);
      addTearDown(preferences.dispose);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpWidget(
        WorthhitApp(controller: controller, preferences: preferences),
      );
      await tester.pumpAndSettle();
      final product = find.byKey(const ValueKey('product-field'));
      expect(Theme.of(tester.element(product)).brightness, Brightness.dark);
      preferences.setThemeMode(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(product)).brightness, Brightness.light);
      await tester.tap(find.byKey(const ValueKey('settings-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('theme-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();
      expect(preferences.themeMode, ThemeMode.dark);
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      final context = tester.element(
        find.byKey(const ValueKey('theme-selector')),
      );
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(
        sheet.backgroundColor,
        Theme.of(context).bottomSheetTheme.backgroundColor,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final language in ['de', 'ar', 'zh']) {
    testWidgets(
      '$language remains usable on a narrow dark phone with larger type',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 700);
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        final controller = _UiController();
        final preferences = PreferencesController(store: MemoryStore())
          ..setLocale(Locale(language))
          ..setThemeMode(ThemeMode.dark);
        addTearDown(controller.dispose);
        addTearDown(preferences.dispose);
        await tester.pumpWidget(
          WorthhitApp(controller: controller, preferences: preferences),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('phone-details-tab')));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('phone-estimate-tab')));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('settings-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('language-selector')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'desktop appraisal action remains visible while the form scrolls',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 700);
      final controller = _UiController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(WorthhitApp(controller: controller));
      await tester.pumpAndSettle();
      final action = find.widgetWithText(FilledButton, 'Find a fair price');
      expect(action.hitTestable(), findsOneWidget);
      final initial = tester.getRect(action);
      await tester.drag(
        find.byKey(const ValueKey('product-field')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(action.hitTestable(), findsOneWidget);
      expect(tester.getRect(action), initial);
      await tester.tap(action);
      await tester.pump();
      expect(controller.submissions, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
