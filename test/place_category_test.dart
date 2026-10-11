import 'dart:async';
import 'dart:convert';
import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/cubits/places/categorias_cubit.dart';
import 'package:crowdradar/cubits/places/places_cubit.dart';
import 'package:crowdradar/cubits/places/places_state.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/map/map_page.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _lugares = [
  PlaceModel(
    id: 1,
    nombre: 'Parque de prueba',
    categoria: 'Parque',
    latitud: -12.046,
    longitud: -77.042,
    demostrativo: true,
  ),
  PlaceModel(
    id: 2,
    nombre: 'Plaza de prueba',
    categoria: 'Plaza',
    latitud: -12.048,
    longitud: -77.044,
    demostrativo: true,
  ),
];

class _Servicio extends PlaceService {
  final consultas = <String>[];
  bool vacio = false;
  bool errorFiltro = false;
  bool errorCategorias = false;
  List<String> categorias = ['Parque', 'Plaza'];
  Future<GenericResponse<List<String>>>? categoriasPendientes;

  @override
  Future<GenericResponse<List<PlaceModel>>> getPlaces() async {
    consultas.add('');
    return const GenericResponse(success: true, data: _lugares);
  }

  @override
  Future<GenericResponse<List<PlaceModel>>> filterPlacesByCategory(
    String categoria,
  ) async {
    consultas.add(categoria);
    if (errorFiltro) {
      return const GenericResponse(
        success: false,
        message: PlaceService.loadError,
      );
    }
    return GenericResponse(
      success: true,
      data: vacio
          ? []
          : _lugares.where((lugar) => lugar.categoria == categoria).toList(),
    );
  }

  @override
  Future<GenericResponse<List<String>>> getCategories() async =>
      categoriasPendientes != null
      ? await categoriasPendientes!
      : errorCategorias
      ? const GenericResponse(
          success: false,
          message: PlaceService.categoriesError,
        )
      : GenericResponse(success: true, data: categorias);
}

class _Teselas extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

