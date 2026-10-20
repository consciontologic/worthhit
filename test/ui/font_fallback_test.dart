import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/l10n/app_strings.dart';
import 'package:worthhit/ui/worthhit_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('$brightness tooltips keep Arabic and Chinese fonts local', (
      tester,
    ) async {
      final tooltip = GlobalKey<TooltipState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: worthhitTheme(brightness: brightness),
          locale: const Locale('ar'),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: AppStrings.localizationsDelegates,
          home: Scaffold(
            body: Tooltip(
              key: tooltip,
              message: 'الإعدادات 中文',
              child: const Icon(Icons.settings),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tooltip.currentState!.ensureTooltipVisible();
      await tester.pumpAndSettle();
      final rendered = tester
          .widgetList<RichText>(find.byType(RichText))
          .where((widget) => widget.text.toPlainText() == 'الإعدادات 中文')
          .single;
      expect(rendered.text.style?.fontFamily, 'WorthhitSans');
      expect(
        rendered.text.style?.fontFamilyFallback,
        containsAll(['WorthhitArabic', 'WorthhitChinese']),
      );
    });
  }
}
