import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/l10n/app_strings.dart';
import 'package:worthhit/l10n/translations.dart';

void main() {
  test('compact controls and update guidance translate in every language', () {
    for (final locale in AppStrings.supportedLocales.skip(1)) {
      final strings = AppStrings(locale);
      for (final key in [
        'Continue',
        'Cancel',
        'Done',
        'Item guidance',
        'Evidence guidance',
        'Connection help',
        'Model help',
        'How it works',
        'Update ready',
        'Draft saved on update. Re-enter your key.',
        'Update',
        'Later',
        'Updating…',
        'Finish your check before updating.',
      ]) {
        expect(
          strings.text(key),
          isNot(key),
          reason: '${locale.languageCode}:$key',
        );
      }
    }
  });
  test('every shipped translation preserves its parameter contract', () {
    final parameter = RegExp(r'\{[a-z]+\}');
    for (final entry in translations.entries) {
      expect(entry.value.length, 7, reason: entry.key);
      final expected = parameter.allMatches(entry.key).map((m) => m[0]).toSet();
      for (final translated in entry.value) {
        expect(translated.trim(), isNotEmpty, reason: entry.key);
        expect(
          parameter.allMatches(translated).map((m) => m[0]).toSet(),
          expected,
          reason: entry.key,
        );
      }
    }
  });

  test(
    'browser language order wins and unknown languages fall back to English',
    () {
      expect(
        AppStrings.resolveLocales(const [
          Locale('xx'),
          Locale('tr', 'TR'),
        ], AppStrings.supportedLocales),
        const Locale('tr'),
      );
      expect(
        AppStrings.resolveLocales(const [
          Locale('de', 'AT'),
          Locale('en'),
        ], AppStrings.supportedLocales),
        const Locale('de'),
      );
      expect(
        AppStrings.resolveLocales(const [
          Locale('xx'),
        ], AppStrings.supportedLocales),
        const Locale('en'),
      );
      expect(
        AppStrings.resolveLocales(null, AppStrings.supportedLocales),
        const Locale('en'),
      );
    },
  );

  test('all supported languages translate core copy', () async {
    for (final locale in AppStrings.supportedLocales) {
      final strings = await AppStrings.delegate.load(locale);
      if (locale.languageCode != 'en') {
        expect(strings.text('Find a fair price'), isNot('Find a fair price'));
        expect(
          strings.safeMessage('Describe the product and model.'),
          isNot('Describe the product and model.'),
        );
      }
      expect(
        strings.safeMessage('A seller’s verbatim source quote.'),
        'A seller’s verbatim source quote.',
      );
    }
  });

  test(
    'localized amount parsing rejects ambiguous grouping and malformed values',
    () async {
      final en = await AppStrings.delegate.load(const Locale('en'));
      final de = await AppStrings.delegate.load(const Locale('de'));
      final ar = await AppStrings.delegate.load(const Locale('ar'));
      expect(en.parseAmount('1234.50'), 1234.5);
      expect(de.parseAmount('1234,50'), 1234.5);
      expect(ar.parseAmount('١٢٣٫٥٠'), 123.5);
      expect(ar.parseAmount('۱۲۳٫۵۰'), 123.5);
      for (final invalid in [
        '1,234',
        '1,234.50',
        '1 234',
        '1e3',
        '-1',
        'NaN',
        'Infinity',
        '12.',
        '.50',
        '1.234',
        '',
      ]) {
        expect(en.parseAmount(invalid), isNull, reason: invalid);
      }
      for (final invalid in ['1.234', '1.234,50', '1,234', '12.50', '12,']) {
        expect(de.parseAmount(invalid), isNull, reason: invalid);
      }
      expect(en.parseAmount('0'), 0);
      expect(de.amountInput(1234.5), '1234,5');
      expect(de.parseAmount(de.amountInput(1234.5)), 1234.5);
    },
  );

  test(
    'UTC date formatting preserves actual UTC day and replaces parameters',
    () async {
      final strings = await AppStrings.delegate.load(const Locale('en'));
      expect(
        strings.utcDate(DateTime.parse('2026-10-21T01:00:00+03:00')),
        strings.utcDate(DateTime.utc(2026, 10, 20)),
      );
      final tr = await AppStrings.delegate.load(const Locale('tr'));
      expect(
        tr.text('Comparable {number}: {reason}', {
          'number': 2,
          'reason': 'test',
        }),
        contains('2'),
      );
      expect(
        tr.safeMessage('Comparable 2: The sale date is missing.'),
        isNot('Comparable 2: The sale date is missing.'),
      );
    },
  );

  testWidgets('Arabic activates native RTL and framework translations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: AppStrings.localizationsDelegates,
        home: Builder(
          builder: (context) => Text(
            '${Directionality.of(context).name}:${AppStrings.of(context).text('Language')}',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('rtl:اللغة'), findsOneWidget);
  });
}
