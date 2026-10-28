import 'dart:async';
import 'dart:convert';
import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/cubits/places/places_cubit.dart';
import 'package:crowdradar/cubits/places/places_state.dart';
import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/places/place_detail_page.dart';
import 'package:crowdradar/pages/places/place_search_page.dart';
import 'package:crowdradar/router/app_router.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _json = {
  'id': -103,
  'nombre': 'Demo · Parque Central',
  'categoria': 'Parque',
  'direccion': 'Dirección ilustrativa: Av. Ejemplo 100 (no verificada)',
  'referencia': 'Ubicación demostrativa',
  'latitud': -12.0464,
  'longitud': -77.0428,
  'demostrativo': true,
};
final _lugar = PlaceModel.fromJson(_json);
const _usuario = UserModel(id: 1, nombre: 'Prueba');

class _Servicio extends PlaceService {
  int intentos = 0;
  bool falla = false;
  String ultimaConsulta = '';
  Completer<GenericResponse<PlaceModel>>? pendiente;
  @override
  Future<GenericResponse<List<PlaceModel>>> getPlaces() async =>
      GenericResponse(success: true, data: [_lugar]);
  @override
  Future<GenericResponse<List<PlaceModel>>> searchPlaces(
    String consulta,
  ) async {
    ultimaConsulta = consulta;
    intentos++;
    if (falla) {
      return const GenericResponse(
        success: false,
        message: PlaceService.loadError,
      );
    }
    return GenericResponse(
      success: true,
      data: consulta == 'inexistente'
          ? []
          : [
              _lugar,
              PlaceModel.fromJson({
                ..._json,
                'id': -102,
                'nombre': 'Otro Parque',
              }),
            ],
    );
  }

  @override
  Future<GenericResponse<PlaceModel>> getPlace(int id) async {
    intentos++;
    if (pendiente != null) return pendiente!.future;
    if (falla) {
      return const GenericResponse(
        success: false,
        message: PlaceService.detailError,
      );
    }
    return GenericResponse(success: true, data: _lugar);
  }
}

