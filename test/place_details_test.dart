import 'dart:async';
import 'dart:convert';
import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/cubits/places/place_detail_cubit.dart';
import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/places/place_detail_page.dart';
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
  Completer<GenericResponse<PlaceModel>>? pendiente;
  @override
  Future<GenericResponse<List<PlaceModel>>> getPlaces() async =>
      GenericResponse(success: true, data: [_lugar]);
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

  test('detalle usa ID negativo, dirección y referencia del API', () async {
    await http.runWithClient(
      () async {
        final respuesta = await PlaceService().getPlace(-103);
        expect(respuesta.success, isTrue);
        expect(respuesta.data!.direccion, _json['direccion']);
        expect(respuesta.data!.referencia, _json['referencia']);
      },
      () => MockClient((request) async {
        expect(request.url.path, '/api/places/-103');
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode({'data': _json}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  });
  test('dirección null es válida y dirección malformada se rechaza', () {
    expect(
      PlaceModel.fromJson({..._json, 'direccion': null}).direccion,
      isNull,
    );
    for (final valor in [12, '', '   ']) {
      expect(
        () => PlaceModel.fromJson({..._json, 'direccion': valor}),
        throwsFormatException,
      );
    }
  });
  test('sin sesión ni ID inválido hacen petición', () async {
    var llamadas = 0;
    await http.runWithClient(
      () async {
        expect((await PlaceService().getPlace(0)).success, isFalse);
        expect((await PlaceService().getPlace(2147483648)).success, isFalse);
        SessionService.clear();
        expect((await PlaceService().getPlace(-103)).success, isFalse);
        expect(llamadas, 0);
      },
      () => MockClient((_) async {
        llamadas++;
        throw StateError('No debe consultar');
      }),
    );
  });
  for (final caso in [
    (401, 'internal', 'Tu sesión no es válida. Vuelve a iniciar sesión.'),
    (404, 'internal', 'El lugar no está disponible.'),
    (503, 'internal', PlaceService.detailError),
    (200, '{}', PlaceService.detailError),
    (200, 'not-json', PlaceService.detailError),
    (
      200,
      jsonEncode({
        'data': {..._json, 'id': 99},
      }),
      PlaceService.detailError,
    ),
  ]) {
    test('detalle ${caso.$1}/${caso.$2} muestra mensaje público', () async {
      await http.runWithClient(() async {
        final respuesta = await PlaceService().getPlace(-103);
        expect(respuesta.success, isFalse);
        expect(respuesta.data, isNull);
        expect(respuesta.message, caso.$3);
      }, () => MockClient((_) async => http.Response(caso.$2, caso.$1)));
    });
  }
  for (final detalle in [true]) {
    for (final reemplazar in [false, true]) {
      test(
        '${detalle ? 'detalle' : 'búsqueda'} descarta respuesta tras cambio de sesión $reemplazar',
        () async {
          final enviada = Completer<void>(),
              respuesta = Completer<http.Response>();
          await http.runWithClient(
            () async {
              final pendiente = PlaceService().getPlace(-103);
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
  for (final cerrar in [false, true]) {
    test(
      'cubit detalle borra datos y descarta respuesta tras ${cerrar ? 'dispose' : 'logout'}',
      () async {
        final servicio = _Servicio()..pendiente = Completer();
        final cubit = PlaceDetailCubit(servicio, -103);
        addTearDown(cubit.close);
        final pendiente = cubit.loadPlace();
        expect(cubit.state, isA<PlaceDetailLoading>());
        SessionService.clear();
        if (cerrar) await cubit.close();
        servicio.pendiente!.complete(
          GenericResponse(success: true, data: _lugar),
        );
        await pendiente;
        expect(cubit.state, isNot(isA<PlaceDetailLoaded>()));
      },
    );
  }

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
    'detalle muestra nombre dirección categoría y aviso demostrativo',
    (tester) async {
      await montar(tester, PlaceDetailPage(id: -103, service: _Servicio()));
      for (final texto in [
        'Nombre',
        'Dirección',
        'Categoría',
        _lugar.nombre,
        _lugar.direccion!,
        _lugar.categoria,
      ]) {
        expect(find.text(texto), findsOneWidget);
      }
      expect(
        find.textContaining('Datos ilustrativos, no verificados'),
        findsOneWidget,
      );
      SessionService.clear();
      await tester.pumpAndSettle();
      expect(find.text(_lugar.nombre), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('detalle error permite reintentar y recuperar información', (
    tester,
  ) async {
    final servicio = _Servicio()..falla = true;
    await montar(tester, PlaceDetailPage(id: -103, service: servicio));
    expect(find.text(PlaceService.detailError), findsOneWidget);
    servicio.falla = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text(_lugar.nombre), findsOneWidget);
    expect(servicio.intentos, 2);
  });
  for (final ancho in [360.0, 390.0, 1440.0]) {
    for (final escala in [1.0, 2.0]) {
      testWidgets(
        'pantallas sin overflow ancho $ancho escala $escala y teclado',
        (tester) async {
          await montar(
            tester,
            PlaceDetailPage(id: -103, service: _Servicio()),
            ancho: ancho,
            escala: escala,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('router abre detalle y logout vuelve a login', (tester) async {
    final router = createAppRouter(
      initialLocation: '/places/-103',
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
    expect(find.byType(PlaceDetailPage), findsOneWidget);
    expect(find.text('Dirección'), findsOneWidget);
    SessionService.clear();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(find.text(_lugar.nombre), findsNothing);
  });
  for (final ruta in ['/places/-103']) {
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
