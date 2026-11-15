import 'dart:async';
import 'dart:convert';
import 'package:crowdradar/services/saturation_report_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(
    () => SessionService.start(token: 'QA-A', user: const UserModel(id: 1)),
  );
  tearDown(SessionService.clear);
  Future<dynamic> send(http.Client client) => http.runWithClient(
    () => SaturationReportService().createReport(
      placeId: -701,
      level: SaturationLevel.tranquil,
    ),
    () => client,
  );
  test(
    'solo 409 + REPORT_COOLDOWN confirma que no hay otro registro/premio',
    () async {
      final result = await send(
        MockClient(
          (_) async => http.Response(
            '{"code":"REPORT_COOLDOWN","message":"private"}',
            409,
          ),
        ),
      );
      expect(result.success, false);
      expect(result.error, 'REPORT_COOLDOWN');
      expect(
        result.message,
        contains('no registró otro reporte ni añadió puntos'),
      );
      expect(result.message, isNot(contains('private')));
    },
  );
  for (final item in [
    (409, '{"code":"OTHER_CONFLICT"}'),
    (409, 'unreadable'),
    (409, '[]'),
    (503, '{"code":"REPORT_COOLDOWN"}'),
    (500, '{}'),
    (200, '{}'),
    (201, '{}'),
    (201, 'bad json'),
    (201, '{"message":"ok","data":{"id":0}}'),
    (201, '{"message":"ok","data":{"id":"not-an-id"}}'),
    (201, '{"message":"ok","data":{"id":"1","placeId":-702}}'),
  ]) {
    test(
      '${item.$1} ${item.$2}: resultado incierto, no fracaso definitivo',
      () async {
        final result = await send(
          MockClient((_) async => http.Response(item.$2, item.$1)),
        );
        expect(result.success, false);
        expect(result.error, 'REPORT_UNCERTAIN');
        expect(result.data, isNull);
        expect(
          result.message,
          contains('Revisa Mis reportes antes de volver a enviarlo'),
        );
      },
    );
  }
  for (final failure in ['timeout', 'offline', 'commit-response-lost']) {
    test(
      '$failure: una solicitud, sin reenvío aunque el servidor haya confirmado',
      () async {
        var calls = 0;
        var committed = 0;
        final result = await send(
          MockClient((_) async {
            calls++;
            if (failure == 'commit-response-lost') committed++;
            if (failure == 'offline') {
              throw http.ClientException('private offline');
            }
            throw TimeoutException('private timeout');
          }),
        );
        expect(result.error, 'REPORT_UNCERTAIN');
        expect(result.success, false);
        expect(result.data, isNull);
        expect(calls, 1);
        expect(committed, failure == 'commit-response-lost' ? 1 : 0);
        expect(SessionService.isAuthenticated, true);
      },
    );
  }
  for (final reward in [
    null,
    {'pointsAwarded': 10, 'karmaPoints': 37},
    {'pointsAwarded': -1, 'karmaPoints': 37},
  ]) {
    test(
      '201 válido: usa recompensa real o no muestra puntos ($reward)',
      () async {
        final result = await send(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                'message': 'Reporte enviado correctamente.',
                'data': {
                  'id': '99',
                  'placeId': -701,
                  'level': 'TRANQUILO',
                  ...?reward,
                },
              }),
              201,
            ),
          ),
        );
        expect(result.success, true);
        if (reward?['pointsAwarded'] == 10) {
          expect(result.data.pointsAwarded, 10);
          expect(result.data.karmaPoints, 37);
        } else {
          expect(result.data, isNull);
        }
      },
    );
  }
  test('401 vigente invalida la sesión del reporte', () async {
    await send(MockClient((_) async => http.Response('{}', 401)));
    expect(SessionService.isAuthenticated, false);
  });
  for (final status in [201, 401, 409, 503]) {
    test('$status de A no cierra ni atribuye recompensa a B', () async {
      final pending = Completer<http.Response>();
      final request = send(MockClient((_) => pending.future));
      await Future<void>.delayed(Duration.zero);
      SessionService.clear();
      SessionService.start(token: 'QA-B', user: const UserModel(id: 2));
      pending.complete(
        http.Response(
          '{"message":"ok","data":{"id":"99","pointsAwarded":10,"karmaPoints":10}}',
          status,
        ),
      );
      final result = await request;
      expect(result.success, false);
      expect(result.data, isNull);
      expect(SessionService.token, 'QA-B');
    });
  }
}
