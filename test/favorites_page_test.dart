import 'dart:convert';

import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/favoritos/favoritos_page.dart';
import 'package:crowdradar/pages/places/place_detail_page.dart';
import 'package:crowdradar/router/app_router.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FavoritesService extends PlaceService {
  final Future<GenericResponse<List<PlaceModel>>> Function() load;

  _FavoritesService(this.load);

  @override
  Future<GenericResponse<List<PlaceModel>>> getFavorites() => load();

  @override
  Future<GenericResponse<PlaceModel>> getPlace(int id) async {
    final result = await load();
    return GenericResponse(
      success: result.success,
      data: result.data?.firstOrNull,
    );
  }
}

void main() {
  const place = PlaceModel(
    id: 1,
    nombre: 'Parque Central',
    categoria: 'Parque',
    referencia: 'Junto a la plaza principal',
    latitud: -12.0464,
    longitud: -77.0428,
    demostrativo: false,
    esFavorito: true,
  );

  setUp(() {
    SessionService.clear();
    SessionService.start(token: 'favorites-test', user: const UserModel(id: 1));
  });
  tearDown(SessionService.clear);

  for (final width in [360.0, 390.0, 1440.0]) {
    testWidgets('favoritos y detalle a ancho $width con texto 2x', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _FavoritesService(
        () async => const GenericResponse(success: true, data: [place]),
      );
      Widget app(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: child,
      );
      await tester.pumpWidget(app(FavoritosPage(service: service)));
      await tester.pumpAndSettle();
      expect(find.text(place.nombre), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        app(PlaceDetailPage(id: place.id, service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('En tus favoritos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  Future<void> mount(WidgetTester tester, PlaceService service) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: FavoritosPage(service: service),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra los lugares guardados', (tester) async {
    await mount(
      tester,
      _FavoritesService(
        () async => const GenericResponse(success: true, data: [place]),
      ),
    );
    expect(find.text('Parque Central'), findsOneWidget);
    expect(find.text('Parque'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('abre la información del favorito seleccionado', (tester) async {
    final router = createAppRouter(initialLocation: '/favoritos');
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('favorite-place-1')));
        await tester.pumpAndSettle();

        expect(find.byType(PlaceDetailPage), findsOneWidget);
        expect(find.text('Parque Central'), findsOneWidget);
        expect(find.text('Categoría'), findsOneWidget);
        expect(find.text('Referencia'), findsOneWidget);
        expect(find.text('Junto a la plaza principal'), findsOneWidget);
        expect(find.text('Coordenadas'), findsOneWidget);
        expect(find.text('-12.0464, -77.0428'), findsOneWidget);
        expect(find.text('En tus favoritos'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.path,
          isIn(['/api/places/favorites', '/api/places/1']),
        );
        return http.Response(
          jsonEncode({
            'data': request.url.path == '/api/places/1'
                ? {
                    'id': place.id,
                    'nombre': place.nombre,
                    'categoria': place.categoria,
                    'referencia': place.referencia,
                    'latitud': place.latitud,
                    'longitud': place.longitud,
                    'demostrativo': place.demostrativo,
                    'esFavorito': place.esFavorito,
                  }
                : [
                    {
                      'id': place.id,
                      'nombre': place.nombre,
                      'categoria': place.categoria,
                      'referencia': place.referencia,
                      'latitud': place.latitud,
                      'longitud': place.longitud,
                      'demostrativo': place.demostrativo,
                      'esFavorito': place.esFavorito,
                    },
                  ],
          }),
          200,
        );
      }),
    );
  });

  testWidgets('muestra el estado vacío cuando no hay favoritos', (
    tester,
  ) async {
    await mount(
      tester,
      _FavoritesService(
        () async => const GenericResponse(success: true, data: []),
      ),
    );
    expect(find.text('Sin favoritos todavía'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite reintentar si falla la carga de favoritos', (
    tester,
  ) async {
    var calls = 0;
    await mount(
      tester,
      _FavoritesService(
        () async => calls++ == 0
            ? const GenericResponse(
                success: false,
                message: PlaceService.loadError,
              )
            : const GenericResponse(success: true, data: [place]),
      ),
    );
    expect(find.text(PlaceService.loadError), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Parque Central'), findsOneWidget);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });
}
