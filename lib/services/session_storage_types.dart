const sessionStorageKey = 'crowdradar.session.v1';

abstract class SessionStorage {
  bool get enabled;
  String? read();
  void write(String record);
  void clear();
}
