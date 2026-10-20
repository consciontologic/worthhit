import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/app/app_controller.dart';
import 'package:worthhit/l10n/app_strings.dart';
import 'package:worthhit/platform/local_store.dart';
import 'package:worthhit/ui/selectable_surface.dart';
import 'package:worthhit/ui/update_notice.dart';
import 'package:worthhit/ui/worthhit_app.dart';
import 'package:worthhit/ui/worthhit_theme.dart';

void main() {
  Future<void> showNotice(
    WidgetTester tester,
    AppController controller, {
    double width = 390,
    double scale = 1,
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: worthhitTheme(brightness: brightness),
        locale: locale,
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SelectionArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: UpdateNotice(controller: controller),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'phone notice is compact, announces itself and offers explicit update',
    (tester) async {
      final store = _UpdateStore();
      final controller = AppController(store: store)..updateAvailable = true;
      addTearDown(controller.dispose);
      await showNotice(tester, controller);
      expect(find.text('Update ready'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('update-notice'))).height,
        lessThanOrEqualTo(100),
      );
      final liveRegion = tester.widget<Semantics>(
        find.byKey(const ValueKey('update-announcement')),
      );
      expect(liveRegion.properties.liveRegion, isTrue);
      for (final key in ['update-apply', 'update-later']) {
        expect(
          tester.getSize(find.byKey(ValueKey(key))).height,
          greaterThanOrEqualTo(44),
        );
      }
      expect(store.activations, 0);
      await tester.tap(find.byKey(const ValueKey('update-later')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update-notice')), findsNothing);
      expect(controller.updateAvailable, isTrue);
      expect(store.activations, 0);
    },
  );

  testWidgets('busy notice explains why update is disabled', (tester) async {
    final store = _UpdateStore();
    final controller = AppController(store: store)
      ..updateAvailable = true
      ..busy = true;
    addTearDown(controller.dispose);
    await showNotice(tester, controller);
    expect(find.text('Finish your check before updating.'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('update-apply')))
          .onPressed,
      isNull,
    );
    expect(store.activations, 0);
  });

  testWidgets('Later hint can be selected without dismissing or updating', (
    tester,
  ) async {
    final store = _UpdateStore();
    final controller = AppController(store: store)..updateAvailable = true;
    addTearDown(controller.dispose);
    await showNotice(tester, controller);
    await tester.longPress(find.byKey(const ValueKey('update-later')));
    await tester.pumpAndSettle();
    final tooltip = tester.widget<Tooltip>(
      find.descendant(
        of: find.byKey(const ValueKey('update-later')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.ignorePointer, isFalse);
    expect(
      find.descendant(
        of: find.byType(SelectionArea),
        matching: find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'Later',
        ),
      ),
      findsOneWidget,
    );
    expect(controller.updateNoticeVisible, isTrue);
    expect(store.activations, 0);
  });

  for (final busy in [false, true]) {
    testWidgets('Settings retains the dismissed update (busy=$busy)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final store = _UpdateStore()..activation = Completer<void>();
      final controller = AppController(store: store)
        ..updateAvailable = true
        ..busy = busy;
      addTearDown(controller.dispose);
      await tester.pumpWidget(WorthhitApp(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('update-later')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('update-notice')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('settings-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('update-notice')), findsOneWidget);
      expect(find.byKey(const ValueKey('update-later')), findsNothing);
      final apply = find.byKey(const ValueKey('update-apply'));
      expect(apply.hitTestable(), findsOneWidget);
      if (busy) {
        expect(tester.widget<TextButton>(apply).onPressed, isNull);
        expect(find.text('Finish your check before updating.'), findsOneWidget);
      } else {
        await tester.tap(apply);
        await tester.pump();
        expect(tester.widget<TextButton>(apply).onPressed, isNull);
        store.activation!.completeError(StateError('Activation failed'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'The update could not be activated. Your saved draft is safe.',
          ),
          findsOneWidget,
        );
        expect(tester.widget<TextButton>(apply).onPressed, isNotNull);
      }
    });
  }

  testWidgets(
    'failed draft save remains visible and blocks update activation',
    (tester) async {
      final store = _UpdateStore()..saveFails = true;
      final controller = AppController(store: store)..updateAvailable = true;
      addTearDown(controller.dispose);
      await showNotice(tester, controller);
      await tester.tap(find.byKey(const ValueKey('update-apply')));
      await tester.pumpAndSettle();
      expect(store.activations, 0);
      expect(controller.persistenceError, isNotNull);
      expect(find.text(controller.persistenceError!), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('update-apply')))
            .onPressed,
        isNotNull,
      );
      store.saveFails = false;
      await tester.tap(find.byKey(const ValueKey('update-apply')));
      await tester.pumpAndSettle();
      expect(store.activations, 1);
      expect(controller.persistenceError, isNull);
    },
  );

  testWidgets(
    'failed activation remains visible and can be retried explicitly',
    (tester) async {
      final store = _UpdateStore()..activation = Completer<void>();
      final controller = AppController(store: store)..updateAvailable = true;
      addTearDown(controller.dispose);
      await showNotice(tester, controller);
      await tester.tap(find.byKey(const ValueKey('update-apply')));
      await tester.pump();
      expect(find.text('Updating…'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('update-apply')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<SelectableIconButton>(
              find.byKey(const ValueKey('update-later')),
            )
            .onPressed,
        isNull,
      );
      store.activation!.completeError(
        StateError('Browser declined activation'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The update could not be activated. Your saved draft is safe.',
        ),
        findsOneWidget,
      );
      store.activation = null;
      await tester.tap(find.byKey(const ValueKey('update-apply')));
      await tester.pumpAndSettle();
      expect(store.activations, 2);
      expect(controller.updateError, isNull);
    },
  );

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets(
      'notice wraps at 320px with 200% text in ${locale.languageCode}',
      (tester) async {
        final controller = AppController()..updateAvailable = true;
        addTearDown(controller.dispose);
        await showNotice(
          tester,
          controller,
          width: 320,
          scale: 2,
          locale: locale,
          brightness: Brightness.dark,
        );
        expect(
          find.byKey(const ValueKey('update-apply')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('update-later')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _UpdateStore extends MemoryStore {
  int activations = 0;
  bool saveFails = false;
  Completer<void>? activation;
  @override
  void write(String key, String value) {
    if (saveFails) throw StateError('Storage unavailable');
    super.write(key, value);
  }

  @override
  Future<void> applyUpdate() async {
    activations++;
    await activation?.future;
  }
}