void main() {
  const usuario = UserModel(id: 1, nombre: 'Prueba');
  setUp(() {
    SessionService.clear();
    SessionService.start(token: 'test-token', user: usuario);
  });
  tearDown(SessionService.clear);

  test(
    'categoría literal usa query codificada y JWT, no concatena SQL/URL',
    () async {
      await http.runWithClient(
        () async {
          expect(
            (await PlaceService().filterPlacesByCategory(
              '  Estación & servicios?  ',
            )).success,
            isTrue,
          );
          expect(
            (await PlaceService().filterPlacesByCategory('  ')).data,
            isEmpty,
          );
        },
        () => MockClient((solicitud) async {
          expect(solicitud.url.path, '/api/places');
          expect(solicitud.headers['Authorization'], 'Bearer test-token');
          if (solicitud.url.hasQuery) {
            expect(solicitud.url.queryParameters, {
              'categoria': 'Estación & servicios?',
            });
          }
          return http.Response('{"data":[]}', 200);
        }),
      );
    },
  );

  test(
    'límite de categoría cuenta 80 caracteres Unicode y rechaza 81 antes de HTTP',
    () async {
      var llamadas = 0;
      await http.runWithClient(
        () async {
          expect(
            (await PlaceService().filterPlacesByCategory('😀' * 80)).success,
            isTrue,
          );
          expect(
            (await PlaceService().filterPlacesByCategory('😀' * 81)).success,
            isFalse,
          );
          expect(llamadas, 1);
        },
        () => MockClient((_) async {
          llamadas++;
          return http.Response('{"data":[]}', 200);
        }),
      );
    },
  );

  test(
    'consulta catálogo autenticado conserva tildes y elimina duplicados',
    () async {
      await http.runWithClient(
        () async {
          final resultado = await PlaceService().getCategories();
          expect(resultado.success, isTrue);
          expect(resultado.data, ['Estación', 'Parque']);
        },
        () => MockClient((solicitud) async {
          expect(solicitud.url.path, '/api/places/categories');
          expect(solicitud.headers['Authorization'], 'Bearer test-token');
          return http.Response(
            jsonEncode({
              'data': ['Estación', 'Parque', 'Parque'],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
    },
  );

  for (final cuerpo in [
    '{}',
    'not-json',
    '{"data":[null]}',
    '{"data":[" "]}',
    '{"data":[" Parque "]}',
    jsonEncode({
      'data': ['a' * 81],
    }),
  ]) {
    test('catálogo inválido devuelve mensaje público: $cuerpo', () async {
      await http.runWithClient(() async {
        final resultado = await PlaceService().getCategories();
        expect(resultado.success, isFalse);
        expect(resultado.message, PlaceService.categoriesError);
        expect(resultado.data, isNull);
      }, () => MockClient((_) async => http.Response(cuerpo, 200)));
    });
  }

  test('catálogo vacío es válido y errores no exponen detalles', () async {
    for (final codigo in [200, 401, 503]) {
      await http.runWithClient(
        () async {
          final resultado = await PlaceService().getCategories();
          expect(resultado.success, codigo == 200);
          if (codigo == 200) expect(resultado.data, isEmpty);
          expect(resultado.message, isNot(contains('internal-host')));
        },
        () => MockClient(
          (_) async => http.Response(
            codigo == 200 ? '{"data":[]}' : 'internal-host',
            codigo,
          ),
        ),
      );
    }
  });

  test('sin sesión no consulta categorías ni filtro', () async {
    SessionService.clear();
    await http.runWithClient(() async {
      expect((await PlaceService().getCategories()).success, isFalse);
      expect(
        (await PlaceService().filterPlacesByCategory('Parque')).success,
        isFalse,
      );
    }, () => MockClient((_) async => throw StateError('No debe conectar')));
  });

  test('reintentar conserva categoría y quitarla restaura listado', () async {
    final servicio = _Servicio();
    final cubit = PlacesCubit(servicio);
    addTearDown(cubit.close);
    await cubit.loadPlaces();
    await cubit.filterByCategory('Parque');
    expect((cubit.state as PlacesLoaded).places.single.id, 1);
    servicio.errorFiltro = true;
    await cubit.filterByCategory('Plaza');
    expect(cubit.state, isA<PlacesError>());
    servicio.errorFiltro = false;
    await cubit.loadPlaces();
    expect((cubit.state as PlacesLoaded).places.single.id, 2);
    await cubit.filterByCategory('');
    expect((cubit.state as PlacesLoaded).places.length, 2);
    expect(servicio.consultas, ['', 'Parque', 'Plaza', 'Plaza', '']);
  });

  test('cambiar filtro descarta la respuesta del filtro anterior', () async {
    final pendiente = Completer<http.Response>();
    await http.runWithClient(
      () async {
        final cubit = PlacesCubit(PlaceService());
        addTearDown(cubit.close);
        final anterior = cubit.filterByCategory('Parque');
        await cubit.filterByCategory('Plaza');
        pendiente.complete(http.Response('{"data":[]}', 200));
        await anterior;
        expect(cubit.categoria, 'Plaza');
        expect((cubit.state as PlacesLoaded).places.single.categoria, 'Plaza');
      },
      () => MockClient(
        (solicitud) async =>
            solicitud.url.queryParameters['categoria'] == 'Parque'
            ? pendiente.future
            : http.Response(
                jsonEncode({
                  'data': [
                    {
                      'id': 2,
                      'nombre': 'Plaza',
                      'categoria': 'Plaza',
                      'latitud': -12.048,
                      'longitud': -77.044,
                      'demostrativo': true,
                    },
                  ],
                }),
                200,
              ),
      ),
    );
  });

  test('logout limpia categoría y resultados', () async {
    final cubit = PlacesCubit(_Servicio());
    addTearDown(cubit.close);
    await cubit.filterByCategory('Parque');
    SessionService.clear();
    expect(cubit.categoria, isEmpty);
    expect(cubit.state, isA<PlacesInitial>());
  });

  for (final terminar in ['logout', 'sesion', 'close']) {
    test('catálogo pendiente se descarta tras $terminar', () async {
      final respuesta = Completer<http.Response>();
      final solicitada = Completer<void>();
      await http.runWithClient(
        () async {
          final cubit = CategoriasCubit(PlaceService());
          addTearDown(cubit.close);
          final pendiente = cubit.loadCategories();
          await solicitada.future;
          if (terminar == 'close') {
            await cubit.close();
          } else {
            SessionService.clear();
            if (terminar == 'sesion') {
              SessionService.start(token: 'test-token', user: usuario);
            }
          }
          respuesta.complete(http.Response('{"data":["Parque"]}', 200));
          await pendiente;
          expect(cubit.state, isNot(isA<CategoriasCargadas>()));
        },
        () => MockClient((_) {
          solicitada.complete();
          return respuesta.future;
        }),
      );
    });
  }

  test(
    'cargas invertidas de categorías conservan solo la más reciente',
    () async {
      final anterior = Completer<http.Response>();
      var llamadas = 0;
      await http.runWithClient(
        () async {
          final cubit = CategoriasCubit(PlaceService());
          addTearDown(cubit.close);
          final pendiente = cubit.loadCategories();
          await cubit.loadCategories();
          anterior.complete(http.Response('{"data":["Parque"]}', 200));
          await pendiente;
          expect((cubit.state as CategoriasCargadas).categorias, ['Plaza']);
        },
        () => MockClient(
          (_) => llamadas++ == 0
              ? anterior.future
              : Future.value(http.Response('{"data":["Plaza"]}', 200)),
        ),
      );
    },
  );

  Future<void> montar(
    WidgetTester tester,
    _Servicio servicio, {
    Size size = const Size(390, 844),
    double escala = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: MapPage(service: servicio, tileProvider: _Teselas()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> elegir(WidgetTester tester, String categoria) async {
    await tester.tap(find.byTooltip('Filtrar por categoría'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(categoria));
    await tester.pumpAndSettle();
  }

  int marcadores(WidgetTester tester) =>
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length;

  testWidgets('seleccionar, cambiar y quitar categoría actualiza marcadores', (
    tester,
  ) async {
    final servicio = _Servicio();
    await montar(tester, servicio);
    expect(marcadores(tester), 2);
    await elegir(tester, 'Parque');
    expect(marcadores(tester), 1);
    expect(find.byKey(const ValueKey('select-place-1')), findsOneWidget);
    await elegir(tester, 'Plaza');
    expect(find.byKey(const ValueKey('select-place-1')), findsNothing);
    expect(find.byKey(const ValueKey('select-place-2')), findsOneWidget);
    await tester.tap(find.text('Quitar filtro'));
    await tester.pumpAndSettle();
    expect(marcadores(tester), 2);
    expect(find.text('Quitar filtro'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('categoría sin coincidencias informa y permite quitar filtro', (
    tester,
  ) async {
    final servicio = _Servicio()..vacio = true;
    await montar(tester, servicio);
    await elegir(tester, 'Parque');
    expect(
      find.text('No hay lugares disponibles para esta categoría.'),
      findsOneWidget,
    );
    expect(find.byType(MarkerLayer), findsNothing);
    await tester.tap(find.text('Quitar filtro'));
    await tester.pumpAndSettle();
    expect(marcadores(tester), 2);
  });

  testWidgets('error del filtro conserva selección y reintento funciona', (
    tester,
  ) async {
    final servicio = _Servicio()..errorFiltro = true;
    await montar(tester, servicio);
    await elegir(tester, 'Parque');
    expect(find.text(PlaceService.loadError), findsOneWidget);
    expect(find.text('Categoría: Parque'), findsOneWidget);
    servicio.errorFiltro = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(marcadores(tester), 1);
    expect(servicio.consultas.last, 'Parque');
  });

  testWidgets('error del catálogo permite reintentar sin perder mapa', (
    tester,
  ) async {
    final servicio = _Servicio()..errorCategorias = true;
    await montar(tester, servicio);
    await tester.tap(find.byTooltip('Filtrar por categoría'));
    await tester.pumpAndSettle();
    expect(find.text(PlaceService.categoriesError), findsOneWidget);
    servicio.errorCategorias = false;
    await tester.tap(find.text('Reintentar categorías'));
    await tester.pumpAndSettle();
    expect(find.text('Parque'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar categorías'));
    await tester.pumpAndSettle();
    expect(marcadores(tester), 2);
  });

  testWidgets('catálogo vacío no fabrica opciones', (tester) async {
    await montar(tester, _Servicio()..categorias = []);
    await tester.tap(find.byTooltip('Filtrar por categoría'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay categorías disponibles.'), findsOneWidget);
    expect(find.text('Todas las categorías'), findsOneWidget);
    expect(find.text('Parque'), findsNothing);
  });

  testWidgets('selector abierto no restaura categorías después de logout', (
    tester,
  ) async {
    final pendiente = Completer<GenericResponse<List<String>>>();
    final servicio = _Servicio()..categoriasPendientes = pendiente.future;
    await montar(tester, servicio);
    await tester.tap(find.byTooltip('Filtrar por categoría'));
    await tester.pump();
    expect(find.text('Cargando categorías…'), findsOneWidget);
    SessionService.clear();
    pendiente.complete(const GenericResponse(success: true, data: ['Parque']));
    await tester.pumpAndSettle();
    expect(find.text('Parque'), findsNothing);
    expect(find.text('Todas las categorías'), findsNothing);
    expect(find.text('Inicia sesión para ver las categorías.'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar categorías'));
    await tester.pumpAndSettle();
    expect(find.byType(MarkerLayer), findsNothing);
    expect(servicio.consultas, ['']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'categoría de 80 caracteres funciona a 360 dp con texto ampliado',
    (tester) async {
      final categoria = 'Categoría ${'a' * 70}';
      expect(categoria.length, 80);
      await montar(
        tester,
        _Servicio()..categorias = [categoria],
        size: const Size(360, 800),
        escala: 2,
      );
      await tester.tap(find.byTooltip('Filtrar por categoría'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(categoria));
      await tester.tap(find.text(categoria));
      await tester.pumpAndSettle();
      expect(find.text('Quitar filtro'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    testWidgets('filtro y selector sin overflow a $size con texto ampliado', (
      tester,
    ) async {
      await montar(tester, _Servicio(), size: size, escala: 2);
      await elegir(tester, 'Parque');
      expect(find.text('Categoría: Parque'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await elegir(tester, 'Todas las categorías');
      expect(marcadores(tester), 2);
      expect(tester.takeException(), isNull);
    });
  }
}
