import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../platform/local_store.dart';

/// Device-only appearance and language choices; never stores API credentials.
class PreferencesController extends ChangeNotifier {
  PreferencesController({required this.store}) {
    try {
      final saved = store.read(storageKey);
      if (saved == null) return;
      if (saved.length > 1024) {
        throw const FormatException('Preferences too large');
      }
      final decoded = jsonDecode(saved);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Preferences shape');
      }
      final language = decoded['locale'];
      if (language is String &&
          AppStrings.languageNames.containsKey(language)) {
        _locale = Locale(language);
      }
      _themeMode = switch (decoded['theme']) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      persistenceError = 'Language and appearance preferences could not be read. Your saved work has not been changed.';
    }
  }

  static const storageKey = 'worthhit.preferences.v1';
  final LocalStore store;
  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.system;
  String? persistenceError;

  Locale? get locale => _locale;
  ThemeMode get themeMode => _themeMode;

  void setLocale(Locale? value) {
    if (value != null &&
        !AppStrings.languageNames.containsKey(value.languageCode)) {
      return;
    }
    _locale = value == null ? null : Locale(value.languageCode);
    _save();
  }

  void setThemeMode(ThemeMode value) {
    _themeMode = value;
    _save();
  }

  void _save() {
    try {
      store.write(
        storageKey,
        jsonEncode({'locale': _locale?.languageCode, 'theme': _themeMode.name}),
      );
      persistenceError = null;
    } catch (_) {
      persistenceError = 'These preferences apply to this session but could not be saved. Your draft and report are unchanged.';
    }
    notifyListeners();
  }
}
