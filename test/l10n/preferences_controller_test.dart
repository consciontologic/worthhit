import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/app/preferences_controller.dart';
import 'package:worthhit/platform/local_store.dart';

class DeniedStore extends MemoryStore {
  @override
  void write(String key, String value) => throw StateError('denied');
}

void main() {
  test(
    'system defaults, persistent manual override, and returning to system',
    () {
      final store = MemoryStore();
      final preferences = PreferencesController(store: store);
      expect(preferences.locale, isNull);
      expect(preferences.themeMode, ThemeMode.system);
      preferences.setLocale(const Locale('tr', 'TR'));
      preferences.setThemeMode(ThemeMode.dark);
      final reloaded = PreferencesController(store: store);
      expect(reloaded.locale, const Locale('tr'));
      expect(reloaded.themeMode, ThemeMode.dark);
      reloaded.setLocale(null);
      reloaded.setThemeMode(ThemeMode.system);
      expect(PreferencesController(store: store).locale, isNull);
      expect(PreferencesController(store: store).themeMode, ThemeMode.system);
    },
  );
  test(
    'corrupt and unsupported preferences cannot change legacy stored work',
    () {
      final store = MemoryStore();
      store.values['worthit.draft.v1'] = 'original';
      store.values['worthhit.preferences.v1'] = jsonEncode({
        'locale': 'xx',
        'theme': 'ultraviolet',
      });
      final preferences = PreferencesController(store: store);
      expect(preferences.locale, isNull);
      expect(preferences.themeMode, ThemeMode.system);
      preferences.setLocale(const Locale('xx'));
      expect(preferences.locale, isNull);
      expect(store.values['worthit.draft.v1'], 'original');
      store.values['worthhit.preferences.v1'] = '{broken';
      expect(PreferencesController(store: store).persistenceError, isNotNull);
      expect(store.values['worthit.draft.v1'], 'original');
    },
  );
  test(
    'denied persistence retains this session preference and reports safely',
    () {
      final preferences = PreferencesController(store: DeniedStore());
      var notifications = 0;
      preferences.addListener(() => notifications++);
      preferences.setThemeMode(ThemeMode.dark);
      preferences.setLocale(const Locale('ar'));
      expect(preferences.themeMode, ThemeMode.dark);
      expect(preferences.locale, const Locale('ar'));
      expect(preferences.persistenceError, isNotNull);
      expect(notifications, 2);
    },
  );
}
