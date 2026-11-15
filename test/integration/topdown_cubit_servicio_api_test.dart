// PRUEBAS DE INTEGRACIÓN — TOP-DOWN en el frontend
// Componentes reales integrados: Cubit → Servicio → SessionService → cliente HTTP.
// El backend (nivel inferior) se sustituye por un STUB: MockClient de package:http/testing,
// instalado con http.runWithClient. Así se verifica el CONTRATO con la API:
// método, ruta, cabeceras, cuerpo enviado e interpretación de cada código de respuesta.
import 'dart:convert';

import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/cubits/login_state.dart';
import 'package:crowdradar/cubits/places/places_cubit.dart';
import 'package:crowdradar/cubits/places/places_state.dart';
import 'package:crowdradar/models/saturation_model.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const usuarioApi = {
  'id': 7,
  'nombre': 'Ana',
  'apellido': 'Pérez',
  'email': 'ana@crowdradar.test',
  'rol': 'USUARIO',
};

void main() {
  tearDown(SessionService.clear);

  group('AuthCubit → AuthService → API (login)', () {
    test(
      'login correcto envía el JSON esperado, abre la sesión y emite AuthLoggedIn',
      () async {
        final peticiones = <http.Request>[];
        await http.runWithClient(
          () async {
            final cubit = AuthCubit();
            await cubit.login('ana@crowdradar.test', 'ClaveSegura1');
            expect(cubit.state, isA<AuthLoggedIn>());
            expect(SessionService.isAuthenticated, isTrue);
            expect(SessionService.token, 'jwt-de-prueba');
            expect(SessionService.currentUser?.id, 7);
            await cubit.close();
          },
          () => MockClient((request) async {
            peticiones.add(request);
            return json(200, {
              'message': 'Inicio de sesión exitoso.',
              'data': {'token': 'jwt-de-prueba', 'user': usuarioApi},
            });
          }),
        );

        final peticion = peticiones.single;
        expect(peticion.method, 'POST');
        expect(peticion.url.path, '/api/auth/login');
        expect(jsonDecode(peticion.body), {
          'email': 'ana@crowdradar.test',
          'password': 'ClaveSegura1',
        });
      },
    );

    final casos = <int, Map<String, dynamic>>{
      401: {'code': 'INVALID_CREDENTIALS'},
      403: {'code': 'ACCOUNT_SUSPENDED'},
      503: {'code': 'SERVICE_UNAVAILABLE'},
    };
    casos.forEach((status, cuerpo) {
      test('respuesta $status → AuthError y la sesión sigue cerrada', () async {
        await http.runWithClient(() async {
          final cubit = AuthCubit();
          await cubit.login('ana@crowdradar.test', 'x');
          expect(cubit.state, isA<AuthError>());
          if (status == 403) {
            expect((cubit.state as AuthError).error, contains('suspendida'));
          }
          expect(SessionService.isAuthenticated, isFalse);
          await cubit.close();
        }, () => MockClient((_) async => json(status, cuerpo)));
      });
    });

    test(
      'sin conexión con el backend → mensaje de conexión, sin sesión',
      () async {
        await http.runWithClient(
          () async {
            final cubit = AuthCubit();
            await cubit.login('ana@crowdradar.test', 'ClaveSegura1');
            expect(cubit.state, isA<AuthError>());
            expect(SessionService.isAuthenticated, isFalse);
            await cubit.close();
          },
          () => MockClient((_) async => throw http.ClientException('sin red')),
        );
      },
    );
  });

  group('PlacesCubit → PlaceService → API (lugares)', () {
    Map<String, dynamic> lugar(int id, String nombre) => {
      'id': id,
      'nombre': nombre,
      'categoria': 'Parque',
      'latitud': -12.1,
      'longitud': -77.0,
      'demostrativo': false,
      'esFavorito': id == 2,
    };

    Future<void> conSesion() async {
      await http.runWithClient(
        () => AuthCubit().login('ana@crowdradar.test', 'ClaveSegura1'),
        () => MockClient(
          (_) async => json(200, {
            'data': {'token': 'jwt-de-prueba', 'user': usuarioApi},
          }),
        ),
      );
    }

    test(
      'el filtro de saturación viaja como query param y la respuesta se convierte en modelos',
      () async {
        await conSesion();
        late http.Request peticion;
        await http.runWithClient(
          () async {
            final cubit = PlacesCubit(PlaceService());
            await cubit.filtrarPorSaturacion(SaturationLevel.saturado);
            final estado = cubit.state as PlacesLoaded;
            expect(estado.places.map((l) => l.nombre), ['Plaza', 'Kennedy']);
            expect(estado.places.last.esFavorito, isTrue);
            await cubit.close();
          },
          () => MockClient((request) async {
            peticion = request;
            return json(200, {
              'data': [lugar(1, 'Plaza'), lugar(2, 'Kennedy')],
            });
          }),
        );

        expect(peticion.url.path, '/api/places');
        expect(peticion.url.queryParameters, {'nivel': 'SATURADO'});
        expect(peticion.headers['Authorization'], 'Bearer jwt-de-prueba');
      },
    );

    test('401 del backend cierra la sesión local (token revocado)', () async {
      await conSesion();
      await http.runWithClient(() async {
        final cubit = PlacesCubit(PlaceService());
        await cubit.loadPlaces();
        expect(SessionService.isAuthenticated, isFalse);
        expect(SessionService.wasRejected, isTrue);
        await cubit.close();
      }, () => MockClient((_) async => json(401, {'code': 'SESSION_INVALID'})));
    });

    test(
      'lugar con coordenadas fuera de rango en la respuesta → PlacesError (contrato roto)',
      () async {
        await conSesion();
        await http.runWithClient(
          () async {
            final cubit = PlacesCubit(PlaceService());
            await cubit.loadPlaces();
            expect(
              (cubit.state as PlacesError).message,
              PlaceService.loadError,
            );
            await cubit.close();
          },
          () => MockClient(
            (_) async => json(200, {
              'data': [
                {...lugar(1, 'Plaza'), 'latitud': 95},
              ],
            }),
          ),
        );
      },
    );

    test(
      'filtro inválido (400 SATURATION_FILTER_INVALID) muestra el mensaje específico',
      () async {
        await conSesion();
        await http.runWithClient(
          () async {
            final cubit = PlacesCubit(PlaceService());
            await cubit.filtrarPorSaturacion(SaturationLevel.moderado);
            expect(
              (cubit.state as PlacesError).message,
              PlaceService.filtroError,
            );
            await cubit.close();
          },
          () => MockClient(
            (_) async => json(400, {'code': 'SATURATION_FILTER_INVALID'}),
          ),
        );
      },
    );
  });
}
