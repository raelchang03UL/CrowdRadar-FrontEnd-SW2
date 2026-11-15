import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/components/place_catalog.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/saturation_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/map/map_page.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/saturation_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

const _place = PlaceModel(
  id: 7,
  nombre: 'Parque del barrio',
  categoria: 'Parque',
  latitud: -12.0464,
  longitud: -77.0428,
  demostrativo: true,
  direccion: 'Una dirección de prueba',
);

class _Places extends PlaceService {
  int calls = 0;
  @override
  Future<GenericResponse<List<PlaceModel>>> getPlaces() async {
    calls++;
    return const GenericResponse(success: true, data: [_place]);
  }
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
          'evaluatedAt': '2026-11-03T12:00:00Z',
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
    () => SessionService.start(
      token: 'visual-layout-test',
      user: const UserModel(id: 1),
    ),
  );
  tearDown(SessionService.clear);

  Future<_Places> open(WidgetTester tester, Size size, double scale) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _Places();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: MapPage(
          service: service,
          saturationService: _Saturation(),
          tileProvider: _Tiles(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // La lista es la alternativa accesible al mapa en pantallas cortas con
    // texto ampliado; ejercitamos una selección real, sin invocar callbacks.
    await tester.ensureVisible(find.text('Ver lista'));
    await tester.tap(find.text('Ver lista'));
    await tester.pumpAndSettle();
    final place = find.byKey(const ValueKey('pick-place-7'));
    await tester.scrollUntilVisible(
      place,
      180,
      scrollable: find.descendant(
        of: find.byType(PlacePickerSheet),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(place);
    await tester.pumpAndSettle();
    return service;
  }

  testWidgets(
    'ficha móvil prioriza estado y reportar; ampliar conserva mapa y consultas',
    (tester) async {
      final service = await open(tester, const Size(390, 844), 1);
      final mapState = tester.state(find.byType(FlutterMap));
      final camera = MapCamera.of(tester.element(find.byType(MarkerLayer)));
      final card = find.byKey(const ValueKey('place-selection-card'));
      final compactHeight = tester.getSize(card).height;
      expect(
        compactHeight,
        lessThanOrEqualTo(
          tester.getSize(find.byType(FlutterMap)).height * 0.63,
        ),
      );
      expect(
        tester.getTopLeft(find.text('Sin información suficiente')).dy,
        lessThan(tester.getTopLeft(find.text('Reportar saturación')).dy),
      );
      expect(find.text('Reportar saturación').hitTestable(), findsOneWidget);
      final calls = service.calls;
      await tester.tap(find.byTooltip('Ampliar ficha'));
      await tester.pumpAndSettle();
      expect(tester.getSize(card).height, greaterThan(compactHeight));
      expect(tester.state(find.byType(FlutterMap)), same(mapState));
      expect(
        MapCamera.of(tester.element(find.byType(MarkerLayer))).center,
        camera.center,
      );
      expect(
        MapCamera.of(tester.element(find.byType(MarkerLayer))).zoom,
        camera.zoom,
      );
      expect(service.calls, calls);
      await tester.tap(find.byTooltip('Reducir ficha'));
      await tester.pumpAndSettle();
      expect(tester.getSize(card).height, compactHeight);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(360, 640), const Size(390, 844)]) {
    testWidgets(
      'ficha ampliable conserva acciones y atribución a texto 200% $size',
      (tester) async {
        await open(tester, size, 2);
        await tester.ensureVisible(find.byTooltip('Ampliar ficha'));
        await tester.tap(find.byTooltip('Ampliar ficha'));
        await tester.pumpAndSettle();
        for (final text in [
          'Reportar saturación',
          'Agregar a favoritos',
          'Ver detalles',
          'Historial del lugar',
          'Mis reportes',
          'Más información',
        ]) {
          await tester.ensureVisible(find.text(text));
          await tester.pumpAndSettle();
          expect(find.text(text).hitTestable(), findsOneWidget);
        }
        expect(
          find.textContaining('© OpenStreetMap contributors'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.byTooltip('Cerrar identificación'));
        await tester.tap(find.byTooltip('Cerrar identificación'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('place-selection-card')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
