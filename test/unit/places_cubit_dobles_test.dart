// PRUEBAS UNITARIAS — CAJA BLANCA con DOBLES DE PRUEBA
// Unidad: PlacesCubit.loadPlaces(). PlaceService se sustituye por un Mock escrito a mano
// (subclase que registra las llamadas y devuelve respuestas configuradas).
//
// Camino básico de la cadena de decisiones de loadPlaces():
//   P1 ¿sesión autenticada?          P2 ¿más de un filtro activo?
//   P3 ¿hay consulta por nombre?     P4 ¿hay categoría?     P5 ¿hay nivel?
//   P6 ¿respuesta exitosa?
// V(G) = 6 + 1 = 7 caminos independientes:
//   C1 sin sesión → PlacesInitial            C2 varios filtros → queryPlaces
//   C3 solo nombre → searchPlaces            C4 solo categoría → filterPlacesByCategory
//   C5 solo nivel → getPlacesBySaturation    C6 sin filtros → getPlaces (éxito)
//   C7 respuesta fallida → PlacesError
import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/cubits/places/places_cubit.dart';
import 'package:crowdradar/cubits/places/places_state.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/saturation_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';

const lugarDemo = PlaceModel(
  id: 1,
  nombre: 'Plaza',
  categoria: 'Plaza',
  latitud: -12,
  longitud: -77,
  demostrativo: false,
);

class PlaceServiceMock extends PlaceService {
  final llamadas = <String>[];
  GenericResponse<List<PlaceModel>> respuesta = const GenericResponse(
    success: true,
    data: [lugarDemo],
  );

  Future<GenericResponse<List<PlaceModel>>> _registrar(String llamada) async {
    llamadas.add(llamada);
    return respuesta;
  }

  @override
  Future<GenericResponse<List<PlaceModel>>> getPlaces() =>
      _registrar('getPlaces');

  @override
  Future<GenericResponse<List<PlaceModel>>> searchPlaces(String consulta) =>
      _registrar('searchPlaces($consulta)');

  @override
  Future<GenericResponse<List<PlaceModel>>> filterPlacesByCategory(
    String categoria,
  ) => _registrar('filterPlacesByCategory($categoria)');

  @override
  Future<GenericResponse<List<PlaceModel>>> getPlacesBySaturation(
    SaturationLevel nivel,
  ) => _registrar('getPlacesBySaturation(${nivel.valorApi})');

  @override
  Future<GenericResponse<List<PlaceModel>>> queryPlaces({
    String nombre = '',
    String categoria = '',
    SaturationLevel? nivel,
  }) => _registrar('queryPlaces($nombre|$categoria|${nivel?.valorApi})');
}

void main() {
  late PlaceServiceMock servicio;
  late PlacesCubit cubit;

  setUp(() {
    SessionService.start(token: 'token-prueba', user: const UserModel(id: 1));
    servicio = PlaceServiceMock();
    cubit = PlacesCubit(servicio);
  });

  tearDown(() async {
    await cubit.close();
    SessionService.clear();
  });

  test(
    'C1: sin sesión no consulta el servicio y queda en PlacesInitial',
    () async {
      SessionService.clear();
      await cubit.loadPlaces();
      expect(cubit.state, isA<PlacesInitial>());
      expect(servicio.llamadas, isEmpty);
    },
  );

  test('C2: nombre + categoría → una sola consulta combinada', () async {
    await cubit.filterByCategory('Parque');
    await cubit.searchPlaces('Kennedy');
    expect(servicio.llamadas.last, 'queryPlaces(Kennedy|Parque|null)');
  });

  test('C3: solo nombre → searchPlaces', () async {
    await cubit.searchPlaces('Plaza');
    expect(servicio.llamadas, ['searchPlaces(Plaza)']);
    expect(cubit.state, isA<PlacesLoaded>());
  });

  test('C4: solo categoría → filterPlacesByCategory', () async {
    await cubit.filterByCategory('Mercado');
    expect(servicio.llamadas, ['filterPlacesByCategory(Mercado)']);
  });

  test('C5: solo nivel → getPlacesBySaturation', () async {
    await cubit.filtrarPorSaturacion(SaturationLevel.saturado);
    expect(servicio.llamadas, ['getPlacesBySaturation(SATURADO)']);
    expect(cubit.nivelSaturacion, SaturationLevel.saturado);
  });

  test(
    'C6: sin filtros → getPlaces y estado PlacesLoaded con los datos',
    () async {
      await cubit.loadPlaces();
      expect(servicio.llamadas, ['getPlaces']);
      expect((cubit.state as PlacesLoaded).places.single.nombre, 'Plaza');
    },
  );

  test(
    'C7: respuesta fallida del servicio → PlacesError con su mensaje',
    () async {
      servicio.respuesta = const GenericResponse(
        success: false,
        message: PlaceService.loadError,
      );
      await cubit.loadPlaces();
      expect((cubit.state as PlacesError).message, PlaceService.loadError);
    },
  );

  test(
    'cerrar sesión reinicia filtros y estado (listener de SessionService)',
    () async {
      await cubit.filtrarPorSaturacion(SaturationLevel.moderado);
      SessionService.clear();
      expect(cubit.state, isA<PlacesInitial>());
      expect(cubit.nivelSaturacion, isNull);
    },
  );
}
