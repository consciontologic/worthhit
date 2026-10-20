import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'local_store.dart';

LocalStore createStore() => BrowserStore();

class BrowserStore implements LocalStore {
  bool _disposed = false;
  Completer<void>? _activation;

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
    if (_disposed) return false;
    final registration = await web.window.navigator.serviceWorker
        .getRegistration()
        .toDart
        .timeout(const Duration(seconds: 5));
    return registration?.waiting != null;
  }

  @override
  Future<void> applyUpdate() async {
    if (_disposed) return;
    final registration = await web.window.navigator.serviceWorker
        .getRegistration()
        .toDart
        .timeout(const Duration(seconds: 5));
    if (_disposed) return;
    final waiting = registration?.waiting;
    if (waiting == null) {
      throw StateError('No waiting update');
    }
    final activation = _activation = Completer<void>();
    final changed = ((web.Event _) {
      if (!activation.isCompleted) activation.complete();
    }).toJS;
    final workers = web.window.navigator.serviceWorker;
    workers.addEventListener('controllerchange', changed);
    try {
      waiting.postMessage({'type': 'APPLY_UPDATE'}.jsify());
      await activation.future.timeout(const Duration(seconds: 15));
      if (!_disposed) web.window.location.reload();
    } finally {
      workers.removeEventListener('controllerchange', changed);
      _activation = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final activation = _activation;
    if (activation != null && !activation.isCompleted) activation.complete();
  }
}
