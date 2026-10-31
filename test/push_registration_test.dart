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
  final requests =
      <
        ({
          int generation,
          Completer<String> result,
          String token,
          String targetType,
        })
      >[];
  final removed = <String>[];
  @override
  Future<String> register({
    required String sessionToken,
    required String deviceToken,
    required String platform,
    required int generation,
    String targetType = 'fid',
  }) {
    final result = Completer<String>();
    requests.add((
      generation: generation,
      result: result,
      token: deviceToken,
      targetType: targetType,
    ));
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

class _PendingPermissionMessaging extends _Messaging {
  final permissions = <Completer<NotificationSettings>>[];
  int registrations = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #requestPermission) {
      final permission = Completer<NotificationSettings>();
      permissions.add(permission);
      return permission.future;
    }
    if (invocation.memberName == #register) registrations++;
    return super.noSuchMethod(invocation);
  }
}

class _WebMessaging extends _Messaging {
  final operations = <String>[];
  final tokens = <Completer<String?>>[];
  final permissions = <Completer<NotificationSettings>>[];
  bool pendingPermission = false;
  Object? migrationError;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #onRegistered:
      case #register:
        throw StateError('Web no puede usar la administración FID');
      case #requestPermission:
        if (!pendingPermission) {
          return Future<NotificationSettings>.value(_Settings());
        }
        final permission = Completer<NotificationSettings>();
        permissions.add(permission);
        return permission.future;
      case #getToken:
        operations.add('getToken');
        final token = Completer<String?>();
        tokens.add(token);
        return token.future;
      case #deleteToken:
        operations.add('deleteToken');
        return Future<void>.value();
      case #unregister:
        operations.add('unregister');
        return migrationError == null
            ? Future<void>.value()
            : Future<void>.error(migrationError!);
      default:
        return super.noSuchMethod(invocation);
    }
  }
}

