import 'dart:async';
import 'dart:convert';

import 'package:crowdradar/configs/api_config.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/services/session_storage.dart';
import 'package:crowdradar/services/session_validation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryStorage implements SessionStorage {
  String? value;
  bool blocked = false, writeBlocked = false;
  int writes = 0;
  @override
  bool get enabled => true;
  @override
  String? read() {
    if (blocked) throw StateError('blocked');
    return value;
  }

  @override
  void write(String record) {
    if (blocked || writeBlocked) throw StateError('blocked');
    writes++;
    value = record;
  }

  @override
  void clear() {
    if (blocked) throw StateError('blocked');
    value = null;
  }
}

final now = DateTime.utc(2026, 11, 13, 18);
const freshUser = UserModel(
  id: 7,
  nombre: 'Perfil actualizado',
  rol: 'USUARIO',
  status: 'ACTIVO',
);
String jwt({int? expires, String role = 'ADMIN'}) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'id': 7, 'rol': role, 'exp': expires ?? now.millisecondsSinceEpoch ~/ 1000 + 7200})}.${base64Url.encode(utf8.encode('synthetic-signature')).replaceAll('=', '')}';
}

String stored(String token, {bool alerts = false}) => jsonEncode({
  'version': 1,
  'apiOrigin': ApiConfig.baseUrl,
  'token': token,
  'alertsEnabledForReload': alerts,
});
void configure(
  MemoryStorage storage, {
  SessionValidator? validator,
  DateTime Function()? clock,
}) => SessionService.configureRestoreForTesting(
  storage: storage,
  validator: validator,
  clock: clock ?? () => now,
);
void expectPrivate() {
  expect(SessionService.isAuthenticated, isFalse);
  expect(SessionService.token, isNull);
  expect(SessionService.currentUser, isNull);
  expect(SessionService.alertsEnabledForReload, isFalse);
}

