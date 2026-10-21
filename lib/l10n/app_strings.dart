import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'translations.dart';

/// Source-English keys are stable IDs, including compatibility with saved reports.
/// User prose, evidence quotations, URLs and schema enums must never be translated.
class AppStrings {
  const AppStrings(this.locale);
  final Locale locale;

  static const languageNames = <String, String>{
    'en': 'English',
    'tr': 'Türkçe',
    'de': 'Deutsch',
    'fr': 'Français',
    'es': 'Español',
    'pt': 'Português',
    'ar': 'العربية',
    'zh': '简体中文',
  };
  static const supportedLocales = [
    Locale('en'),
    Locale('tr'),
    Locale('de'),
    Locale('fr'),
    Locale('es'),
    Locale('pt'),
    Locale('ar'),
    Locale('zh'),
  ];
  static const delegate = _AppStringsDelegate();
  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      const AppStrings(Locale('en'));

  /// Browser/platform language order is used; no IP address leaves the browser.
  static Locale resolveLocales(
    List<Locale>? preferred,
    Iterable<Locale> supported,
  ) {
    for (final candidate in preferred ?? const <Locale>[]) {
      for (final supportedLocale in supported) {
        if (candidate.languageCode == supportedLocale.languageCode) {
          return supportedLocale;
        }
      }
    }
    return const Locale('en');
  }

  String text(String id, [Map<String, Object> parameters = const {}]) {
    final index = languageNames.keys.toList().indexOf(locale.languageCode) - 1;
    var value = index < 0 ? id : translations[id]?[index] ?? id;
    for (final parameter in parameters.entries) {
      value = value.replaceAll(
        '{${parameter.key}}',
        parameter.value.toString(),
      );
    }
    return value;
  }

  /// Translate known application messages only. Arbitrary model/user text stays intact.
  String safeMessage(String original) {
    if (translations.containsKey(original)) return text(original);
    final normalized = original.replaceAll('Worthit', 'Worthhit');
    if (translations.containsKey(normalized)) return text(normalized);
    final comparable = RegExp(r'^Comparable ([1-9][0-9]*): (.+)$')
        .firstMatch(original);
    if (comparable != null && translations.containsKey(comparable[2])) {
      return text('Comparable {number}: {reason}', {
        'number': comparable[1]!,
        'reason': text(comparable[2]!),
      });
    }
    final count = RegExp(
      r'^([0-9]+) free text models available\. Choose one from Models\.$',
    ).firstMatch(original);
    if (count != null) {
      return text(
        '{count} free text models available. Choose one from Models.',
        {'count': count[1]!},
      );
    }
    const endpointSuffix = '. Metadata only; availability is not guaranteed.';
    if (original.endsWith(endpointSuffix)) {
      return '${original.substring(0, original.length - endpointSuffix.length)}. ${text('Metadata only; availability is not guaranteed.')}';
    }
    return original;
  }

  String number(num value) => NumberFormat.decimalPatternDigits(
    locale: locale.languageCode,
    decimalDigits: value == value.roundToDouble() ? 0 : 2,
  ).format(value);

  /// Format the report's UTC date, not the current device's local date.
  String utcDate(DateTime value) =>
      DateFormat.yMMMd(locale.languageCode).format(value.toUtc());

  String get _decimalSeparator => locale.languageCode == 'ar'
      ? '٫'
      : NumberFormat.decimalPattern(locale.languageCode).symbols.DECIMAL_SEP;

  /// Editable amounts use no grouping, so displaying a value never changes its meaning.
  String formatAmount(num value) => amountInput(value);

  String amountInput(num value) =>
      value.toString().replaceFirst('.', _decimalSeparator);

  /// Currency input permits at most two decimal places and never guesses grouping.
  /// Arabic and Eastern Arabic digits are normalized without changing punctuation.
  double? parseAmount(String input) {
    var normalized = input.trim();
    if (normalized.length > 24) return null;
    normalized = String.fromCharCodes(
      normalized.runes.map((code) {
        if (code >= 0x0660 && code <= 0x0669) return 48 + code - 0x0660;
        if (code >= 0x06f0 && code <= 0x06f9) return 48 + code - 0x06f0;
        return code;
      }),
    );
    // Arabic keyboards commonly expose either native or ASCII decimal points.
    if (locale.languageCode == 'ar' && !normalized.contains('٫')) {
      normalized = normalized.replaceAll('.', '٫');
    }
    final separator = RegExp.escape(_decimalSeparator);
    if (!RegExp('^[0-9]+(?:$separator[0-9]{1,2})?\$').hasMatch(normalized)) {
      return null;
    }
    final parsed = double.tryParse(
      normalized.replaceFirst(_decimalSeparator, '.'),
    );
    return parsed != null && parsed.isFinite && parsed >= 0 && parsed <= 1e12
        ? parsed
        : null;
  }
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();
  @override
  bool isSupported(Locale locale) =>
      AppStrings.languageNames.containsKey(locale.languageCode);
  @override
  Future<AppStrings> load(Locale locale) async {
    await initializeDateFormatting(locale.languageCode);
    return AppStrings(locale);
  }

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
