import 'dart:async';
import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/map/map_page.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/services/saturation_service.dart';
import 'package:crowdradar/models/saturation_model.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:crowdradar/pages/places/place_detail_page.dart';
import 'package:crowdradar/pages/places/place_search_page.dart';
import 'package:crowdradar/components/place_catalog.dart';
import 'package:crowdradar/components/report_place_sheet.dart';

class _Service extends PlaceService {
  final Future<GenericResponse<List<PlaceModel>>> Function() load;
  _Service(this.load);
  @override
  Future<GenericResponse<List<PlaceModel>>> getPlaces() => load();
  @override
  Future<GenericResponse<PlaceModel>> getPlace(int id) async => GenericResponse(
    success: true,
    data: (await load()).data!.firstWhere((place) => place.id == id),
  );
}

class _Saturation extends SaturationService {
  @override
  Future<GenericResponse<SaturationModel>> getSaturation(int placeId) async =>
      GenericResponse(
        success: true,
        data: SaturationModel.fromJson({
          'placeId': placeId,
          'level': null,
          'reason': 'INSUFFICIENT_REPORTS',
          'reportCount': 0,
          'minimumReports': 3,
          'windowMinutes': 30,
          'evaluatedAt': '2026-10-11T17:25:00.000Z',
          'updatedAt': null,
        }),
      );
}

class _FavoriteService extends _Service {
  final saved = Completer<GenericResponse<bool>>();
  int calls = 0;

  _FavoriteService(super.load);

  @override
  Future<GenericResponse<bool>> addFavorite(int id) {
    calls++;
    return saved.future;
  }
}

// Solo sustituye la red de teselas: se renderizan FlutterMap y MarkerLayer reales.
class _Tiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

