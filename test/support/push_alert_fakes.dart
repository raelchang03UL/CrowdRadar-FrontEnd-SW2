import 'dart:async';

import 'package:crowdradar/services/push_device_service.dart';
import 'package:crowdradar/services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushTestSettings implements NotificationSettings {
  @override
  AuthorizationStatus get authorizationStatus => AuthorizationStatus.authorized;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PushTestMessaging implements FirebaseMessaging {
  final operations = <String>[];
  Completer<void>? deleteGate;
  Completer<NotificationSettings>? permissionGate;
  int _tokens = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #requestPermission:
        operations.add('permission');
        return permissionGate?.future ?? Future.value(PushTestSettings());
      case #getInitialMessage:
        return Future<RemoteMessage?>.value();
      case #getToken:
        operations.add('getToken');
        return Future<String?>.value('device-${++_tokens}');
      case #deleteToken:
        operations.add('deleteToken');
        return deleteGate?.future ?? Future<void>.value();
      default:
        return super.noSuchMethod(invocation);
    }
  }
}

typedef RemovedPushDevice = ({String session, String token, String binding});

class PushTestDevices extends PushDeviceService {
  final registered = <String>[];
  final removed = <RemovedPushDevice>[];
  Completer<void>? removalGate;
  Object? removalError;

  @override
  Future<String> register({
    required String sessionToken,
    required String deviceToken,
    required String platform,
    required int generation,
    String targetType = 'fid',
  }) async {
    registered.add(deviceToken);
    return 'binding-${registered.length}';
  }

  @override
  Future<void> unregister({
    required String sessionToken,
    required String deviceToken,
    required String registrationId,
    int? generation,
  }) {
    removed.add((
      session: sessionToken,
      token: deviceToken,
      binding: registrationId,
    ));
    if (removalError != null) return Future<void>.error(removalError!);
    return removalGate?.future ?? Future<void>.value();
  }
}

class PushTestFixture {
  final devices = PushTestDevices();
  final messaging = PushTestMessaging();
  late final push = PushNotificationService.forTesting(
    devices,
    messaging,
    isWeb: true,
    vapidKey: 'public-test-vapid',
  );

  Future<void> activate() async {
    await push.initialize();
    await push.enableForCurrentSession();
  }
}

Future<void> flushPush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