void main() {
  setUp(() {
    SessionService.clear();
    SessionService.start(token: 'test-token', user: _usuario);
  });
  tearDown(SessionService.clear);

  test(
    'búsqueda codifica nombre literalmente y obtiene todas las coincidencias',
    () async {
      await http.runWithClient(
        () async {
          final respuesta = await PlaceService().searchPlaces(
            '  Parque 50%_\\ &  ',
          );
          expect(respuesta.success, isTrue);
          expect(respuesta.data!.length, 2);
        },
        () => MockClient((request) async {
          expect(request.url.path, '/api/places');
          expect(request.url.queryParameters, {'nombre': 'Parque 50%_\\ &'});
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response(
            jsonEncode({
              'data': [
                _json,
                {..._json, 'id': -102},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
    },
  );
  test('sin sesión ni búsqueda inválida hacen petición', () async {
    var llamadas = 0;
    await http.runWithClient(
      () async {
        expect((await PlaceService().searchPlaces('x' * 161)).success, isFalse);
        SessionService.clear();
        expect((await PlaceService().searchPlaces('Parque')).success, isFalse);
        expect(llamadas, 0);
      },
      () => MockClient((_) async {
        llamadas++;
        throw StateError('No debe consultar');
      }),
    );
  });
  for (final detalle in [false]) {
    for (final reemplazar in [false, true]) {
      test(
        '${detalle ? 'detalle' : 'búsqueda'} descarta respuesta tras cambio de sesión $reemplazar',
        () async {
          final enviada = Completer<void>(),
              respuesta = Completer<http.Response>();
          await http.runWithClient(
            () async {
              final pendiente = PlaceService().searchPlaces('Parque');
              await enviada.future;
              SessionService.clear();
              if (reemplazar) {
                SessionService.start(token: 'test-token', user: _usuario);
              }
              respuesta.complete(
                http.Response(
                  jsonEncode({
                    'data': detalle ? _json : [_json],
                  }),
                  200,
                ),
              );
              final resultado = await pendiente;
              expect(resultado.success, isFalse);
              expect(resultado.data, isNull);
            },
            () => MockClient((_) {
              enviada.complete();
              return respuesta.future;
            }),
          );
        },
      );
    }
  }
  test(
    'búsqueda conserva solo consulta más reciente y borra al cerrar sesión',
    () async {
      final primera = Completer<http.Response>(), enviada = Completer<void>();
      await http.runWithClient(
        () async {
          final cubit = PlacesCubit(PlaceService());
          addTearDown(cubit.close);
          final pendiente = cubit.searchPlaces('Parque');
          await enviada.future;
          await cubit.searchPlaces('inexistente');
          primera.complete(
            http.Response(
              jsonEncode({
                'data': [_json],
              }),
              200,
            ),
          );
          await pendiente;
          expect((cubit.state as PlacesLoaded).places, isEmpty);
          expect(cubit.consulta, 'inexistente');
          SessionService.clear();
          expect(cubit.state, isA<PlacesInitial>());
          expect(cubit.consulta, isEmpty);
        },
        () => MockClient((request) {
          if (request.url.queryParameters['nombre'] == 'Parque') {
            enviada.complete();
            return primera.future;
          }
          return Future.value(http.Response('{"data":[]}', 200));
        }),
      );
    },
  );
  Future<void> montar(
    WidgetTester tester,
    Widget page, {
    double ancho = 390,
    double escala = 1,
    double teclado = 0,
  }) async {
    tester.view.physicalSize = Size(ancho, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(escala),
            viewInsets: EdgeInsets.only(bottom: teclado),
          ),
          child: child!,
        ),
        home: page,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'búsqueda completa/parcial presenta todos, vacío, limpiar y reintento',
    (tester) async {
      final servicio = _Servicio();
      await montar(tester, PlaceSearchPage(service: servicio));
      await tester.enterText(find.byType(TextField), '  Parque  ');
      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();
      expect(servicio.ultimaConsulta, 'Parque');
      expect(find.byKey(const ValueKey('result-place--103')), findsOneWidget);
      expect(find.byKey(const ValueKey('result-place--102')), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'inexistente');
      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();
      expect(
        find.text('No se encontraron lugares con ese nombre.'),
        findsOneWidget,
      );
      servicio.falla = true;
      await tester.enterText(find.byType(TextField), 'Parque');
      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();
      expect(find.text(PlaceService.loadError), findsOneWidget);
      servicio.falla = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(servicio.ultimaConsulta, 'Parque');
      await tester.tap(find.byTooltip('Limpiar búsqueda'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.text('1 resultado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final ancho in [360.0, 390.0, 1440.0]) {
    for (final escala in [1.0, 2.0]) {
      testWidgets(
        'pantallas sin overflow ancho $ancho escala $escala y teclado',
        (tester) async {
          await montar(
            tester,
            PlaceSearchPage(service: _Servicio()),
            ancho: ancho,
            escala: escala,
            teclado: 280,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('router navega búsqueda a detalle y logout vuelve a login', (
    tester,
  ) async {
    final router = createAppRouter(
      initialLocation: '/places/search',
      placeService: _Servicio(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => AuthCubit(),
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('result-place--103')));
    await tester.pumpAndSettle();
    // GoRouter no refleja los push imperativos en la URI raíz por defecto.
    // Se comprueba la pantalla visible y la navegación de regreso, no esa URI.
    expect(find.byType(PlaceDetailPage), findsOneWidget);
    expect(router.canPop(), isTrue);
    expect(find.text('Dirección'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(PlaceSearchPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('result-place--103')));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceDetailPage), findsOneWidget);
    SessionService.clear();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(find.text(_lugar.nombre), findsNothing);
  });
  for (final ruta in ['/places/search']) {
    testWidgets('ruta $ruta sin sesión redirige a login', (tester) async {
      SessionService.clear();
      final router = createAppRouter(
        initialLocation: ruta,
        placeService: _Servicio(),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        BlocProvider(
          create: (_) => AuthCubit(),
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(find.text(_lugar.nombre), findsNothing);
    });
  }
}
