import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/app/app_controller.dart';
import 'package:worthhit/app/preferences_controller.dart';
import 'package:worthhit/l10n/app_strings.dart';
import 'package:worthhit/platform/local_store.dart';
import 'package:worthhit/ui/app_navigation.dart';
import 'package:worthhit/ui/worthhit_app.dart';

/// Models the PlatformRouteInformationProvider contract: navigation pushes,
/// neglect replaces, and browser traversal reports the stored public state.
class _BrowserHistory extends RouteInformationProvider with ChangeNotifier {
  _BrowserHistory(String location)
    : entries = [RouteInformation(uri: Uri.parse(location))];
  final List<RouteInformation> entries;
  int index = 0;
  int backCalls = 0;
  bool deferBack = false;
  VoidCallback? pendingBack;
  @override
  RouteInformation get value => entries[index];

  @override
  void routerReportsNewRouteInformation(
    RouteInformation information, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    if (type == RouteInformationReportingType.neglect ||
        (type == RouteInformationReportingType.none &&
            information.uri == value.uri)) {
      entries[index] = information;
    } else {
      entries.removeRange(index + 1, entries.length);
      entries.add(information);
      index++;
    }
  }

  bool back() {
    backCalls++;
    if (index == 0) return false;
    void traverse() {
      index--;
      notifyListeners();
    }

    if (deferBack) {
      pendingBack = traverse;
    } else {
      traverse();
    }
    return true;
  }

  void forward() {
    if (index + 1 >= entries.length) return;
    index++;
    notifyListeners();
  }
}

class _NavigationController extends AppController {
  int submissions = 0;
  @override
  Future<void> appraise({String responseLanguage = 'en'}) async {
    submissions++;
  }
}

