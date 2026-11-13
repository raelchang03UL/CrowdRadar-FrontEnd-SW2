import 'session_storage_types.dart';

SessionStorage createSessionStorage() => const _MemoryOnlySessionStorage();

class _MemoryOnlySessionStorage implements SessionStorage {
  const _MemoryOnlySessionStorage();
  @override
  bool get enabled => false;
  @override
  String? read() => null;
  @override
  void write(String record) {}
  @override
  void clear() {}
}
