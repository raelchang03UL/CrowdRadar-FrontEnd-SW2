void initializePushBridge(
  String Function() binding,
  void Function(String) open,
) {}
void clearPushBridge() {}
Future<void> preparePushWorker(String path) async {}
Future<bool> hasPushFidRegistration(String appId) async => false;
