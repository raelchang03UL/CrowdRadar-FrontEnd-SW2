import 'dart:async';
import 'dart:convert';
import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/cubits/places/saturation_cubit.dart';
import 'package:crowdradar/models/saturation_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/services/saturation_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const saturationJson = {
  'placeId': -1,
  'level': 'TRANQUILO',
  'reportCount': 3,
  'windowMinutes': 30,
  'minimumReports': 3,
  'reason': null,
  'evaluatedAt': '2026-10-11T17:25:00.000Z',
  'updatedAt': '2026-10-11T17:20:00.000Z',
};

class _Service extends SaturationService {
  final Future<GenericResponse<SaturationModel>> Function(int) load;
  _Service(this.load);
  @override
  Future<GenericResponse<SaturationModel>> getSaturation(int placeId) =>
      load(placeId);
}

void main() {
  setUp(() {
    SessionService.clear();
    SessionService.start(token: 'test-token', user: const UserModel(id: 1));
  });
  tearDown(SessionService.clear);

  for (final level in ['TRANQUILO', 'MODERADO', 'SATURADO']) {
    test('DTO acepta $level y conserva cifras/fechas de API', () {
      final model = SaturationModel.fromJson({
        ...saturationJson,
        'level': level,
      });
      expect(model.placeId, -1);
      expect(
        model.level,
        SaturationLevel.values[[
          'TRANQUILO',
          'MODERADO',
          'SATURADO',
        ].indexOf(level)],
      );
      expect(model.reportCount, 3);
      expect(model.windowMinutes, 30);
      expect(model.minimumReports, 3);
      expect(model.reason, isNull);
      expect(model.evaluatedAt.isUtc, true);
      expect(model.updatedAt!.isUtc, true);
    });
  }

  test('DTO distingue cero, pocos reportes y empate sin inventar un nivel', () {
    for (final count in [0, 2, 3]) {
      final model = SaturationModel.fromJson({
        ...saturationJson,
        'level': null,
        'reportCount': count,
        'reason': count < 3 ? 'INSUFFICIENT_REPORTS' : 'TIE',
        'updatedAt': count == 0 ? null : saturationJson['updatedAt'],
      });
      expect(model.level, isNull);
      expect(
        model.reason,
        count < 3 ? SaturationReason.insufficientReports : SaturationReason.tie,
      );
    }
  });

  test('DTO acepta límites de ID y reporte justo al inicio de ventana', () {
    for (final id in [-2147483648, 2147483647]) {
      expect(
        SaturationModel.fromJson({
          ...saturationJson,
          'placeId': id,
          'updatedAt': '2026-10-11T16:55:00.000Z',
        }).placeId,
        id,
      );
    }
  });

  final invalidChanges = <Map<String, dynamic>>[
    {'placeId': 0},
    {'placeId': '1'},
    {'placeId': 2147483648},
    {'reportCount': -1},
    {'reportCount': 3.0},
    {'reportCount': '3'},
    {'windowMinutes': 0},
    {'minimumReports': 0},
    {'windowMinutes': 30.0},
    {'level': 'BAJO'},
    {'reason': 'UNKNOWN'},
    {'reason': 'TIE'},
    {'level': null},
    {'reportCount': 2},
    {'updatedAt': null},
    {'evaluatedAt': 'not-a-date'},
    {'evaluatedAt': '2026-10-11T17:25:00'},
    {'evaluatedAt': '2026-02-30T17:25:00.000Z'},
    {'updatedAt': '2026-10-11T17:26:00.000Z'},
    {'updatedAt': '2026-10-11T16:54:59.999Z'},
    {'level': null, 'reason': 'TIE', 'reportCount': 2},
    {'level': null, 'reason': 'INSUFFICIENT_REPORTS'},
    {'level': null, 'reason': 'INSUFFICIENT_REPORTS', 'reportCount': 0},
  ];
  for (var index = 0; index < invalidChanges.length; index++) {
    test('DTO rechaza datos incoherentes #$index', () {
      expect(
        () => SaturationModel.fromJson({
          ...saturationJson,
          ...invalidChanges[index],
        }),
        throwsFormatException,
      );
    });
  }
  for (final key in [
    'level',
    'reason',
    'updatedAt',
    'evaluatedAt',
    'minimumReports',
  ]) {
    test('DTO rechaza campo ausente $key', () {
      final json = {...saturationJson}..remove(key);
      expect(() => SaturationModel.fromJson(json), throwsFormatException);
    });
  }

  Future<GenericResponse<SaturationModel>> responseResult(
    http.Response response,
  ) => http.runWithClient(
    () => SaturationService().getSaturation(-1),
    () => MockClient((_) async => response),
  );

  test('GET autenticado usa ID negativo y DTO UTF-8 válido', () async {
    await http.runWithClient(
      () async {
        final result = await SaturationService().getSaturation(-1);
        expect(result.success, true);
        expect(result.data!.level, SaturationLevel.tranquilo);
      },
      () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/places/-1/saturation');
        expect(request.url.query, isEmpty);
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(jsonEncode({'data': saturationJson}), 200);
      }),
    );
  });

  test('sin sesión o ID inválido no envía HTTP', () async {
    var calls = 0;
    await http.runWithClient(
      () async {
        for (final id in [0, -2147483649, 2147483648]) {
          expect((await SaturationService().getSaturation(id)).success, false);
        }
        SessionService.clear();
        expect((await SaturationService().getSaturation(-1)).success, false);
        expect(calls, 0);
      },
      () => MockClient((_) async {
        calls++;
        throw StateError('No debe enviar HTTP');
      }),
    );
  });

  for (final status in [400, 401, 404, 503]) {
    test(
      'HTTP $status tiene mensaje público sin cuerpo del servidor',
      () async {
        final result = await responseResult(
          http.Response('SQL private stack token', status),
        );
        expect(result.success, false);
        expect(result.data, isNull);
        expect(
          result.message,
          status == 401
              ? 'Tu sesión no es válida. Vuelve a iniciar sesión.'
              : status == 404
              ? 'Este lugar ya no está disponible.'
              : SaturationService.loadError,
        );
      },
    );
  }
  for (final body in [
    'not-json',
    '{}',
    '{"data":[]}',
    jsonEncode({
      'data': {...saturationJson, 'placeId': 2},
    }),
  ]) {
    test('servicio no acepta cuerpo inválido/otro lugar: $body', () async {
      final result = await responseResult(http.Response(body, 200));
      expect(result.success, false);
      expect(result.message, SaturationService.loadError);
    });
  }
  test('excepción de red saneada', () async {
    await http.runWithClient(
      () async {
        final result = await SaturationService().getSaturation(-1);
        expect(result.success, false);
        expect(result.message, SaturationService.loadError);
      },
      () => MockClient((_) async => throw http.ClientException('private host')),
    );
  });
  testWidgets('timeout HTTP de 15 segundos da error público', (tester) async {
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      final result = SaturationService().getSaturation(-1);
      await tester.pump(const Duration(seconds: 16));
      expect((await result).message, SaturationService.loadError);
      response.complete(http.Response('{}', 200));
      await tester.pump();
    }, () => MockClient((_) => response.future));
  });

  for (final action in ['logout', 'replace', 'close', 'unselect']) {
    test('cubit descarta respuesta después de $action', () async {
      final response = Completer<GenericResponse<SaturationModel>>();
      final cubit = SaturationCubit(_Service((_) => response.future));
      addTearDown(() async {
        if (!cubit.isClosed) {
          await cubit.close();
        }
      });
      final pending = cubit.loadPlace(-1);
      expect(cubit.state.status, SaturationStatus.loading);
      if (action == 'close') {
        await cubit.close();
      } else if (action == 'unselect') {
        cubit.clearSelection();
      } else {
        SessionService.clear();
        if (action == 'replace') {
          SessionService.start(
            token: 'test-token',
            user: const UserModel(id: 2),
          );
        }
      }
      response.complete(
        GenericResponse(
          success: true,
          data: SaturationModel.fromJson(saturationJson),
        ),
      );
      await pending;
      expect(cubit.state.data, isNull);
      expect(cubit.state.status, isNot(SaturationStatus.loaded));
    });
  }
  for (final replacement in [false, true]) {
    test(
      'servicio descarta respuesta HTTP después de cambio de sesión, nueva=$replacement',
      () async {
        final response = Completer<http.Response>();
        await http.runWithClient(() async {
          final pending = SaturationService().getSaturation(-1);
          SessionService.clear();
          if (replacement) {
            SessionService.start(
              token: 'test-token',
              user: const UserModel(id: 2),
            );
          }
          response.complete(
            http.Response(jsonEncode({'data': saturationJson}), 200),
          );
          final result = await pending;
          expect(result.success, false);
          expect(result.data, isNull);
        }, () => MockClient((_) => response.future));
      },
    );
  }
  test(
    'cubit conserva selección más reciente y no repone el lugar anterior',
    () async {
      final first = Completer<GenericResponse<SaturationModel>>();
      final cubit = SaturationCubit(
        _Service(
          (id) => id == -1
              ? first.future
              : Future.value(
                  GenericResponse(
                    success: true,
                    data: SaturationModel.fromJson({
                      ...saturationJson,
                      'placeId': 2,
                      'level': 'SATURADO',
                    }),
                  ),
                ),
        ),
      );
      addTearDown(cubit.close);
      final pending = cubit.loadPlace(-1);
      await cubit.loadPlace(2);
      first.complete(
        GenericResponse(
          success: true,
          data: SaturationModel.fromJson(saturationJson),
        ),
      );
      await pending;
      expect(cubit.state.placeId, 2);
      expect(cubit.state.data!.level, SaturationLevel.saturado);
    },
  );
  test('cubit sin sesión no invoca servicio', () async {
    SessionService.clear();
    final cubit = SaturationCubit(
      _Service((_) => throw StateError('No llamar')),
    );
    addTearDown(cubit.close);
    await cubit.loadPlace(-1);
    expect(cubit.state.status, SaturationStatus.initial);
  });
  test('cubit permite reintentar después de error público', () async {
    var calls = 0;
    final cubit = SaturationCubit(
      _Service(
        (_) async => calls++ == 0
            ? const GenericResponse(
                success: false,
                message: SaturationService.loadError,
              )
            : GenericResponse(
                success: true,
                data: SaturationModel.fromJson(saturationJson),
              ),
      ),
    );
    addTearDown(cubit.close);
    await cubit.loadPlace(-1);
    expect(cubit.state.status, SaturationStatus.error);
    await cubit.loadPlace(-1);
    expect(cubit.state.status, SaturationStatus.loaded);
    expect(calls, 2);
  });
}
