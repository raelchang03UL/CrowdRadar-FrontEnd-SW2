import 'dart:async';
import 'dart:convert';

import 'package:crowdradar/configs/api_config.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/services/push_device_service.dart';
import 'package:crowdradar/services/push_notification_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/services/session_storage.dart';
import 'package:crowdradar/services/session_validation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

class _Settings implements NotificationSettings {
  _Settings(this.authorizationStatus);

  @override
  final AuthorizationStatus authorizationStatus;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Messaging implements FirebaseMessaging {
  final operations = <String>[];
  AuthorizationStatus permission = AuthorizationStatus.authorized;
  Completer<NotificationSettings>? settingsGate;
  Completer<String?>? tokenGate;
  Completer<RemoteMessage?>? initialGate;
  final cachedToken = 'same-cached-fcm-token';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #getInitialMessage:
        return initialGate?.future ?? Future<RemoteMessage?>.value();
      case #getNotificationSettings:
        operations.add('settings');
        return settingsGate?.future ?? Future.value(_Settings(permission));
      case #requestPermission:
        operations.add('requestPermission');
        return Future.value(_Settings(permission));
      case #getToken:
        operations.add('getToken');
        return tokenGate?.future ?? Future<String?>.value(cachedToken);
      case #deleteToken:
        operations.add('deleteToken');
        return Future<void>.value();
      case #unregister:
        operations.add('legacyUnregister');
        return Future<void>.value();
      default:
        return super.noSuchMethod(invocation);
    }
  }
}

typedef _Registration = ({
  String session,
  String token,
  int generation,
  Completer<String> result,
});

class _Devices extends PushDeviceService {
  final registrations = <_Registration>[];
  final removed = <String>[];
  final bindingsByToken = <String, String>{};
  bool deferRegistrations = false;
  Completer<void>? removalGate;
  Object? removalFailure;

  @override
  Future<String> register({
    required String sessionToken,
    required String deviceToken,
    required String platform,
    required int generation,
    String targetType = 'fid',
  }) async {
    expect(platform, 'web');
    expect(targetType, 'fcm-token');
    final result = Completer<String>();
    registrations.add((
      session: sessionToken,
      token: deviceToken,
      generation: generation,
      result: result,
    ));
    if (!deferRegistrations) result.complete('binding-${registrations.length}');
    final id = await result.future;
    // Simula el contrato UNIQUE(token), con un RID diferente por cada POST.
    bindingsByToken[deviceToken] = id;
    return id;
  }

  @override
  Future<void> unregister({
    required String sessionToken,
    required String deviceToken,
    required String registrationId,
    int? generation,
  }) async {
    removed.add(registrationId);
    if (removalFailure != null) throw removalFailure!;
    await removalGate?.future;
    if (bindingsByToken[deviceToken] == registrationId) {
      bindingsByToken.remove(deviceToken);
    }
  }
}

Future<void> _flush() async {
  for (var i = 0; i < 40; i++) {
    await Future<void>.value();
  }
}

class _Storage implements SessionStorage {
  String? record;
  @override
  bool get enabled => true;
  @override
  String? read() => record;
  @override
  void write(String value) => record = value;
  @override
  void clear() => record = null;
}

final _now = DateTime.utc(2026, 11, 13, 12);
const _validUser = UserModel(id: 1, rol: 'USUARIO', status: 'ACTIVO');
String _jwt({bool expired = false}) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'id': 1, 'exp': _now.millisecondsSinceEpoch ~/ 1000 + (expired ? -1 : 3600)})}.cWE';
}

_Storage _storedCandidate({bool expired = false}) =>
    _Storage()
      ..record = jsonEncode({
        'version': 1,
        'apiOrigin': ApiConfig.baseUrl,
        'token': _jwt(expired: expired),
        'alertsEnabledForReload': true,
      });

void _configure(_Storage storage, {SessionValidator? validator}) {
  SessionService.configureRestoreForTesting(
    storage: storage,
    clock: () => _now,
    validator:
        validator ??
        (_) async => const SessionValidationResult.valid(_validUser),
  );
}

void _session({
  bool alerts = false,
  int userId = 1,
  String token = 'session-a',
}) {
  SessionService.start(
    token: token,
    user: UserModel(id: userId),
  );
  SessionService.setAlertsEnabledForReload(
    alerts,
    token: token,
    generation: SessionService.generation,
  );
}

