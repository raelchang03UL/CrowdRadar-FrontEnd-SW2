import 'dart:async';
import 'dart:convert';
import 'package:crowdradar/cubits/places/places_cubit.dart';
import 'package:crowdradar/cubits/places/places_state.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const placeJson = {
  'id': 1,
  'nombre': 'Lugar de prueba',
  'categoria': 'Parque',
  'latitud': -12.0464,
  'longitud': -77.0428,
  'demostrativo': true,
};

void main() {
  const user = UserModel(id: 1, nombre: 'Prueba');
  setUp(() {
    SessionService.clear();
    SessionService.start(token: 'test-token', user: user);
  });
  tearDown(SessionService.clear);

  Future<T> withResponse<T>(
    Future<T> Function() action,
    http.Response response,
  ) => http.runWithClient(action, () => MockClient((_) async => response));

  test('consulta autenticada usa endpoint y coordenadas recibidas', () async {
    await http.runWithClient(
      () async {
        final result = await PlaceService().getPlaces();
        expect(result.success, isTrue);
        expect(result.data!.single.nombre, 'Lugar de prueba');
        expect(result.data!.single.latitud, -12.0464);
        expect(result.data!.single.longitud, -77.0428);
        expect(result.data!.single.demostrativo, isTrue);
      },
      () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/places');
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode({
            'data': [placeJson],
          }),
          200,
        );
      }),
    );
  });

  test('lista vacía es un resultado válido', () async {
    await withResponse(() async {
      final result = await PlaceService().getPlaces();
      expect(result.success, isTrue);
      expect(result.data, isEmpty);
    }, http.Response('{"data":[]}', 200));
  });

  test('sin sesión no se hace ninguna petición', () async {
    SessionService.clear();
    var calls = 0;
    await http.runWithClient(
      () async {
        expect((await PlaceService().getPlaces()).success, isFalse);
        expect(calls, 0);
      },
      () => MockClient((_) async {
        calls++;
        throw StateError('No debe solicitar');
      }),
    );
  });

  test('401 informa sobre sesión sin exponer cuerpo técnico', () async {
    await withResponse(() async {
      final result = await PlaceService().getPlaces();
      expect(result.success, isFalse);
      expect(
        result.message,
        'Tu sesión no es válida. Vuelve a iniciar sesión.',
      );
    }, http.Response('internal-details', 401));
  });

  for (final response in [
    http.Response('internal-stack', 503),
    http.Response('not-json', 200),
    http.Response('{}', 200),
    http.Response('{"data":[null]}', 200),
    http.Response(
      jsonEncode({
        'data': [
          {...placeJson, 'latitud': 91},
        ],
      }),
      200,
    ),
    http.Response(
      jsonEncode({
        'data': [
          {...placeJson, 'longitud': '-77'},
        ],
      }),
      200,
    ),
  ]) {
    test('respuesta inválida ${response.body} da error público', () async {
      await withResponse(() async {
        final result = await PlaceService().getPlaces();
        expect(result.success, isFalse);
        expect(result.data, isNull);
        expect(result.message, PlaceService.loadError);
      }, response);
    });
  }

  test('fallo de conexión no expone ClientException', () async {
    await http.runWithClient(
      () async {
        final result = await PlaceService().getPlaces();
        expect(result.message, PlaceService.loadError);
        expect(result.success, isFalse);
      },
      () => MockClient(
        (_) async => throw http.ClientException('technical host detail'),
      ),
    );
  });

  test('modelo rechaza NaN e infinito antes de construir marcadores', () {
    for (final latitude in [double.nan, double.infinity, -91, null]) {
      expect(
        () => PlaceModel.fromJson({...placeJson, 'latitud': latitude}),
        throwsFormatException,
      );
    }
  });

  for (final replaceSession in [false, true]) {
    test(
      'descarta respuesta pendiente si sesión ${replaceSession ? 'cambia con mismo JWT' : 'se cierra'}',
      () async {
        final requested = Completer<void>();
        final response = Completer<http.Response>();
        await http.runWithClient(
          () async {
            final pending = PlaceService().getPlaces();
            await requested.future;
            SessionService.clear();
            if (replaceSession) {
              SessionService.start(token: 'test-token', user: user);
            }
            response.complete(
              http.Response(
                jsonEncode({
                  'data': [placeJson],
                }),
                200,
              ),
            );
            final result = await pending;
            expect(result.success, isFalse);
            expect(result.data, isNull);
            expect(result.message, 'La sesión cambió durante la solicitud');
          },
          () => MockClient((_) {
            requested.complete();
            return response.future;
          }),
        );
      },
    );
  }

  test(
    'cubit emite carga, datos y borra lista inmediatamente al cerrar sesión',
    () async {
      await withResponse(
        () async {
          final cubit = PlacesCubit(PlaceService());
          addTearDown(cubit.close);
          final pending = cubit.loadPlaces();
          expect(cubit.state, isA<PlacesLoading>());
          await pending;
          expect((cubit.state as PlacesLoaded).places.length, 1);
          SessionService.clear();
          expect(cubit.state, isA<PlacesInitial>());
        },
        http.Response(
          jsonEncode({
            'data': [placeJson],
          }),
          200,
        ),
      );
    },
  );

  for (final closedCubit in [false, true]) {
    test(
      'cubit descarta respuesta tras ${closedCubit ? 'dispose' : 'logout'}',
      () async {
        final requested = Completer<void>();
        final response = Completer<http.Response>();
        await http.runWithClient(
          () async {
            final cubit = PlacesCubit(PlaceService());
            addTearDown(cubit.close);
            final pending = cubit.loadPlaces();
            await requested.future;
            SessionService.clear();
            if (closedCubit) await cubit.close();
            response.complete(
              http.Response(
                jsonEncode({
                  'data': [placeJson],
                }),
                200,
              ),
            );
            await expectLater(pending, completes);
            expect(cubit.state, isNot(isA<PlacesLoaded>()));
          },
          () => MockClient((_) {
            requested.complete();
            return response.future;
          }),
        );
      },
    );
  }

  test(
    'cubit conserva solo el resultado de la solicitud más reciente',
    () async {
      final first = Completer<http.Response>();
      final requested = Completer<void>();
      var calls = 0;
      await http.runWithClient(
        () async {
          final cubit = PlacesCubit(PlaceService());
          addTearDown(cubit.close);
          final pending = cubit.loadPlaces();
          await requested.future;
          await cubit.loadPlaces();
          expect((cubit.state as PlacesLoaded).places, isEmpty);
          first.complete(
            http.Response(
              jsonEncode({
                'data': [placeJson],
              }),
              200,
            ),
          );
          await pending;
          expect((cubit.state as PlacesLoaded).places, isEmpty);
        },
        () => MockClient((_) {
          if (calls++ == 0) {
            requested.complete();
            return first.future;
          }
          return Future.value(http.Response('{"data":[]}', 200));
        }),
      );
    },
  );
}
