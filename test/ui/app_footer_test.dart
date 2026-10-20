import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/app/app_controller.dart';
import 'package:worthhit/app/app_identity.dart';
import 'package:worthhit/app/preferences_controller.dart';
import 'package:worthhit/l10n/app_strings.dart';
import 'package:worthhit/platform/local_store.dart';
import 'package:worthhit/ui/worthhit_app.dart';

void main() {
  void size(WidgetTester tester, double width, double height) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('information stays in the app and preserves draft and key', (
    tester,
  ) async {
    size(tester, 1440, 900);
    final opened = <Uri>[];
    final controller = AppController()..setApiKey('test-memory-only');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      WorthhitApp(
        controller: controller,
        opener: (uri) {
          opened.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    final product = find.byKey(const ValueKey('product-field'));
    await tester.enterText(product, 'Preserved price check');
    final fieldController = tester.widget<TextField>(product).controller;
    for (final key in ['about', 'terms', 'liability']) {
      await tester.tap(find.byKey(ValueKey('footer-$key')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('information-$key')), findsOneWidget);
      expect(opened, isEmpty);
      expect(controller.draft.product, 'Preserved price check');
      expect(controller.apiKey, 'test-memory-only');
      await tester.tap(find.byKey(const ValueKey('information-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('desktop-layout')), findsOneWidget);
      expect(
        tester.widget<TextField>(product).controller,
        same(fieldController),
      );
    }
    await tester.tap(find.byKey(const ValueKey('footer-github')));
    await tester.pumpAndSettle();
    expect(opened.map((uri) => '$uri'), [sourceRepositoryUrl]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('version and information actions have accessible semantics', (
    tester,
  ) async {
    size(tester, 1440, 900);
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(WorthhitApp(controller: controller));
    await tester.pumpAndSettle();
    final version = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Version $appVersion',
    );
    expect(version, findsOneWidget);
    for (final key in ['about', 'terms', 'liability', 'github']) {
      final semantics = tester.widget<Semantics>(
        find.byKey(ValueKey('footer-$key')),
      );
      expect(semantics.properties.link, isTrue);
      expect(
        semantics.properties.hint,
        key == 'github' ? 'Opens in a new tab' : isNull,
      );
    }
  });

  for (final throws in [false, true]) {
    testWidgets(
      'blocked external link has selectable and copy fallback (throws=$throws)',
      (tester) async {
        size(tester, 1440, 900);
        final controller = AppController();
        addTearDown(controller.dispose);
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await tester.pumpWidget(
          WorthhitApp(
            controller: controller,
            opener: (_) {
              if (throws) throw StateError('Platform denied');
              return false;
            },
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('footer-github')));
        await tester.pumpAndSettle();
        expect(find.text('Could not open this link'), findsOneWidget);
        expect(
          find.widgetWithText(SelectableText, sourceRepositoryUrl),
          findsOneWidget,
        );
        await tester.tap(find.text('Copy link'));
        await tester.pumpAndSettle();
        expect(copied, sourceRepositoryUrl);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('clipboard denial leaves a selectable URL and visible recovery', (
    tester,
  ) async {
    size(tester, 1440, 900);
    final controller = AppController();
    addTearDown(controller.dispose);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'denied');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      WorthhitApp(controller: controller, opener: (_) => false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('footer-github')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(
      find.text('Copy failed. Select and copy the address above.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(SelectableText, sourceRepositoryUrl),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact information navigation closes drawer and retains step', (
    tester,
  ) async {
    size(tester, 390, 900);
    final controller = AppController()..setApiKey('test-memory-only');
    addTearDown(controller.dispose);
    final opened = <Uri>[];
    await tester.pumpWidget(
      WorthhitApp(
        controller: controller,
        opener: (uri) {
          opened.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('product-field')),
      'Preserved mobile draft',
    );
    await tester.tap(find.byKey(const ValueKey('phone-evidence-tab')));
    await tester.pumpAndSettle();
    for (final destination in {
      'About': 'about',
      'Terms and conditions': 'terms',
      'Liability': 'liability',
    }.entries) {
      await tester.tap(find.byKey(const ValueKey('navigation-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('footer-info-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(destination.key));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('information-${destination.value}')),
        findsOneWidget,
      );
      expect(opened, isEmpty);
      expect(controller.draft.product, 'Preserved mobile draft');
      expect(controller.apiKey, 'test-memory-only');
      await tester.tap(find.byKey(const ValueKey('information-back')));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      expect(find.byKey(const ValueKey('web-search-toggle')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'internal navigation works even when external opening is denied',
    (tester) async {
      size(tester, 390, 900);
      final controller = AppController()..setApiKey('test-memory-only');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        WorthhitApp(controller: controller, opener: (_) => false),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('navigation-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('footer-info-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terms and conditions'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('information-terms')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(controller.apiKey, 'test-memory-only');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings About returns to the same settings panel', (
    tester,
  ) async {
    size(tester, 390, 900);
    final controller = AppController();
    addTearDown(controller.dispose);
    final opened = <Uri>[];
    await tester.pumpWidget(
      WorthhitApp(
        controller: controller,
        opener: (uri) {
          opened.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('About Worthhit'));
    await tester.tap(find.text('About Worthhit'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(find.byKey(const ValueKey('information-about')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('information-back')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('desktop footer hides while software keyboard is visible', (
    tester,
  ) async {
    size(tester, 1440, 900);
    addTearDown(tester.view.resetViewInsets);
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(WorthhitApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-footer')), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-footer')), findsNothing);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-footer')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'de', 'ar', 'zh']) {
    testWidgets('$language drawer footer stays reachable at 320px and 200%', (
      tester,
    ) async {
      size(tester, 320, 480);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final controller = AppController();
      final preferences = PreferencesController(store: MemoryStore())
        ..setLocale(Locale(language))
        ..setThemeMode(ThemeMode.dark);
      final opened = <Uri>[];
      addTearDown(controller.dispose);
      addTearDown(preferences.dispose);
      await tester.pumpWidget(
        WorthhitApp(
          controller: controller,
          preferences: preferences,
          opener: (uri) {
            opened.add(uri);
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('navigation-menu')));
      await tester.pumpAndSettle();
      final menu = find.byKey(const ValueKey('footer-info-menu'));
      await tester.ensureVisible(menu);
      await tester.pumpAndSettle();
      expect(menu.hitTestable(), findsOneWidget);
      expect(find.text('v$appVersion'), findsOneWidget);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      final strings = AppStrings(Locale(language));
      final terms = find.text(strings.text('Terms and conditions'));
      await tester.ensureVisible(terms);
      await tester.tap(terms);
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(find.byKey(const ValueKey('information-terms')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('new information and recovery copy is translated in every language', () {
    for (final locale in AppStrings.supportedLocales.skip(1)) {
      final strings = AppStrings(locale);
      for (final key in [
        'Back',
        'About',
        'Terms and conditions',
        'Liability',
        'Information links',
        'Opens in a new tab',
        'Open navigation',
        'Close navigation',
        'Could not open this link',
        'Your check is still here. Copy this address and open it in a new tab.',
        'Copy failed. Select and copy the address above.',
        'Copy link',
        'Close',
      ]) {
        expect(
          strings.text(key),
          isNot(key),
          reason: '${locale.languageCode}:$key',
        );
      }
    }
  });
}
