import 'package:crowdradar/models/push_saturation_transition.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/services/push_message_guard.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const _payload = <String, dynamic>{
  'userId': '1',
  'placeId': '-2005',
  'registrationId': 'current-binding',
  'previousLevel': 'SATURADO',
  'newLevel': 'MODERADO',
};

void main() {
  late ValueNotifier<int> changes;
  String? binding;

  AuthorizedPushTransition? parse(Map<String, dynamic> data) =>
      authorizedPushTransition(
        data,
        binding,
        currentRegistrationId: () => binding,
        authorizationChanges: changes,
      );

  setUp(() {
    SessionService.clear();
    SessionService.start(token: 'test-session', user: const UserModel(id: 1));
    changes = ValueNotifier(0);
    binding = 'current-binding';
  });
  tearDown(() {
    changes.dispose();
    SessionService.clear();
  });

  test('solo admite cambios entre los cuatro niveles conocidos', () {
    const levels = ['SIN_DATOS', 'TRANQUILO', 'MODERADO', 'SATURADO'];
    for (final previous in levels) {
      for (final next in levels) {
        final transition = PushSaturationTransition.fromPayload({
          'previousLevel': previous,
          'newLevel': next,
        });
        if (previous == next) {
          expect(transition, isNull);
        } else {
          expect(transition?.previousLevel.apiValue, previous);
          expect(transition?.newLevel.apiValue, next);
        }
      }
    }
  });

  test(
    'niveles ausentes, arbitrarios o mal tipados no forman una transición',
    () {
      for (final value in <Object?>[
        null,
        '',
        'SIN DATOS',
        'sin_datos',
        ' SATURADO',
        'Texto enviado por terceros',
        1,
        <String, String>{'level': 'SATURADO'},
      ]) {
        expect(parse({..._payload, 'previousLevel': value}), isNull);
        expect(parse({..._payload, 'newLevel': value}), isNull);
      }
      expect(parse({..._payload}..remove('previousLevel')), isNull);
      expect(parse({..._payload}..remove('newLevel')), isNull);
      // Falta de contexto histórico no impide abrir el lugar autorizado.
      expect(
        authorizedPushPlace({..._payload}..remove('newLevel'), binding),
        -2005,
      );
    },
  );

  test(
    'el contexto conserva valores tipados aunque cambie el mapa recibido',
    () {
      final data = {..._payload};
      final alert = parse(data)!;
      data['newLevel'] = 'Texto arbitrario';
      data['placeId'] = '12';
      expect(alert.placeId, -2005);
      expect(alert.transition.previousLevel, PushSaturationLevel.saturado);
      expect(alert.transition.newLevel, PushSaturationLevel.moderado);
      expect(alert.isCurrentForPlace(-2005), isTrue);
      expect(alert.isCurrentForPlace(12), isFalse);
    },
  );

  test('rechaza binding ajeno, usuario ajeno y lugar inválido', () {
    expect(parse({..._payload, 'registrationId': 'previous-binding'}), isNull);
    expect(parse({..._payload, 'userId': '2'}), isNull);
    for (final id in ['0', '2147483648', '-2147483649', 'unknown', null]) {
      expect(parse({..._payload, 'placeId': id}), isNull);
    }
    binding = '';
    expect(parse({..._payload, 'registrationId': ''}), isNull);
    binding = null;
    expect(parse(_payload), isNull);
  });

  test('revalida el binding actual al crear y al usar el contexto', () {
    expect(
      authorizedPushTransition(
        _payload,
        'current-binding',
        currentRegistrationId: () => 'changed-binding',
        authorizationChanges: changes,
      ),
      isNull,
    );
    final alert = parse(_payload)!;
    binding = null;
    expect(alert.isCurrentForPlace(-2005), isFalse);
    binding = 'new-binding';
    expect(alert.isCurrentForPlace(-2005), isFalse);
  });

  test('logout invalida el contexto y la recepción sin sesión', () {
    final alert = parse(_payload)!;
    SessionService.clear();
    expect(alert.isCurrentForPlace(-2005), isFalse);
    expect(parse(_payload), isNull);
  });

  test('no reutiliza contexto al volver con la misma cuenta y token', () {
    final alert = parse(_payload)!;
    SessionService.start(token: 'test-session', user: const UserModel(id: 1));
    expect(alert.isCurrentForPlace(-2005), isFalse);
  });

  test(
    'un cambio de usuario invalida el contexto aun sin cambiar generación',
    () {
      final alert = parse(_payload)!;
      SessionService.updateUser(
        const UserModel(id: 2),
        sessionToken: 'test-session',
        sessionGeneration: SessionService.generation,
      );
      expect(alert.isCurrentForPlace(-2005), isFalse);
    },
  );
}