void main() {
  setUp(() => configure(MemoryStorage()));
  tearDown(() {
    SessionService.clear();
    SessionService.configureRestoreForTesting();
  });

  test(
    'reload valida perfil fresco sin exponer JWT ni rol persistido antes del 200',
    () async {
      final token = jwt(),
          storage = MemoryStorage()..value = stored(jwt(), alerts: true);
      final response = Completer<http.Response>();
      configure(storage);
      await http.runWithClient(
        () async {
          SessionService.prepareRestore();
          expect(SessionService.restoreStatus, SessionRestoreStatus.restoring);
          expectPrivate();
          final pending = SessionService.restore();
          expectPrivate();
          response.complete(
            http.Response(jsonEncode({'data': freshUser.toJson()}), 200),
          );
          await pending;
          expect(SessionService.token, token);
          expect(SessionService.currentUser?.nombre, freshUser.nombre);
          expect(SessionService.currentUser?.rol, 'USUARIO');
          expect(SessionService.alertsEnabledForReload, isTrue);
          expect(SessionService.restoreStatus, SessionRestoreStatus.idle);
          expect(storage.value, stored(token, alerts: true));
        },
        () => MockClient((request) {
          expect(request.method, 'GET');
          expect(request.url.path, ApiConfig.profile);
          expect(request.url.queryParameters['_sessionCheck'], isNotEmpty);
          expect(request.headers['Authorization'], 'Bearer $token');
          expectPrivate();
          return response.future;
        }),
      );
    },
  );

  test(
    'start guarda solo JWT, origen y flag; updateUser no escribe; logout borra antes de avisar',
    () {
      final storage = MemoryStorage();
      configure(storage);
      final token = jwt();
      SessionService.start(token: token, user: freshUser);
      expect(jsonDecode(storage.value!), {
        'version': 1,
        'apiOrigin': ApiConfig.baseUrl,
        'token': token,
        'alertsEnabledForReload': false,
      });
      final writes = storage.writes;
      SessionService.updateUser(
        freshUser.copyWith(nombre: 'Otro nombre'),
        sessionToken: token,
        sessionGeneration: SessionService.generation,
      );
      expect(storage.writes, writes);
      SessionService.setAlertsEnabledForReload(
        true,
        token: token,
        generation: SessionService.generation,
      );
      var notified = false;
      void listener() {
        notified = true;
        expect(storage.value, isNull);
        expectPrivate();
      }

      SessionService.changes.addListener(listener);
      SessionService.clear();
      SessionService.changes.removeListener(listener);
      expect(notified, isTrue);
      configure(storage);
      SessionService.prepareRestore();
      expect(SessionService.restoreStatus, SessionRestoreStatus.idle);
      expectPrivate();
    },
  );

  test(
    'fixtures con token sintético abren memoria pero nunca se persisten',
    () {
      final storage = MemoryStorage()..value = stored(jwt());
      configure(storage);
      SessionService.start(token: 'test-session', user: freshUser);
      expect(SessionService.isAuthenticated, isTrue);
      expect(storage.value, isNull);
    },
  );

  test(
    '401 de JWT manipulado vigente borra candidato y marca rechazo',
    () async {
      final storage = MemoryStorage()..value = stored(jwt());
      configure(storage);
      await http.runWithClient(() async {
        SessionService.prepareRestore();
        await SessionService.restore();
        expectPrivate();
        expect(storage.value, isNull);
        expect(SessionService.wasRejected, isTrue);
        expect(SessionService.restoreStatus, SessionRestoreStatus.idle);
      }, () => MockClient((_) async => http.Response('not-json', 401)));
    },
  );

  for (final bad in [
    'corrupt',
    stored(jwt(expires: now.millisecondsSinceEpoch ~/ 1000)),
    jsonEncode({'version': 2, 'apiOrigin': ApiConfig.baseUrl, 'token': jwt()}),
    jsonEncode({
      'version': 1,
      'apiOrigin': 'https://other.invalid',
      'token': jwt(),
    }),
    jsonEncode({
      'version': 1,
      'apiOrigin': ApiConfig.baseUrl,
      'token': jwt(),
      'user': {'rol': 'ADMIN'},
    }),
    'x' * 9001,
  ]) {
    test(
      'candidato inválido o de otro backend se descarta sin HTTP caso${bad.length}',
      () async {
        final storage = MemoryStorage()..value = bad;
        configure(
          storage,
          validator: (_) async => throw StateError('Must not validate'),
        );
        SessionService.prepareRestore();
        await SessionService.restore();
        expectPrivate();
        expect(storage.value, isNull);
        expect(SessionService.restoreStatus, SessionRestoreStatus.idle);
      },
    );
  }

  for (final response in [
    http.Response('', 503),
    http.Response('', 404),
    http.Response('', 403),
    http.Response('not-json', 200),
    http.Response('{"data":{"id":7}}', 200),
    http.Response(
      jsonEncode({'data': freshUser.copyWith(rol: 'UNKNOWN').toJson()}),
      200,
    ),
    http.Response(
      jsonEncode({'data': freshUser.copyWith(status: 'SUSPENDIDO').toJson()}),
      200,
    ),
  ]) {
    test(
      'fallo transitorio o perfil inválido conserva candidato privado ${response.statusCode}/${response.body.length}',
      () async {
        final storage = MemoryStorage()..value = stored(jwt(), alerts: true),
            original = stored(jwt(), alerts: true);
        configure(storage);
        await http.runWithClient(() async {
          SessionService.prepareRestore();
          await SessionService.restore();
          expectPrivate();
          expect(
            SessionService.restoreStatus,
            SessionRestoreStatus.retryRequired,
          );
          expect(SessionService.wasRejected, isFalse);
          expect(storage.value, original);
        }, () => MockClient((_) async => response));
      },
    );
  }

  testWidgets(
    'timeout conserva candidato privado y permite validar otra vez sin respuesta tardía',
    (tester) async {
      final storage = MemoryStorage()..value = stored(jwt());
      final delayed = Completer<http.Response>();
      var calls = 0;
      configure(storage);
      await http.runWithClient(
        () async {
          SessionService.prepareRestore();
          final pending = SessionService.restore();
          await tester.pump(const Duration(seconds: 16));
          await pending;
          expectPrivate();
          expect(
            SessionService.restoreStatus,
            SessionRestoreStatus.retryRequired,
          );
          await SessionService.restore();
          expect(SessionService.isAuthenticated, isTrue);
          delayed.complete(http.Response('', 401));
          await tester.pump();
          expect(SessionService.isAuthenticated, isTrue);
        },
        () => MockClient(
          (_) => calls++ == 0
              ? delayed.future
              : Future.value(
                  http.Response(jsonEncode({'data': freshUser.toJson()}), 200),
                ),
        ),
      );
    },
  );

  test(
    'red y503 permiten reintento fresco single-flight sin duplicar perfil',
    () async {
      final storage = MemoryStorage()..value = stored(jwt());
      final keys = <String>[];
      var calls = 0;
      configure(storage);
      await http.runWithClient(
        () async {
          SessionService.prepareRestore();
          final first = SessionService.restore();
          expect(identical(first, SessionService.restore()), isTrue);
          await first;
          expect(
            SessionService.restoreStatus,
            SessionRestoreStatus.retryRequired,
          );
          expectPrivate();
          await SessionService.restore();
          expect(
            SessionService.restoreStatus,
            SessionRestoreStatus.retryRequired,
          );
          await SessionService.restore();
          expect(SessionService.isAuthenticated, isTrue);
          expect(keys.toSet().length, 3);
        },
        () => MockClient((request) async {
          keys.add(request.url.queryParameters['_sessionCheck']!);
          if (calls++ == 0) {
            throw http.ClientException('private network details');
          }
          if (calls == 2) return http.Response('', 503);
          return http.Response(jsonEncode({'data': freshUser.toJson()}), 200);
        }),
      );
    },
  );

  for (final change in ['logout', 'B', 'same-token']) {
    for (final invalid in [false, true]) {
      test(
        'restore tardío ${invalid ? '401' : '200'} no afecta $change',
        () async {
          final storage = MemoryStorage()..value = stored(jwt(), alerts: true);
          final result = Completer<SessionValidationResult>();
          configure(storage, validator: (_) => result.future);
          SessionService.prepareRestore();
          final pending = SessionService.restore();
          if (change == 'logout') {
            SessionService.clear();
          } else {
            SessionService.start(
              token: change == 'B' ? jwt(role: 'USUARIO') : jwt(),
              user: freshUser.copyWith(id: 8),
            );
          }
          final generation = SessionService.generation, record = storage.value;
          result.complete(
            invalid
                ? const SessionValidationResult.invalid()
                : const SessionValidationResult.valid(freshUser),
          );
          await pending;
          expect(SessionService.generation, generation);
          expect(storage.value, record);
          expect(SessionService.wasRejected, isFalse);
          if (change == 'logout') {
            expectPrivate();
          } else {
            expect(SessionService.currentUser?.id, 8);
            expect(SessionService.isAuthenticated, isTrue);
          }
        },
      );
    }
  }

  test('token que expira durante validación no amplía vigencia', () async {
    var clock = now;
    final storage = MemoryStorage()
      ..value = stored(jwt(expires: now.millisecondsSinceEpoch ~/ 1000 + 1));
    final result = Completer<SessionValidationResult>();
    configure(storage, clock: () => clock, validator: (_) => result.future);
    SessionService.prepareRestore();
    final pending = SessionService.restore();
    clock = now.add(const Duration(seconds: 2));
    result.complete(const SessionValidationResult.valid(freshUser));
    await pending;
    expectPrivate();
    expect(storage.value, isNull);
  });

  test(
    'flags no notifican auth y llamadas antiguas no alteran registro nuevo',
    () {
      final storage = MemoryStorage();
      configure(storage);
      final token = jwt();
      SessionService.start(token: token, user: freshUser);
      final oldGeneration = SessionService.generation;
      var changes = 0;
      void listener() {
        changes++;
      }

      SessionService.changes.addListener(listener);
      SessionService.setAlertsEnabledForReload(
        true,
        token: token,
        generation: oldGeneration,
      );
      expect(changes, 0);
      expect(SessionService.alertsEnabledForReload, isTrue);
      SessionService.start(token: token, user: freshUser.copyWith(id: 8));
      final currentRecord = storage.value;
      SessionService.setAlertsEnabledForReload(
        true,
        token: token,
        generation: oldGeneration,
      );
      expect(SessionService.alertsEnabledForReload, isFalse);
      expect(storage.value, currentRecord);
      SessionService.changes.removeListener(listener);
    },
  );

  test('almacenamiento no disponible no rompe login/logout en memoria', () {
    final storage = MemoryStorage()..blocked = true;
    configure(storage);
    expect(SessionService.prepareRestore, returnsNormally);
    expect(SessionService.restoreStatus, SessionRestoreStatus.idle);
    expect(
      () => SessionService.start(token: jwt(), user: freshUser),
      returnsNormally,
    );
    expect(SessionService.isAuthenticated, isTrue);
    expect(SessionService.clear, returnsNormally);
    expectPrivate();
  });

  for (final off in [false, true]) {
    test(
      'fallo de escritura ${off ? 'OFF' : 'B'} borra registro previo recuperable',
      () {
        final storage = MemoryStorage();
        configure(storage);
        SessionService.start(token: jwt(), user: freshUser);
        SessionService.setAlertsEnabledForReload(
          true,
          token: jwt(),
          generation: SessionService.generation,
        );
        storage.writeBlocked = true;
        if (off) {
          SessionService.setAlertsEnabledForReload(
            false,
            token: jwt(),
            generation: SessionService.generation,
          );
        } else {
          SessionService.start(
            token: jwt(role: 'USUARIO'),
            user: freshUser.copyWith(id: 8),
          );
        }
        expect(storage.value, isNull);
        expect(SessionService.isAuthenticated, isTrue);
        configure(storage);
        SessionService.prepareRestore();
        expectPrivate();
        expect(SessionService.restoreStatus, SessionRestoreStatus.idle);
      },
    );
  }
}
