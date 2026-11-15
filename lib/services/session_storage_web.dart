import 'dart:js_interop';

import 'session_storage_types.dart';

@JS('sessionStorage')
external _WebSessionStorage get _sessionStorage;

extension type _WebSessionStorage(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);
  external void setItem(JSString key, JSString value);
  external void removeItem(JSString key);
}

SessionStorage createSessionStorage() => const _BrowserSessionStorage();

class _BrowserSessionStorage implements SessionStorage {
  const _BrowserSessionStorage();
  @override
  bool get enabled => true;
  @override
  String? read() => _sessionStorage.getItem(sessionStorageKey.toJS)?.toDart;
  @override
  void write(String record) =>
      _sessionStorage.setItem(sessionStorageKey.toJS, record.toJS);
  @override
  void clear() => _sessionStorage.removeItem(sessionStorageKey.toJS);
}
