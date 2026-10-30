import 'dart:js_interop';

@JS('crowdRadarPush.initialize')
external void _initialize(JSFunction binding, JSFunction open);
@JS('crowdRadarPush.clear')
external void _clear();
@JS('crowdRadarPush.prepare')
external JSPromise<JSAny?> _prepare(JSString path);

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