void main() {
  test(
    'route information admits only public known routes and section identifiers',
    () async {
      const parser = AppRouteParser();
      for (final location in [
        '/about',
        '/terms?section=data',
        '/liability',
        '/settings',
      ]) {
        final state = await parser.parseRouteInformation(
          RouteInformation(uri: Uri.parse(location)),
        );
        expect('${state.current.uri}', location);
        expect(state.historyDepth, 0);
        expect(state.locations.first.name, isEmpty);
      }
      for (final location in [
        'https://evil.example/terms',
        '//evil.example/about',
        '/private',
        '/terms?section=secret',
      ]) {
        final state = await parser.parseRouteInformation(
          RouteInformation(uri: Uri.parse(location)),
        );
        expect('${state.current.uri}', '/');
        expect(state.locations, hasLength(1));
      }
      final route = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/about?apiKey=never-retain')),
      );
      expect(
        jsonEncode(parser.restoreRouteInformation(route).state),
        isNot(contains('never-retain')),
      );
    },
  );

  test(
    'history round-trips public settings context and rejects corrupt stacks',
    () {
      const expected = AppRouteState([
        AppLocation(''),
        AppLocation('settings'),
        AppLocation('about'),
        AppLocation('terms', section: 'data'),
      ], historyDepth: 3);
      final restored = AppRouteState.fromInformation(expected.information);
      expect(restored.locations.map((e) => '${e.uri}'), [
        '/',
        '/settings',
        '/about',
        '/terms?section=data',
      ]);
      expect(restored.historyDepth, 3);
      for (final bad in [
        {
          'worthhitRoutes': ['/', 'https://evil.example'],
          'depth': 1,
        },
        {
          'worthhitRoutes': ['/settings', '/about'],
          'depth': 1,
        },
        {
          'worthhitRoutes': ['/', '/settings'],
          'depth': 1,
        },
        {
          'worthhitRoutes': ['/', '/about'],
          'depth': 20,
        },
        {'worthhitRoutes': List.filled(33, '/about'), 'depth': 1},
        {
          'worthhitRoutes': ['/', 42],
          'depth': 1,
        },
      ]) {
        final state = AppRouteState.fromInformation(
          RouteInformation(uri: Uri.parse('/about'), state: bad),
        );
        expect(state.locations.map((e) => '${e.uri}'), ['/', '/about']);
        expect(state.historyDepth, 0);
      }
    },
  );

  Future<void> mount(
    WidgetTester tester,
    AppController controller,
    PreferencesController preferences,
    _BrowserHistory history,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(controller.dispose);
    addTearDown(preferences.dispose);
    addTearDown(history.dispose);
    await tester.pumpWidget(
      WorthhitApp(
        controller: controller,
        preferences: preferences,
        routeInformationProvider: history,
        browserBack: history.back,
        opener: (_) => throw StateError('Information must stay in this app'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('information navigation actions support Tab then Enter', (
    tester,
  ) async {
    final controller = _NavigationController();
    final preferences = PreferencesController(store: MemoryStore());
    final history = _BrowserHistory('/about');
    final semantics = tester.ensureSemantics();
    try {
      await mount(tester, controller, preferences, history);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        controller.submissions,
        0,
        reason: 'Retained workspace shortcuts must not run behind information pages',
      );
      final link = find.byKey(
        const ValueKey('information-link-/terms?section=data'),
      );
      expect(link, findsOneWidget);
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      final data = tester.getSemantics(link).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(
        data.linkUrl,
        isNull,
        reason: 'A native anchor must not navigate independently of Flutter',
      );
      final label = find.text('data and analytics explanation');
      for (
        var i = 0;
        i < 30 && !Focus.of(tester.element(label)).hasFocus;
        i++
      ) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      expect(
        Focus.of(tester.element(label)).hasFocus,
        isTrue,
        reason: 'Inline links belong in the keyboard focus order',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect('${history.value.uri}', '/terms?section=data');
      expect(find.byKey(const ValueKey('information-terms')), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'Back Forward and information cross-links retain settings and workspace',
    (tester) async {
      final store = MemoryStore();
      final controller = AppController(store: store);
      final preferences = PreferencesController(store: store);
      final history = _BrowserHistory('/');
      await mount(tester, controller, preferences, history);
      final product = find.byKey(const ValueKey('product-field'));
      await tester.enterText(product, 'Private draft to preserve');
      final productController = tester.widget<TextField>(product).controller;
      await tester.tap(find.byKey(const ValueKey('phone-evidence-tab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-button')));
      await tester.pumpAndSettle();
      final keyField = find.byKey(const ValueKey('api-key-field'));
      await tester.enterText(keyField, 'memory-only-test-key');
      final keyController = tester.widget<TextField>(keyField).controller;
      await tester.tap(find.byTooltip('Show API key'));
      preferences.setThemeMode(ThemeMode.dark);
      preferences.setLocale(const Locale('de'));
      await tester.pumpAndSettle();
      final strings = AppStrings(const Locale('de'));
      await tester.ensureVisible(find.text(strings.text('About Worthhit')));
      await tester.tap(find.text(strings.text('About Worthhit')));
      await tester.pumpAndSettle();
      expect('${history.value.uri}', '/about');
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerDelegate!
              as WorthhitRouter;
      final link = find.byKey(
        const ValueKey('information-link-/terms?section=data'),
      );
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect('${history.value.uri}', '/terms?section=data');
      final section = find.text('Data and Google Analytics').last;
      expect(tester.getTopLeft(section).dy, inInclusiveRange(40, 130));
      expect(history.entries, hasLength(4));
      expect(router.currentConfiguration.locations.map((e) => e.name), [
        '',
        'settings',
        'about',
        'terms',
      ]);
      expect(controller.apiKey, 'memory-only-test-key');
      expect(
        jsonEncode(history.entries.map((e) => e.state).toList()),
        isNot(contains('memory-only-test-key')),
      );
      expect(
        jsonEncode(history.entries.map((e) => e.state).toList()),
        isNot(contains('Private draft')),
      );
      expect(jsonEncode(store.values), isNot(contains('memory-only-test-key')));

      // In-app Back traverses the browser entry; Forward can reopen it.
      await tester.tap(find.byKey(const ValueKey('information-back')));
      await tester.pumpAndSettle();
      expect('${history.value.uri}', '/about');
      expect(history.entries, hasLength(4));
      expect(history.backCalls, 1);
      history.forward();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('information-terms')), findsOneWidget);
      history.back();
      await tester.pumpAndSettle();
      history.back();
      await tester.pumpAndSettle();
      expect('${history.value.uri}', '/settings');
      expect(
        tester.widget<TextField>(keyField).controller,
        same(keyController),
      );
      expect(tester.widget<TextField>(keyField).obscureText, isFalse);
      expect(preferences.locale, const Locale('de'));
      expect(preferences.themeMode, ThemeMode.dark);
      // Rebuilding during an outgoing-page animation must not read a removed index.
      await tester.ensureVisible(
        find.byTooltip(strings.text('Close settings')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(strings.text('Close settings')));
      await tester.pump();
      preferences.setLocale(const Locale('en'));
      preferences.setThemeMode(ThemeMode.light);
      await tester.pumpAndSettle();
      expect('${history.value.uri}', '/');
      expect(find.byType(Drawer), findsNothing);
      expect(find.byKey(const ValueKey('web-search-toggle')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('product-field'), skipOffstage: false),
            )
            .controller,
        same(productController),
      );
      expect(controller.draft.product, 'Private draft to preserve');
      expect(controller.apiKey, 'memory-only-test-key');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('native pop and repeated app Back wait for browser traversal', (
    tester,
  ) async {
    final controller = AppController()..setApiKey('retained-native-test-key');
    final preferences = PreferencesController(store: MemoryStore());
    final history = _BrowserHistory('/')..deferBack = true;
    await mount(tester, controller, preferences, history);
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    final keyController = tester
        .widget<TextField>(find.byKey(const ValueKey('api-key-field')))
        .controller;
    await tester.ensureVisible(find.text('About Worthhit'));
    await tester.tap(find.text('About Worthhit'));
    await tester.pumpAndSettle();
    final navigation = AppNavigation.maybeOf(
      tester.element(find.byKey(const ValueKey('information-about'))),
    )!;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(history.backCalls, 1);
    expect(history.pendingBack, isNotNull);
    expect('${history.value.uri}', '/about');
    navigation.open(const AppLocation('terms'));
    await tester.pumpAndSettle();
    expect(
      history.entries,
      hasLength(3),
      reason: 'Do not push another route while browser Back is pending',
    );
    history.pendingBack!();
    history.pendingBack = null;
    await tester.pumpAndSettle();
    expect('${history.value.uri}', '/settings');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('api-key-field')))
          .controller,
      same(keyController),
    );
    history.forward();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('information-about')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('information-back')));
    await tester.tap(find.byKey(const ValueKey('information-back')));
    expect(
      history.backCalls,
      2,
      reason: 'A second tap must not traverse past the retained app',
    );
    history.pendingBack!();
    history.pendingBack = null;
    await tester.pumpAndSettle();
    expect('${history.value.uri}', '/settings');
    expect(history.entries, hasLength(3));
    expect(controller.apiKey, 'retained-native-test-key');
    expect(tester.takeException(), isNull);
  });

  for (final location in ['/about', '/terms?section=data', '/liability']) {
    testWidgets(
      'direct route $location refreshes without requiring prior app history',
      (tester) async {
        final controller = AppController();
        final preferences = PreferencesController(store: MemoryStore())
          ..setLocale(const Locale('ar'));
        final history = _BrowserHistory(location);
        await mount(tester, controller, preferences, history);
        final name = Uri.parse(location).path.substring(1);
        expect(find.byKey(ValueKey('information-$name')), findsOneWidget);
        expect(history.entries, hasLength(1));
        expect(controller.apiKey, isEmpty);
        expect(
          Directionality.of(
            tester.element(find.byKey(const ValueKey('information-back'))),
          ),
          TextDirection.rtl,
        );
        final english = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.localeForSubtree == const Locale('en'),
        );
        expect(english, findsOneWidget);
        final englishDirection = find
            .descendant(of: english, matching: find.byType(Directionality))
            .first;
        expect(
          tester.widget<Directionality>(englishDirection).textDirection,
          TextDirection.ltr,
        );
        await tester.tap(find.byKey(const ValueKey('information-back')));
        await tester.pumpAndSettle();
        expect('${history.value.uri}', '/');
        expect(history.entries, hasLength(1));
        expect(history.backCalls, 0);
        expect(find.byKey(const ValueKey('phone-layout')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