PushNotificationService _push(_Devices devices, _Messaging messaging) {
  final push = PushNotificationService.forTesting(
    devices,
    messaging,
    isWeb: true,
    vapidKey: 'public-test-vapid',
    hasFidRegistration: () async => true,
  );
  addTearDown(() async {
    await push.dispose();
    await _flush();
  });
  return push;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(_session);
  tearDown(() {
    SessionService.clear();
    SessionService.configureRestoreForTesting();
  });

  test(
    'alta explícita confirmada conserva opt-in para un servicio nuevo al recargar',
    () async {
      final storage = _Storage();
      _configure(storage);
      SessionService.start(token: _jwt(), user: _validUser);
      final devices = _Devices(), messaging = _Messaging();
      final beforeReload = _push(devices, messaging);
      // No initialize en el servicio abandonado: no deja listeners del contexto
      // previo. Tampoco dispose/logout, que sí revocaría el registro a propósito.
      expect(await beforeReload.enableForCurrentSession(), isTrue);
      expect(SessionService.alertsEnabledForReload, isTrue);
      expect(jsonDecode(storage.record!)['alertsEnabledForReload'], isTrue);
      messaging.operations.clear();
      _configure(
        storage,
      ); // Contexto de memoria nuevo, conservando solo el record de pestaña.
      SessionService.prepareRestore();
      final afterReload = _push(devices, messaging);
      await afterReload.initialize();
      expect(messaging.operations, isEmpty);
      await SessionService.restore();
      await _flush();
      await afterReload.initialize();
      expect(messaging.operations, ['settings', 'getToken']);
      expect(devices.registrations.length, 2);
      expect(devices.registrations.map((r) => r.token).toSet(), {
        messaging.cachedToken,
      });
      expect(devices.bindingsByToken, {messaging.cachedToken: 'binding-2'});
      expect(devices.removed, isEmpty);
      expect(afterReload.status.value, PushAlertStatus.active);
      expect(await afterReload.enableForCurrentSession(), isTrue);
      expect(devices.registrations.length, 2);
    },
  );

  test(
    'restore validado antes de getInitialMessage inicia una sola reanudación',
    () async {
      _configure(_storedCandidate());
      SessionService.prepareRestore();
      final devices = _Devices(),
          messaging = _Messaging()..initialGate = Completer<RemoteMessage?>();
      final push = _push(devices, messaging);
      final initialized = push.initialize();
      await SessionService.restore();
      await _flush();
      expect(devices.registrations.length, 1);
      messaging.initialGate!.complete();
      await initialized;
      await _flush();
      expect(messaging.operations, ['settings', 'getToken']);
      expect(devices.registrations.length, 1);
      expect(devices.removed, isEmpty);
    },
  );

  test(
    'restore pendiente o retry no usa FCM; solo validación posterior habilita reanudación',
    () async {
      final validation = Completer<SessionValidationResult>();
      var calls = 0;
      _configure(
        _storedCandidate(),
        validator: (_) {
          calls++;
          return calls == 1
              ? validation.future
              : Future.value(const SessionValidationResult.valid(_validUser));
        },
      );
      SessionService.prepareRestore();
      final devices = _Devices(), messaging = _Messaging();
      final push = _push(devices, messaging);
      await push.initialize();
      final restoring = SessionService.restore();
      await _flush();
      expect(SessionService.isAuthenticated, isFalse);
      expect(messaging.operations, isEmpty);
      validation.complete(const SessionValidationResult.retryRequired());
      await restoring;
      expect(SessionService.restoreStatus, SessionRestoreStatus.retryRequired);
      expect(messaging.operations, isEmpty);
      await SessionService.restore();
      await _flush();
      expect(messaging.operations, ['settings', 'getToken']);
      expect(devices.registrations.length, 1);
    },
  );

  test('JWT almacenado vencido no autentica ni accede a FCM', () async {
    final storage = _storedCandidate(expired: true);
    var validations = 0;
    _configure(
      storage,
      validator: (_) async {
        validations++;
        return const SessionValidationResult.valid(_validUser);
      },
    );
    SessionService.prepareRestore();
    final devices = _Devices(), messaging = _Messaging();
    final push = _push(devices, messaging);
    await push.initialize();
    await SessionService.restore();
    await _flush();
    expect(validations, 0);
    expect(storage.record, isNull);
    expect(SessionService.isAuthenticated, isFalse);
    expect(messaging.operations, isEmpty);
    expect(devices.registrations, isEmpty);
  });

  test('opt-in no se guarda antes de confirmar el POST explícito', () async {
    final devices = _Devices()..deferRegistrations = true;
    final push = _push(devices, _Messaging());
    final enabled = push.enableForCurrentSession();
    await _flush();
    expect(SessionService.alertsEnabledForReload, isFalse);
    devices.registrations.single.result.complete('confirmed-binding');
    expect(await enabled, isTrue);
    expect(SessionService.alertsEnabledForReload, isTrue);
  });

  test(
    'OFF conservado y sesión ausente no obtienen token ni solicitan permiso',
    () async {
      final devices = _Devices(), messaging = _Messaging();
      final push = _push(devices, messaging);
      await push.initialize();
      await _flush();
      expect(messaging.operations, isEmpty);
      SessionService.clear();
      await _flush();
      expect(messaging.operations, isEmpty);
      expect(devices.registrations, isEmpty);
    },
  );

  for (final permission in [
    AuthorizationStatus.denied,
    AuthorizationStatus.notDetermined,
    AuthorizationStatus.provisional,
  ]) {
    test(
      'restaurar con permiso $permission no lo solicita ni registra',
      () async {
        _session(alerts: true);
        final devices = _Devices(),
            messaging = _Messaging()..permission = permission;
        final push = _push(devices, messaging);
        await push.initialize();
        await _flush();
        expect(messaging.operations, ['settings']);
        expect(devices.registrations, isEmpty);
        expect(push.status.value, PushAlertStatus.inactive);
      },
    );
  }

  test(
    'baja incierta borra opt-in inmediatamente y no reanuda tras recarga',
    () async {
      final devices = _Devices(), messaging = _Messaging();
      final beforeReload = _push(devices, messaging);
      expect(await beforeReload.enableForCurrentSession(), isTrue);
      devices.removalFailure = TimeoutException('simulated timeout');
      final disabled = beforeReload.disableForCurrentSession();
      expect(SessionService.alertsEnabledForReload, isFalse);
      expect(await disabled, isFalse);
      expect(beforeReload.status.value, PushAlertStatus.disableUnconfirmed);
      messaging.operations.clear();
      final afterReload = _push(devices, messaging);
      await afterReload.initialize();
      await _flush();
      expect(messaging.operations, isEmpty);
      expect(devices.registrations.length, 1);
      expect(afterReload.status.value, PushAlertStatus.inactive);
    },
  );

  test(
    'cambio de cuenta durante permiso leído no activa A ni hereda opt-in en B',
    () async {
      _session(alerts: true);
      final devices = _Devices(),
          messaging = _Messaging()
            ..settingsGate = Completer<NotificationSettings>();
      final push = _push(devices, messaging);
      await push.initialize();
      await _flush();
      _session(userId: 2, token: 'session-b');
      messaging.settingsGate!.complete(
        _Settings(AuthorizationStatus.authorized),
      );
      await _flush();
      expect(messaging.operations, ['settings']);
      expect(devices.registrations, isEmpty);
      expect(SessionService.currentUser?.id, 2);
      expect(SessionService.alertsEnabledForReload, isFalse);
      expect(push.status.value, PushAlertStatus.inactive);
    },
  );

  test(
    'logout o expiración durante POST compensa RID y no guarda opt-in tardío',
    () async {
      _session(alerts: true);
      final devices = _Devices()..deferRegistrations = true;
      final push = _push(devices, _Messaging());
      await push.initialize();
      await _flush();
      SessionService.rejectIfCurrent(
        token: 'session-a',
        generation: SessionService.generation,
      );
      devices.registrations.single.result.complete('late-rejected-binding');
      await _flush();
      expect(devices.removed, ['late-rejected-binding']);
      expect(devices.bindingsByToken, isEmpty);
      expect(SessionService.alertsEnabledForReload, isFalse);
      expect(SessionService.isAuthenticated, isFalse);
      expect(push.status.value, PushAlertStatus.inactive);
    },
  );

  test(
    'compensación A pendiente termina antes del POST B con el mismo token',
    () async {
      _session(alerts: true);
      final devices = _Devices()..deferRegistrations = true;
      final messaging = _Messaging();
      final push = _push(devices, messaging);
      await push.initialize();
      await _flush();
      _session(userId: 2, token: 'session-b');
      final enabledB = push.enableForCurrentSession();
      await _flush();
      devices.removalGate = Completer<void>();
      devices.registrations.first.result.complete('late-a-binding');
      await _flush();
      expect(devices.removed, ['late-a-binding']);
      expect(devices.registrations.length, 1);
      expect(SessionService.alertsEnabledForReload, isFalse);
      devices.removalGate!.complete();
      await _flush();
      expect(devices.registrations.length, 2);
      devices.registrations.last.result.complete('current-b-binding');
      expect(await enabledB, isTrue);
      expect(devices.bindingsByToken, {
        messaging.cachedToken: 'current-b-binding',
      });
      expect(SessionService.alertsEnabledForReload, isTrue);
      expect(SessionService.currentUser?.id, 2);
    },
  );

  testWidgets(
    'timeout de reanudación descarta token tardío sin POST ni permiso nuevo',
    (tester) async {
      _session(alerts: true);
      final devices = _Devices(),
          messaging = _Messaging()..tokenGate = Completer<String?>();
      final push = _push(devices, messaging);
      await push.initialize();
      await tester.pump();
      expect(push.status.value, PushAlertStatus.enabling);
      await tester.pump(const Duration(seconds: 21));
      expect(push.status.value, PushAlertStatus.inactive);
      messaging.tokenGate!.complete(messaging.cachedToken);
      await tester.pump();
      expect(devices.registrations, isEmpty);
      expect(messaging.operations, ['settings', 'getToken', 'deleteToken']);
    },
  );
}