PushNotificationService _webPush(
  _Devices devices,
  _WebMessaging messaging, {
  Future<bool> Function()? hasFid,
}) => PushNotificationService.forTesting(
  devices,
  messaging,
  isWeb: true,
  vapidKey: 'public-qa-vapid',
  hasFidRegistration: hasFid,
);

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

  testWidgets(
    'permiso pendiente vence sin cerrar sesión y su aceptación tardía no registra',
    (tester) async {
      final messaging = _PendingPermissionMessaging(), devices = _Devices();
      final push = PushNotificationService.forTesting(devices, messaging);
      addTearDown(() async {
        await push.dispose();
        await messaging.events.close();
      });
      final generation = SessionService.generation;
      final pending = push.enableForCurrentSession();
      await tester.pump();
      expect(messaging.permissions.length, 1);
      await tester.pump(const Duration(seconds: 21));
      expect(await pending, isFalse);
      expect(SessionService.isAuthenticated, isTrue);
      expect(SessionService.generation, generation);
      messaging.permissions.single.complete(_Settings());
      await tester.pump();
      expect(messaging.registrations, 0);
      expect(devices.requests, isEmpty);
    },
  );

  testWidgets(
    'permiso tardío de intento vencido no finaliza un intento nuevo',
    (tester) async {
      final messaging = _PendingPermissionMessaging(), devices = _Devices();
      final push = PushNotificationService.forTesting(devices, messaging);
      addTearDown(() async {
        await push.dispose();
        await messaging.events.close();
      });
      final first = push.enableForCurrentSession();
      await tester.pump(const Duration(seconds: 21));
      expect(await first, isFalse);
      var secondCompleted = false;
      final second = push.enableForCurrentSession().then((value) {
        secondCompleted = true;
        return value;
      });
      await tester.pump();
      expect(messaging.permissions.length, 2);
      messaging.permissions.first.complete(_Settings());
      await tester.pump();
      expect(secondCompleted, isFalse);
      expect(messaging.registrations, 0);
      messaging.permissions.last.complete(_Settings());
      await tester.pump();
      expect(messaging.registrations, 1);
      expect(secondCompleted, isFalse);
      push.unregisterForLogout();
      await tester.pump();
      expect(await second, isFalse);
      expect(SessionService.isAuthenticated, isTrue);
    },
  );

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

  test(
    'Web conserva caché legacy, renueva token a demanda y declara tipo explícito',
    () async {
      final messaging = _WebMessaging(), devices = _Devices();
      var inspections = 0;
      final push = _webPush(
        devices,
        messaging,
        hasFid: () async {
          inspections++;
          return false;
        },
      );
      addTearDown(() async {
        await push.dispose();
        await messaging.events.close();
      });
      await push.initialize();
      final first = push.enableForCurrentSession();
      await flush();
      messaging.tokens.last.complete('registration-token-first');
      await flush();
      expect(devices.requests.single.targetType, 'fcm-token');
      devices.requests.single.result.complete('binding-first');
      expect(await first, isTrue);
      final unchanged = push.enableForCurrentSession();
      await flush();
      messaging.tokens.last.complete('registration-token-first');
      expect(await unchanged, isTrue);
      expect(devices.requests.length, 1);
      final renewed = push.enableForCurrentSession();
      await flush();
      messaging.tokens.last.complete('registration-token-renewed');
      await flush();
      expect(devices.removed, ['binding-first']);
      expect(devices.requests.last.token, 'registration-token-renewed');
      devices.requests.last.result.complete('binding-renewed');
      expect(await renewed, isTrue);
      expect(inspections, 1);
      expect(messaging.operations, ['getToken', 'getToken', 'getToken']);
      push.unregisterForLogout();
      await flush();
      expect(messaging.operations.last, 'deleteToken');
    },
  );

  test(
    'Web migra metadata FID una vez antes de getToken y luego solo borra tokens',
    () async {
      final messaging = _WebMessaging(), devices = _Devices();
      final push = _webPush(devices, messaging, hasFid: () async => true);
      addTearDown(() async {
        await push.dispose();
        await messaging.events.close();
      });
      await push.initialize();
      final first = push.enableForCurrentSession();
      await flush();
      expect(messaging.operations, ['unregister', 'getToken']);
      messaging.tokens.last.complete('registration-token');
      await flush();
      devices.requests.last.result.complete('binding-first');
      expect(await first, isTrue);
      SessionService.start(token: 'account-b', user: const UserModel(id: 2));
      final second = push.enableForCurrentSession();
      await flush();
      expect(messaging.operations, [
        'unregister',
        'getToken',
        'deleteToken',
        'getToken',
      ]);
      messaging.tokens.last.complete('registration-token-b');
      await flush();
      devices.requests.last.result.complete('binding-b');
      expect(await second, isTrue);
    },
  );

  test(
    'fallo de migración no cae a FID ni getToken y permite reintento limpio',
    () async {
      final messaging = _WebMessaging()..migrationError = StateError('qa');
      final devices = _Devices();
      final push = _webPush(devices, messaging, hasFid: () async => true);
      addTearDown(() async {
        await push.dispose();
        await messaging.events.close();
      });
      expect(await push.enableForCurrentSession(), isFalse);
      expect(messaging.operations, ['unregister']);
      expect(devices.requests, isEmpty);
      messaging.migrationError = null;
      final retry = push.enableForCurrentSession();
      await flush();
      messaging.tokens.single.complete(null);
      expect(await retry, isFalse);
      expect(devices.requests, isEmpty);
      expect(messaging.operations, ['unregister', 'unregister', 'getToken']);
    },
  );

  testWidgets('Web permiso tardío no obtiene token ni migra FID', (
    tester,
  ) async {
    final messaging = _WebMessaging()..pendingPermission = true;
    final devices = _Devices();
    var inspections = 0;
    final push = _webPush(
      devices,
      messaging,
      hasFid: () async {
        inspections++;
        return true;
      },
    );
    addTearDown(() async {
      await push.dispose();
      await messaging.events.close();
    });
    final pending = push.enableForCurrentSession();
    await tester.pump(const Duration(seconds: 21));
    expect(await pending, isFalse);
    messaging.permissions.single.complete(_Settings());
    await tester.pump();
    expect(inspections, 0);
    expect(messaging.operations, isEmpty);
    expect(devices.requests, isEmpty);
    expect(SessionService.isAuthenticated, isTrue);
  });

  test(
    'getToken A tardío se descarta, su limpieza precede getToken B',
    () async {
      final messaging = _WebMessaging(), devices = _Devices();
      final push = _webPush(devices, messaging);
      addTearDown(() async {
        await push.dispose();
        await messaging.events.close();
      });
      await push.initialize();
      final first = push.enableForCurrentSession();
      await flush();
      SessionService.start(token: 'account-b', user: const UserModel(id: 2));
      final second = push.enableForCurrentSession();
      await flush();
      expect(await first, isFalse);
      expect(messaging.tokens.length, 1);
      messaging.tokens.first.complete('late-a-token');
      await flush();
      expect(messaging.operations, ['getToken', 'deleteToken', 'getToken']);
      expect(devices.requests, isEmpty);
      messaging.tokens.last.complete('current-b-token');
      await flush();
      expect(devices.requests.single.token, 'current-b-token');
      devices.requests.single.result.complete('binding-b');
      expect(await second, isTrue);
      await flush();
      expect(messaging.operations, ['getToken', 'deleteToken', 'getToken']);
      expect(SessionService.currentUser?.id, 2);
    },
  );

  test(
    'alta Web A tardía se limpia por RID antes de confirmar B con igual token',
    () async {
      final messaging = _WebMessaging(), devices = _Devices();
      final push = _webPush(devices, messaging);
      addTearDown(() async {
        await push.dispose();
        await messaging.events.close();
      });
      await push.initialize();
      final first = push.enableForCurrentSession();
      await flush();
      messaging.tokens.last.complete('same-registration-token');
      await flush();
      SessionService.start(
        token: 'same-qa-token',
        user: const UserModel(id: 2),
      );
      final second = push.enableForCurrentSession();
      await flush();
      messaging.tokens.last.complete('same-registration-token');
      await flush();
      expect(await first, isFalse);
      expect(devices.requests.length, 1);
      devices.requests.first.result.complete('binding-old');
      await flush();
      expect(devices.removed, ['binding-old']);
      expect(devices.requests.length, 2);
      devices.requests.last.result.complete('binding-new');
      expect(await second, isTrue);
      expect(SessionService.currentUser?.id, 2);
    },
  );
}
