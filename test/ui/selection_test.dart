import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/app/app_controller.dart';
import 'package:worthhit/ui/selectable_surface.dart';
import 'package:worthhit/ui/worthhit_app.dart';
import 'package:worthhit/ui/worthhit_icons.dart';

Offset textPosition(RenderParagraph paragraph, int offset) =>
    paragraph.localToGlobal(
      paragraph.getOffsetForCaret(
            TextPosition(offset: offset),
            const Rect.fromLTWH(0, 0, 2, 20),
          ) +
          Offset(0, paragraph.preferredLineHeight / 2),
    );

Future<void> selectText(WidgetTester tester, String text) async {
  final found = find
      .byWidgetPredicate((widget) => widget is Text && widget.data == text)
      .last;
  await tester.ensureVisible(found);
  await tester.pumpAndSettle();
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: found, matching: find.byType(RichText)).first,
  );
  final gesture = await tester.startGesture(
    textPosition(paragraph, 0),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await gesture.moveTo(textPosition(paragraph, text.length));
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
}

Future<void> shortcut(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  String? copied;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.hasStrings') {
            return {'value': copied?.isNotEmpty ?? false};
          }
          if (call.method == 'Clipboard.getData') return {'text': copied};
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    copied = null;
  });

  Future<AppController> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(WorthhitApp(controller: controller));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets(
    'workspace text copies and editable input keeps its own selection',
    (tester) async {
      final controller = await mount(tester);
      const title = 'Know what it’s worth.';
      await selectText(tester, title);
      await shortcut(tester, LogicalKeyboardKey.keyC);
      expect(copied, title);

      final field = find.byKey(const ValueKey('product-field'));
      await tester.enterText(field, 'My saved item');
      await tester.tap(field);
      await shortcut(tester, LogicalKeyboardKey.keyA);
      await shortcut(tester, LogicalKeyboardKey.keyC);
      expect(copied, 'My saved item');
      expect(controller.draft.product, 'My saved item');
      copied = 'Pasted item';
      await shortcut(tester, LogicalKeyboardKey.keyV);
      expect(controller.draft.product, 'Pasted item');
      expect(tester.takeException(), isNull);
    },
  );

  for (final compact in [false, true]) {
    testWidgets(
      'information prose copies without selecting private workspace data (compact=$compact)',
      (tester) async {
        await mount(tester);
        await tester.enterText(
          find.byKey(const ValueKey('product-field')),
          'Private background draft',
        );
        await tester.tap(find.byKey(const ValueKey('footer-about')));
        await tester.pumpAndSettle();
        if (compact) {
          tester.view.physicalSize = const Size(320, 700);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpAndSettle();
        }
        await selectText(tester, 'A fair-price estimate, made simple.');
        await shortcut(tester, LogicalKeyboardKey.keyA);
        await shortcut(tester, LogicalKeyboardKey.keyC);
        expect(copied, contains('A fair-price estimate, made simple.'));
        expect(
          copied,
          contains('An asking price is not proof of a completed sale.'),
        );
        expect(copied, contains('data and analytics explanation'));
        expect(copied, isNot(contains('\uFFFC')));
        expect(
          copied!.replaceAll(RegExp(r'\s+'), ' '),
          contains(
            'When you request an appraisal, submitted content and attached media go directly to OpenRouter and the selected provider. '
            'Optional paid research may also involve a search provider. Website usage is measured with Google Analytics, '
            'a separate third-party service that may use cookies. See the data and analytics explanation for details.',
          ),
        );

        expect(copied, isNot(contains('Private background draft')));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('settings selection stays inside its sheet', (tester) async {
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    await selectText(tester, 'Settings');
    await shortcut(tester, LogicalKeyboardKey.keyC);
    expect(copied, 'Settings');
    await shortcut(tester, LogicalKeyboardKey.keyA);
    await shortcut(tester, LogicalKeyboardKey.keyC);
    expect(copied, contains('Settings'));
    expect(copied, isNot(contains('Know what it’s worth.')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('drawer selection excludes the obscured workspace and draft', (
    tester,
  ) async {
    final controller = await mount(tester);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('product-field')),
      'Private draft',
    );
    await tester.tap(find.byKey(const ValueKey('navigation-menu')));
    await tester.pumpAndSettle();
    await selectText(tester, 'Price check');
    await shortcut(tester, LogicalKeyboardKey.keyA);
    await shortcut(tester, LogicalKeyboardKey.keyC);
    expect(copied, contains('Price check'));
    expect(copied, contains('Start fresh'));
    expect(copied, isNot(contains('Private draft')));
    expect(copied, isNot(contains('What’s the item?')));
    expect(copied, isNot(contains('Details')));
    expect(controller.draft.product, 'Private draft');
    expect(tester.takeException(), isNull);
  });

  testWidgets('touch selection exposes a working copy toolbar', (tester) async {
    await mount(tester);
    await tester.longPress(find.text('Know what it’s worth.'));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, isNotNull);
    expect('Know what it’s worth.', contains(copied!));
    expect(tester.takeException(), isNull);
  });

  testWidgets('icon tooltip can be copied without activating its action', (
    tester,
  ) async {
    var invoked = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SelectableIconButton(
              tooltip: 'Readable action hint',
              onPressed: () => invoked++,
              icon: const Icon(WorthhitIcons.info_outline),
            ),
          ),
        ),
      ),
    );
    tester.state<TooltipState>(find.byType(Tooltip)).ensureTooltipVisible();
    await tester.pumpAndSettle();
    await selectText(tester, 'Readable action hint');
    await shortcut(tester, LogicalKeyboardKey.keyC);
    expect(copied, 'Readable action hint');
    expect(invoked, 0);
    await tester.tap(find.byType(IconButton));
    expect(invoked, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('popup label supports copy and normal activation', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PopupMenuButton<String>(
            onSelected: (value) => selected = value,
            itemBuilder: (_) => [
              const SelectablePopupMenuItem(
                value: 'terms',
                child: Text('Terms and conditions'),
              ),
            ],
            child: const Text('Information'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Information'));
    await tester.pumpAndSettle();
    await selectText(tester, 'Terms and conditions');
    await shortcut(tester, LogicalKeyboardKey.keyC);
    expect(copied, 'Terms and conditions');
    expect(selected, isNull);
    await tester.tap(find.text('Terms and conditions'));
    await tester.pumpAndSettle();
    expect(selected, 'terms');
    expect(tester.takeException(), isNull);
  });

  testWidgets('contextual help copies only the dialog, not the background', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            child: Column(
              children: [
                Text('Private background draft'),
                ContextHelp(
                  title: 'Item guidance',
                  child: Text('Inspect the model and condition.'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Item guidance'));
    await tester.pumpAndSettle();
    await selectText(tester, 'Inspect the model and condition.');
    await shortcut(tester, LogicalKeyboardKey.keyA);
    await shortcut(tester, LogicalKeyboardKey.keyC);
    expect(copied, contains('Inspect the model and condition.'));
    expect(copied, isNot(contains('Private background draft')));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
