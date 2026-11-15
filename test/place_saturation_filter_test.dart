import 'dart:async';
import 'dart:convert';
import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/cubits/places/places_cubit.dart';
import 'package:crowdradar/cubits/places/places_state.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/saturation_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _lugarJson = {
  'id': -1,
  'nombre': 'Lugar de prueba',
  'categoria': 'Parque',
  'latitud': -12.0464,
  'longitud': -77.0428,
  'demostrativo': true,
};
final _lugares = [PlaceModel.fromJson(_lugarJson)];

class _Servicio extends PlaceService {
  final Future<GenericResponse<List<PlaceModel>>> Function(SaturationLevel?)
  consultar;
  _Servicio(this.consultar);
  @override
  Future<GenericResponse<List<PlaceModel>>> getPlaces() => consultar(null);
  @override
  Future<GenericResponse<List<PlaceModel>>> getPlacesBySaturation(
    SaturationLevel nivel,
  ) => consultar(nivel);
}

void main() {
  setUp(() {
    SessionService.clear();
    SessionService.start(token: 'test-token', user: const UserModel(id: 1));
  });
  tearDown(SessionService.clear);

  for (final nivel in SaturationLevel.values) {
    test(
      'servicio envía ${nivel.valorApi} con JWT sin calcular votos',
      () async {
        await http.runWithClient(
          () async {
            final resultado = await PlaceService().getPlacesBySaturation(nivel);
            expect(resultado.success, isTrue);
            expect(resultado.data!.single.id, -1);
            expect(resultado.data!.single.nombre, 'Lugar de prueba');
          },
          () => MockClient((peticion) async {
            expect(peticion.method, 'GET');
            expect(peticion.url.path, '/api/places');
            expect(peticion.url.queryParameters, {'nivel': nivel.valorApi});
            expect(peticion.headers['Authorization'], 'Bearer test-token');
            return http.Response(
              jsonEncode({
                'data': [_lugarJson],
              }),
              200,
            );
          }),
        );
      },
    );
    test(
      'cubit aplica ${nivel.etiqueta}, mantiene actualizar y quitar',
      () async {
        final solicitudes = <SaturationLevel?>[];
        final cubit = PlacesCubit(
          _Servicio((valor) async {
            solicitudes.add(valor);
            return GenericResponse(success: true, data: _lugares);
          }),
        );
        addTearDown(cubit.close);
        await cubit.loadPlaces();
        final filtrado = cubit.filtrarPorSaturacion(nivel);
        expect(cubit.state, isA<PlacesLoading>());
        expect(cubit.nivelSaturacion, nivel);
        await filtrado;
        expect((cubit.state as PlacesLoaded).places.single.id, -1);
        await cubit.loadPlaces();
        await cubit.filtrarPorSaturacion(null);
        expect(cubit.nivelSaturacion, isNull);
        expect(solicitudes, [null, nivel, nivel, null]);
      },
    );
  }
  test('Todos conserva el endpoint sin query histórico', () async {
    await http.runWithClient(
      () async {
        final resultado = await PlaceService().getPlaces();
        expect(resultado.success, isTrue);
        expect(resultado.data, isEmpty);
      },
      () => MockClient((peticion) async {
        expect(peticion.url.query, isEmpty);
        return http.Response('{"data":[]}', 200);
      }),
    );
  });
  test(
    'sin sesión el filtro no solicita HTTP ni guarda una selección',
    () async {
      SessionService.clear();
      var solicitudes = 0;
      await http.runWithClient(
        () async {
          expect(
            (await PlaceService().getPlacesBySaturation(
              SaturationLevel.tranquilo,
            )).success,
            isFalse,
          );
          final cubit = PlacesCubit(
            _Servicio((_) async {
              solicitudes++;
              return const GenericResponse(success: true, data: []);
            }),
          );
          addTearDown(cubit.close);
          await cubit.filtrarPorSaturacion(SaturationLevel.moderado);
          expect(cubit.nivelSaturacion, isNull);
          expect(solicitudes, 0);
        },
        () => MockClient((_) async {
          solicitudes++;
          throw StateError('No debe consultar');
        }),
      );
    },
  );
  for (final caso in <(int, String, String)>[
    (
      401,
      'detalle privado',
      'Tu sesión no es válida. Vuelve a iniciar sesión.',
    ),
    (
      400,
      '{"code":"SATURATION_FILTER_INVALID","message":"privado"}',
      PlaceService.filtroError,
    ),
    (400, '{"code":"OTRO","message":"privado"}', PlaceService.loadError),
    (503, '{"message":"SQL privado"}', PlaceService.loadError),
    (200, 'no-json', PlaceService.loadError),
    (200, '{"data":[null]}', PlaceService.loadError),
    (200, '{"data":{}}', PlaceService.loadError),
  ]) {
    test('filtro sanea HTTP ${caso.$1} / ${caso.$2}', () async {
      await http.runWithClient(() async {
        final resultado = await PlaceService().getPlacesBySaturation(
          SaturationLevel.saturado,
        );
        expect(resultado.success, isFalse);
        expect(resultado.data, isNull);
        expect(resultado.message, caso.$3);
      }, () => MockClient((_) async => http.Response(caso.$2, caso.$1)));
    });
  }
  testWidgets('filtro mantiene timeout de 15 segundos', (tester) async {
    final respuesta = Completer<http.Response>();
    await http.runWithClient(() async {
      final pendiente = PlaceService().getPlacesBySaturation(
        SaturationLevel.tranquilo,
      );
      await tester.pump(const Duration(seconds: 16));
      expect((await pendiente).message, PlaceService.loadError);
      respuesta.complete(http.Response('{}', 200));
      await tester.pump();
    }, () => MockClient((_) => respuesta.future));
  });
  test('excepción de conexión filtrada es pública', () async {
    await http.runWithClient(() async {
      expect(
        (await PlaceService().getPlacesBySaturation(
          SaturationLevel.moderado,
        )).message,
        PlaceService.loadError,
      );
    }, () => MockClient((_) async => throw http.ClientException('privado')));
  });
  for (final nuevaSesion in [false, true]) {
    test(
      'servicio descarta respuesta tras cambio sesión $nuevaSesion',
      () async {
        final inicio = Completer<void>();
        final respuesta = Completer<http.Response>();
        await http.runWithClient(
          () async {
            final pendiente = PlaceService().getPlacesBySaturation(
              SaturationLevel.tranquilo,
            );
            await inicio.future;
            SessionService.clear();
            if (nuevaSesion) {
              SessionService.start(
                token: 'test-token',
                user: const UserModel(id: 1),
              );
            }
            respuesta.complete(
              http.Response(
                jsonEncode({
                  'data': [_lugarJson],
                }),
                200,
              ),
            );
            final resultado = await pendiente;
            expect(resultado.success, isFalse);
            expect(resultado.data, isNull);
          },
          () => MockClient((_) {
            inicio.complete();
            return respuesta.future;
          }),
        );
      },
    );
  }
  test(
    'cubit reintenta el mismo nivel después de error y acepta vacío',
    () async {
      final solicitudes = <SaturationLevel?>[];
      final cubit = PlacesCubit(
        _Servicio((nivel) async {
          solicitudes.add(nivel);
          return solicitudes.length == 1
              ? const GenericResponse(
                  success: false,
                  message: PlaceService.loadError,
                )
              : const GenericResponse(success: true, data: []);
        }),
      );
      addTearDown(cubit.close);
      await cubit.filtrarPorSaturacion(SaturationLevel.saturado);
      expect(cubit.state, isA<PlacesError>());
      expect(cubit.nivelSaturacion, SaturationLevel.saturado);
      await cubit.loadPlaces();
      expect((cubit.state as PlacesLoaded).places, isEmpty);
      expect(solicitudes, [SaturationLevel.saturado, SaturationLevel.saturado]);
    },
  );
  for (final quitar in [false, true]) {
    test(
      'última selección gana incluso frente a respuesta tardía quitar=$quitar',
      () async {
        final primera = Completer<GenericResponse<List<PlaceModel>>>();
        final cubit = PlacesCubit(
          _Servicio(
            (nivel) async => nivel == SaturationLevel.tranquilo
                ? primera.future
                : const GenericResponse(success: true, data: []),
          ),
        );
        addTearDown(cubit.close);
        final pendiente = cubit.filtrarPorSaturacion(SaturationLevel.tranquilo);
        final ultimo = quitar ? null : SaturationLevel.moderado;
        await cubit.filtrarPorSaturacion(ultimo);
        primera.complete(GenericResponse(success: true, data: _lugares));
        await pendiente;
        expect(cubit.nivelSaturacion, ultimo);
        expect((cubit.state as PlacesLoaded).places, isEmpty);
      },
    );
  }
  for (final accion in ['logout', 'replace', 'close']) {
    test('cubit descarta y retira selección ante $accion', () async {
      final respuesta = Completer<GenericResponse<List<PlaceModel>>>();
      final cubit = PlacesCubit(_Servicio((_) => respuesta.future));
      addTearDown(() async {
        if (!cubit.isClosed) await cubit.close();
      });
      final pendiente = cubit.filtrarPorSaturacion(SaturationLevel.saturado);
      if (accion == 'close') {
        await cubit.close();
      } else {
        SessionService.clear();
        if (accion == 'replace') {
          SessionService.start(
            token: 'test-token',
            user: const UserModel(id: 1),
          );
        }
        expect(cubit.nivelSaturacion, isNull);
      }
      respuesta.complete(GenericResponse(success: true, data: _lugares));
      await pendiente;
      expect(cubit.state, isNot(isA<PlacesLoaded>()));
    });
  }
  test('excepción de un doble no pierde filtro para el reintento', () async {
    final cubit = PlacesCubit(
      _Servicio((_) async => throw StateError('privado')),
    );
    addTearDown(cubit.close);
    await cubit.filtrarPorSaturacion(SaturationLevel.moderado);
    expect(cubit.nivelSaturacion, SaturationLevel.moderado);
    expect((cubit.state as PlacesError).message, PlaceService.loadError);
  });
}
