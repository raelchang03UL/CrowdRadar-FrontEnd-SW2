import 'dart:async';
import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/map/map_page.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

class _Service extends PlaceService {
  final Future<GenericResponse<List<PlaceModel>>> Function() load;
  _Service(this.load);
  @override
  Future<GenericResponse<List<PlaceModel>>> getPlaces() => load();
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

  Future<void> mount(WidgetTester tester, PlaceService service) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MapPage(service: service, tileProvider: _Tiles()),
      ),
    );
    await tester.pump();
  }

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

  testWidgets(
    'marcadores coinciden con backend y selección solo identifica el lugar',
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
