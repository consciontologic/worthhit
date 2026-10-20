import 'local_store_stub.dart'
    if (dart.library.js_interop) 'local_store_web.dart'
    as implementation;

abstract class LocalStore {
  String? read(String key);
  void write(String key, String value);
  void remove(String key);
  void download(String filename, String text);
  Future<bool> hasWaitingUpdate();
  Future<void> applyUpdate();
}

LocalStore createLocalStore() => implementation.createStore();

class MemoryStore implements LocalStore {
  final Map<String, String> values = {};
  String? lastDownload;

  @override
  String? read(String key) => values[key];
  @override
  void write(String key, String value) => values[key] = value;
  @override
  void remove(String key) => values.remove(key);
  @override
  void download(String filename, String text) => lastDownload = text;
  @override
  Future<bool> hasWaitingUpdate() async => false;
  @override
  Future<void> applyUpdate() async {}
}
