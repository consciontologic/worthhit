import 'package:web/web.dart' as web;

/// Called only for entries created by the app's router. Direct links fall back
/// to replacing the route, so an app Back button never exits to another site.
bool goBackInBrowser() {
  try {
    web.window.history.back();
    return true;
  } catch (_) {
    return false;
  }
}
