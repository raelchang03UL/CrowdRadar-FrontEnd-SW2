import 'package:crowdradar/components/place_map_controls.dart';
import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/cubits/places/places_cubit.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/saturation_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/map/map_page.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/saturation_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const places = [
  PlaceModel(
    id: 1,
    nombre: 'Mismo nombre',
    categoria: 'Parque',
    latitud: -12,
    longitud: -77,
    demostrativo: true,
  ),
  PlaceModel(
    id: 2,
    nombre: 'Mismo nombre',
    categoria: 'Plaza',
    latitud: -12.003,
    longitud: -77.003,
    demostrativo: true,
  ),
];

class _Places extends PlaceService {
  final queries = <(String, String, SaturationLevel?)>[];
  List<PlaceModel> result = places;
  @override
  Future<GenericResponse<List<PlaceModel>>> getPlaces() async =>
      GenericResponse(success: true, data: result);
  @override
  Future<GenericResponse<List<PlaceModel>>> searchPlaces(String query) async {
    queries.add((query, '', null));
    return getPlaces();
  }

  @override
  Future<GenericResponse<List<PlaceModel>>> queryPlaces({
    String nombre = '',
    String categoria = '',
    SaturationLevel? nivel,
  }) async {
    queries.add((nombre, categoria, nivel));
    return getPlaces();
  }

  @override
  Future<GenericResponse<List<PlaceModel>>> filterPlacesByCategory(
    String category,
  ) async => getPlaces();
}

class _Saturation extends SaturationService {
  @override
  Future<GenericResponse<SaturationModel>> getSaturation(int id) async =>
      GenericResponse(
        success: true,
        data: SaturationModel.fromJson({
          'placeId': id,
          'level': null,
          'reason': 'INSUFFICIENT_REPORTS',
          'reportCount': 0,
          'minimumReports': 3,
          'windowMinutes': 30,
          'evaluatedAt': '2026-10-19T12:00:00Z',
          'updatedAt': null,
        }),
      );
}

class _Tiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