void main() {
  const places = [
    PlaceModel(
      id: 1,
      nombre: 'Lugar A',
      categoria: 'Parque',
      latitud: -12.0464,
      longitud: -77.0428,
      demostrativo: true,
    ),
    PlaceModel(
      id: 2,
      nombre: 'Lugar B',
      categoria: 'Plaza',
      latitud: -12.048,
      longitud: -77.044,
      demostrativo: true,
    ),
  ];
  setUp(() {
    SessionService.clear();
    SessionService.start(token: 'test-token', user: const UserModel(id: 1));
  });
  tearDown(SessionService.clear);

  testWidgets('favorito A pendiente no cambia estado de selección B', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _FavoriteService(
      () async => const GenericResponse(success: true, data: places),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MapPage(
          service: service,
          tileProvider: _Tiles(),
          saturationService: _Saturation(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-place-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('favorite-place-1')));
    await tester.tap(find.byKey(const ValueKey('favorite-place-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('catalog-place-2')));
    await tester.pumpAndSettle();
    service.saved.complete(
      const GenericResponse(
        success: true,
        data: true,
        message: 'Favorito guardado',
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('favorite-place-2'));
    expect(
      find.descendant(of: button, matching: find.text('Agregar a favoritos')),
      findsOneWidget,
    );
    expect(service.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mapa abre detalles desde marcador y búsqueda desde la barra', (
    tester,
  ) async {
    final service = _Service(
      () async => const GenericResponse(success: true, data: places),
    );
    final router = GoRouter(
      initialLocation: '/map',
      routes: [
        GoRoute(
          path: '/map',
          builder: (_, _) => MapPage(service: service, tileProvider: _Tiles()),
        ),
        GoRoute(
          path: '/places/search',
          builder: (_, _) => PlaceSearchPage(service: service),
        ),
        GoRoute(
          path: '/places/:id',
          builder: (_, state) => PlaceDetailPage(
            id: int.parse(state.pathParameters['id']!),
            service: service,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-place-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver detalles'));
    await tester.tap(find.text('Ver detalles'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceDetailPage), findsOneWidget);
    expect(find.text('Dirección no registrada'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.byType(MapPage), findsOneWidget);
    await tester.tap(find.byTooltip('Más opciones de lugares'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buscar en lista'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceSearchPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final ancho in [360.0, 390.0, 1440.0]) {
    testWidgets('mapa y selección sin overflow a ancho $ancho y texto 2x', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: MapPage(
            service: _Service(
              () async => const GenericResponse(success: true, data: places),
            ),
            tileProvider: _Tiles(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('select-place-1')));
      await tester.pumpAndSettle();
      expect(find.text('Ver detalles'), findsOneWidget);
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
        home: MapPage(
          service: service,
          tileProvider: _Tiles(),
          saturationService: _Saturation(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'agregar reporte es visible sin acertar un marcador y pide lugar',
    (tester) async {
      await mount(
        tester,
        _Service(
          () async => const GenericResponse(success: true, data: places),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('add-report')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('add-report')));
      await tester.pumpAndSettle();
      expect(find.text('¿Dónde quieres reportar?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pick-place-2')));
      await tester.pumpAndSettle();
      expect(find.byType(ReportPlaceSheet), findsOneWidget);
      expect(
        tester.widget<ReportPlaceSheet>(find.byType(ReportPlaceSheet)).place.id,
        2,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selector permite buscar y cancelar sin crear reportes', (
    tester,
  ) async {
    await mount(
      tester,
      _Service(() async => const GenericResponse(success: true, data: places)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver lista'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(PlacePickerSheet),
        matching: find.byType(TextField),
      ),
      'Lugar B',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pick-place-1')), findsNothing);
    expect(find.byKey(const ValueKey('pick-place-2')), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(PlacePickerSheet),
        matching: find.byType(TextField),
      ),
      'Sin coincidencia',
    );
    await tester.pumpAndSettle();
    expect(find.text('No hay coincidencias en este catálogo.'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar selector de lugares'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportPlaceSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lugares con coordenadas iguales muestran contador y selector', (
    tester,
  ) async {
    final samePoint = [
      places.first,
      PlaceModel(
        id: 3,
        nombre: 'Lugar C',
        categoria: 'Plaza',
        latitud: places.first.latitud,
        longitud: places.first.longitud,
        demostrativo: true,
      ),
    ];
    await mount(
      tester,
      _Service(() async => GenericResponse(success: true, data: samePoint)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
      1,
    );
    expect(find.byTooltip('2 lugares en este punto'), findsOneWidget);
    await tester.tap(find.byTooltip('2 lugares en este punto'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pick-place-3')));
    await tester.pumpAndSettle();
    expect(find.byType(PlacePickerSheet), findsNothing);
    expect(find.text('Lugar C'), findsOneWidget);
    expect(find.text('Reportar saturación'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logout mientras se elige lugar impide abrir un reporte tardío', (
    tester,
  ) async {
    await mount(
      tester,
      _Service(() async => const GenericResponse(success: true, data: places)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-report')));
    await tester.pumpAndSettle();
    SessionService.clear();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pick-place-1')));
    await tester.pumpAndSettle();
    expect(find.byType(ReportPlaceSheet), findsNothing);
    expect(find.byType(MarkerLayer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra carga mientras espera al backend', (tester) async {
    final response = Completer<GenericResponse<List<PlaceModel>>>();
    await mount(tester, _Service(() => response.future));
    expect(find.text('Cargando lugares…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    response.complete(const GenericResponse(success: true, data: []));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('lista vacía no fabrica marcadores y permite actualizar', (
    tester,
  ) async {
    await mount(
      tester,
      _Service(() async => const GenericResponse(success: true, data: [])),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay lugares disponibles.'), findsOneWidget);
    expect(find.byType(MarkerLayer), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('doble activación de Agregar reporte abre un solo selector', (
    tester,
  ) async {
    await mount(
      tester,
      _Service(() async => const GenericResponse(success: true, data: places)),
    );
    await tester.pumpAndSettle();
    final action = tester
        .widget<FilledButton>(find.byKey(const ValueKey('add-report')))
        .onPressed!;
    action();
    action();
    await tester.pumpAndSettle();
    expect(find.byType(PlacePickerSheet), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar selector de lugares'));
    await tester.pumpAndSettle();
    expect(find.byType(PlacePickerSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 390.0, 1440.0]) {
    testWidgets('selector usable con texto 2x y teclado a ancho $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 300),
            ),
            child: child!,
          ),
          home: const Scaffold(body: PlacePickerSheet(places: places)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Lugar B');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('pick-place-2')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pick-place-2')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'marcadores coinciden con backend y selección conserva identificación',
    (tester) async {
      await mount(
        tester,
        _Service(
          () async => const GenericResponse(success: true, data: places),
        ),
      );
      await tester.pumpAndSettle();
      final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(layer.markers.length, 2);
      for (var i = 0; i < places.length; i++) {
        expect(layer.markers[i].point.latitude, places[i].latitud);
        expect(layer.markers[i].point.longitude, places[i].longitud);
      }
      expect(
        find.text('Datos demostrativos · Sin monitoreo en tiempo real'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('select-place-1')));
      await tester.pumpAndSettle();
      expect(find.text('Lugar A'), findsOneWidget);
      expect(find.text('Parque · Demostrativo'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar identificación'));
      await tester.pumpAndSettle();
      expect(find.text('Lugar A'), findsNothing);
      final center = MapCamera.of(
        tester.element(find.byType(MarkerLayer)),
      ).center;
      await tester.drag(find.byType(FlutterMap), const Offset(80, 60));
      await tester.pumpAndSettle();
      expect(
        MapCamera.of(tester.element(find.byType(MarkerLayer))).center,
        isNot(center),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('error comprensible y reintento recupera marcadores', (
    tester,
  ) async {
    var calls = 0;
    await mount(
      tester,
      _Service(
        () async => calls++ == 0
            ? const GenericResponse(
                success: false,
                message: PlaceService.loadError,
              )
            : const GenericResponse(success: true, data: places),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(PlaceService.loadError), findsOneWidget);
    expect(find.byType(MarkerLayer), findsNothing);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
      2,
    );
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cerrar sesión retira los marcadores ya cargados', (
    tester,
  ) async {
    await mount(
      tester,
      _Service(() async => const GenericResponse(success: true, data: places)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MarkerLayer), findsOneWidget);
    SessionService.clear();
    await tester.pumpAndSettle();
    expect(find.byType(MarkerLayer), findsNothing);
    expect(find.text('Inicia sesión para ver los lugares.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
