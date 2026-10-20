import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'local_store.dart';

LocalStore createStore() => BrowserStore();

class BrowserStore implements LocalStore {
  @override
  String? read(String key) => web.window.localStorage.getItem(key);
  @override
  void write(String key, String value) =>
      web.window.localStorage.setItem(key, value);
  @override
  void remove(String key) => web.window.localStorage.removeItem(key);

  @override
  void download(String filename, String text) {
    final blob = web.Blob(
      [text.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename;
    anchor.click();
    Future<void>.delayed(
      const Duration(seconds: 2),
      () => web.URL.revokeObjectURL(url),
    );
  }

  @override
  Future<bool> hasWaitingUpdate() async {
    final registration = await web.window.navigator.serviceWorker
        .getRegistration()
        .toDart
        .timeout(const Duration(seconds: 5));
    return registration?.waiting != null;
  }

  @override
  Future<void> applyUpdate() async {
    final registration = await web.window.navigator.serviceWorker
        .getRegistration()
        .toDart
        .timeout(const Duration(seconds: 5));
    final waiting = registration?.waiting;
    if (waiting == null) {
      throw StateError('No waiting update');
    }
    web.window.navigator.serviceWorker.addEventListener(
      'controllerchange',
      ((web.Event _) => web.window.location.reload()).toJS,
      web.AddEventListenerOptions(once: true),
    );
    waiting.postMessage({'type': 'APPLY_UPDATE'}.jsify());
  }
}
