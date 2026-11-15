import 'dart:js_interop';

@JS('crowdRadarPush.initialize')
external void _initialize(JSFunction binding, JSFunction open);
@JS('crowdRadarPush.clear')
external void _clear();
@JS('crowdRadarPush.prepare')
external JSPromise<JSAny?> _prepare(JSString path);
@JS('crowdRadarPush.hasFidRegistration')
external JSPromise<JSBoolean> _hasFidRegistration(JSString appId);

void initializePushBridge(
  String Function() binding,
  void Function(String) open,
) {
  _initialize(
    (() => binding().toJS).toJS,
    ((JSString message) => open(message.toDart)).toJS,
  );
}

void clearPushBridge() => _clear();
Future<void> preparePushWorker(String path) async {
  await _prepare(path.toJS).toDart;
}

Future<bool> hasPushFidRegistration(String appId) async =>
    (await _hasFidRegistration(appId.toJS).toDart).toDart;