void main() {
  setUp(
    () => SessionService.start(token: 'QA-UX', user: const UserModel(id: 1)),
  );
  tearDown(SessionService.clear);
  Future<GoRouter> open(
    WidgetTester tester,
    _Places service, {
    Size size = const Size(1440, 900),
    double scale = 1,
    double inset = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/map',
      routes: [
        GoRoute(
          path: '/map',
          builder: (_, _) => MapPage(
            service: service,
            tileProvider: _Tiles(),
            saturationService: _Saturation(),
          ),
        ),
        GoRoute(
          path: '/places/:id',
          builder: (_, s) =>
              Scaffold(body: Text('Detalle ID ${s.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/places/:id/history',
          builder: (_, s) =>
              Scaffold(body: Text('Historia ID ${s.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/profile/reports',
          builder: (_, _) =>
              const Scaffold(body: Text('Historial personal QA')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: inset),
          ),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'campo + Enter y botón usan nombre/categoría/nivel AND; limpiar no borra filtros',
    (tester) async {
      final service = _Places();
      await open(tester, service);
      final cubit = tester
          .element(find.byType(PlaceMapControls))
          .read<PlacesCubit>();
      await cubit.filterByCategory('Parque');
      await cubit.filtrarPorSaturacion(SaturationLevel.tranquilo);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('map-search')),
        '  Mismo  ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(service.queries.last, (
        'Mismo',
        'Parque',
        SaturationLevel.tranquilo,
      ));
      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();
      expect(service.queries.last, (
        'Mismo',
        'Parque',
        SaturationLevel.tranquilo,
      ));
      await tester.tap(find.byTooltip('Limpiar búsqueda'));
      await tester.pumpAndSettle();
      expect(service.queries.last, ('', 'Parque', SaturationLevel.tranquilo));
      expect(find.text('Categoría: Parque'), findsOneWidget);
      expect(find.text('Saturación: Tranquilo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'homónimos: catálogo selecciona ID 2 y detalle/historial no toman ID 1',
    (tester) async {
      final router = await open(tester, _Places());
      await tester.tap(find.byKey(const ValueKey('catalog-place-2')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('catalog-place-2')))
            .selected,
        true,
      );
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('catalog-place-1')))
            .selected,
        false,
      );
      final camera = MapCamera.of(tester.element(find.byType(MarkerLayer)));
      expect(camera.center.latitude, closeTo(places[1].latitud, 0.00001));
      expect(camera.center.longitude, closeTo(places[1].longitud, 0.00001));
      await tester.ensureVisible(find.text('Ver detalles'));
      await tester.tap(find.text('Ver detalles'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle ID 2'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Historial del lugar'));
      await tester.tap(find.text('Historial del lugar'));
      await tester.pumpAndSettle();
      expect(find.text('Historia ID 2'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mis reportes'));
      await tester.tap(find.text('Mis reportes'));
      await tester.pumpAndSettle();
      expect(find.text('Historial personal QA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'plegar/reabrir catálogo conserva selección ID, filtros, consulta y cámara',
    (tester) async {
      final service = _Places();
      await open(tester, service);
      final cubit = tester
          .element(find.byType(PlaceMapControls))
          .read<PlacesCubit>();
      await cubit.filterByCategory('Parque');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('map-search')), 'Mismo');
      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('catalog-place-2')));
      await tester.pumpAndSettle();
      final initialCenter = MapCamera.of(
        tester.element(find.byType(MarkerLayer)),
      ).center;
      await tester.dragFrom(
        tester.getTopLeft(find.byType(FlutterMap)) + const Offset(70, 70),
        const Offset(90, 50),
      );
      await tester.pumpAndSettle();
      final mapState = tester.state(find.byType(FlutterMap));
      final camera = MapCamera.of(tester.element(find.byType(MarkerLayer)));
      expect(camera.center, isNot(initialCenter));
      final width = tester.getSize(find.byType(FlutterMap)).width;
      final queries = service.queries.length;
      await tester.tap(find.text('Ocultar catálogo'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('catalog-place-2')), findsNothing);
      expect(tester.state(find.byType(FlutterMap)), same(mapState));
      expect(tester.getSize(find.byType(FlutterMap)).width, greaterThan(width));
      expect(
        MapCamera.of(tester.element(find.byType(MarkerLayer))).center,
        camera.center,
      );
      expect(
        MapCamera.of(tester.element(find.byType(MarkerLayer))).zoom,
        camera.zoom,
      );
      expect(find.text('Reportar saturación'), findsOneWidget);
      expect(find.byKey(const ValueKey('add-report')), findsNothing);
      expect(cubit.categoria, 'Parque');
      expect(cubit.consulta, 'Mismo');
      expect(service.queries.length, queries);
      await tester.tap(find.text('Mostrar catálogo'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('catalog-place-2')))
            .selected,
        true,
      );
      expect(
        MapCamera.of(tester.element(find.byType(MarkerLayer))).center,
        camera.center,
      );
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.text('Ver lista'), findsOneWidget);
      expect(find.text('Reportar saturación'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('contador de un lugar usa singular sin cambiar resultados', (
    tester,
  ) async {
    await open(tester, _Places()..result = [places.first]);
    expect(find.text('1 lugar disponible'), findsOneWidget);
    expect(find.text('1 lugares disponibles'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'filtro que excluye seleccionado limpia ficha y catálogo; sin recentrar al escribir',
    (tester) async {
      final service = _Places();
      await open(tester, service);
      await tester.tap(find.byKey(const ValueKey('catalog-place-1')));
      await tester.pumpAndSettle();
      await tester.dragFrom(
        tester.getTopLeft(find.byType(FlutterMap)) + const Offset(70, 70),
        const Offset(90, 60),
      );
      await tester.pumpAndSettle();
      final center = MapCamera.of(
        tester.element(find.byType(MarkerLayer)),
      ).center;
      await tester.enterText(find.byKey(const ValueKey('map-search')), 'otro');
      await tester.pumpAndSettle();
      expect(
        MapCamera.of(tester.element(find.byType(MarkerLayer))).center,
        center,
      );
      service.result = [places[1]];
      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Cerrar identificación'), findsNothing);
      expect(find.byKey(const ValueKey('catalog-place-1')), findsNothing);
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('catalog-place-2')))
            .selected,
        false,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(360, 640),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('controles/búsqueda y foco con teclado $size texto$scale', (
        tester,
      ) async {
        final service = _Places();
        await open(tester, service, size: size, scale: scale, inset: 300);
        await tester.ensureVisible(find.byKey(const ValueKey('map-search')));
        await tester.tap(find.byKey(const ValueKey('map-search')));
        await tester.enterText(
          find.byKey(const ValueKey('map-search')),
          'Mismo',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(service.queries.last.$1, 'Mismo');
        await tester.ensureVisible(find.text('Buscar'));
        // Recorrido de foco real de widgets, sin invocar directamente onPressed.
        await tester.tap(find.byKey(const ValueKey('map-search')));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        expect(FocusManager.instance.primaryFocus, isNotNull);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
