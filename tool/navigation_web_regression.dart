// Compile and run against a simulated browser through test_navigation_web.py.
// Exercise the production Dart bridge, not a JavaScript rewrite of its logic.
import 'dart:js_interop';

import 'package:worthhit/platform/document_preferences_web.dart';
import 'package:worthhit/platform/browser_history_web.dart';

@JS('navigationMode')
external set _mode(JSString value);

@JS('verifyNavigation')
external void _verifyNavigation();

void _check(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  _check(
    resolvePage('about/').toString() == 'https://worthhit.com/preview/about/',
    'Relative links must honor the app base URL',
  );
  for (final destination in [
    'https://worthhit.com/about/',
    'https://worthhit.com/terms/',
    'https://worthhit.com/liability/',
    'https://github.com/consciontologic/worthhit',
    'http://localhost:8766/about/',
  ]) {
    _check(openPage(Uri.parse(destination)), 'Navigation was not dispatched');
  }
  for (final destination in ['javascript:alert(1)', 'data:text/html,test']) {
    _check(!openPage(Uri.parse(destination)), 'Unsafe URL scheme admitted');
  }
  _check(goBackInBrowser(), 'History traversal must stay in the same tab');
  _mode = 'history-denied'.toJS;
  _check(
    !goBackInBrowser(),
    'History errors must allow the local back fallback',
  );
  _mode = 'denied'.toJS;
  _check(
    !openPage(Uri.parse('https://worthhit.com/about/')),
    'A rejected navigation must expose fallback',
  );
  _mode = 'no-body'.toJS;
  _check(
    !openPage(Uri.parse('https://worthhit.com/terms/')),
    'Missing document body must expose fallback',
  );
  _verifyNavigation();
  // CLI completion marker; this test harness is not shipped in the app.
  // ignore: avoid_print
  print('PASS: production browser navigation on Dart JavaScript');
}
