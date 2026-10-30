import 'dart:async';

import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/services/push_device_service.dart';
import 'package:crowdradar/services/push_notification_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

class _Settings implements NotificationSettings {
  @override
  AuthorizationStatus get authorizationStatus => AuthorizationStatus.authorized;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Messaging implements FirebaseMessaging {
  final events = StreamController<String>.broadcast(sync: true);
  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #onRegistered:
        return events.stream;
      case #getInitialMessage:
        return Future<RemoteMessage?>.value();
      case #requestPermission:
        return Future<NotificationSettings>.value(_Settings());
      case #unregister:
        return Future<void>.value();
      case #register:
        events.add('same-device-fid');
        events.add('same-device-fid');
        return Future<void>.value();
      default:
        return super.noSuchMethod(invocation);
    }
  }
}

class _Devices extends PushDeviceService {
  final requests = <({int generation, Completer<String> result})>[];
  final removed = <String>[];
  @override
  Future<String> register({
    required String sessionToken,
    required String deviceToken,
    required String platform,
    required int generation,
  }) {
    final result = Completer<String>();
    requests.add((generation: generation, result: result));
    return result.future;
  }

  @override
  Future<void> unregister({
    required String sessionToken,
    required String deviceToken,
    required String registrationId,
  }) async {
    removed.add(registrationId);
  }
}

Future<void> flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SessionService.start(
      token: 'same-qa-token',
      user: const UserModel(id: 1),
    ),
  );
  tearDown(SessionService.clear);

  test(
    'dos eventos FCM pendientes se serializan y conservan un binding',
    () async {
      final messaging = _Messaging(), devices = _Devices();
      final push = PushNotificationService.forTesting(devices, messaging);
      addTearDown(() async {
        await push.dispose();
        await messaging.events.close();
      });
      await push.initialize();
      await flush();
      expect(devices.requests.length, 1);
      devices.requests.single.result.complete('binding-first');
      await flush();
      expect(devices.requests.length, 1);
      expect(devices.removed, isEmpty);
      push.unregisterForLogout();
      await flush();
      expect(devices.removed, ['binding-first']);
    },
  );

  test(
    'alta antigua se elimina por binding exacto antes de completar cuenta nueva',
    () async {
      final messaging = _Messaging(), devices = _Devices();
      final push = PushNotificationService.forTesting(devices, messaging);
      addTearDown(() async {
        await push.dispose();
        await messaging.events.close();
      });
      await push.initialize();
      await flush();
      expect(devices.requests.length, 1);
      SessionService.start(
        token: 'same-qa-token',
        user: const UserModel(id: 2),
      );
      await flush();
      expect(devices.requests.length, 1);
      devices.requests.first.result.complete('binding-old');
      await flush();
      expect(devices.removed, ['binding-old']);
      expect(devices.requests.length, 2);
      expect(
        devices.requests.first.generation,
        isNot(devices.requests.last.generation),
      );
      devices.requests.last.result.complete('binding-new');
      await flush();
      push.unregisterForLogout();
      await flush();
      expect(devices.removed, ['binding-old', 'binding-new']);
      expect(SessionService.currentUser?.id, 2);
    },
  );
}
