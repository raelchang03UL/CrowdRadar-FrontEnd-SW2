import 'dart:async';
import 'package:crowdradar/configs/generic_response.dart';
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

class _Places extends PlaceService {
  @override
  Future<GenericResponse<List<PlaceModel>>> getPlaces() async =>
      const GenericResponse(
        success: true,
        data: [
          PlaceModel(
            id: -1,
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
        ],
      );
}

class _Saturation extends SaturationService {
  final Future<GenericResponse<SaturationModel>> Function(int) load;
  _Saturation(this.load);
  @override
  Future<GenericResponse<SaturationModel>> getSaturation(int placeId) =>
      load(placeId);
}

class _Tiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

SaturationModel estimate({
  int id = -1,
  String? level = 'TRANQUILO',
  String? reason,
  int count = 3,
}) => SaturationModel.fromJson({
  'placeId': id,
  'level': level,
  'reason': reason,
  'reportCount': count,
  'minimumReports': 3,
  'windowMinutes': 30,
  'evaluatedAt': '2026-10-11T17:25:00.000Z',
  'updatedAt': count == 0 ? null : '2026-10-11T17:20:00.000Z',
});

void main() {
  setUp(() {
    SessionService.clear();
    SessionService.start(token: 'test-token', user: const UserModel(id: 1));
  });
  tearDown(SessionService.clear);

  Future<void> mount(
    WidgetTester tester,
    SaturationService service, {
    Size size = const Size(390, 844),
    double textScale = 1,
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
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: MapPage(
          service: _Places(),
          saturationService: service,
          tileProvider: _Tiles(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-place--1')));
    await tester.pump();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  for (final level in ['TRANQUILO', 'MODERADO', 'SATURADO']) {
    testWidgets('selección muestra $level con etiqueta, no solo color', (
      tester,
    ) async {
      await mount(
        tester,
        _Saturation(
          (_) async =>
              GenericResponse(success: true, data: estimate(level: level)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lugar A'), findsOneWidget);
      expect(find.text('Parque · Demostrativo'), findsOneWidget);
      expect(
        find.text(level[0] + level.substring(1).toLowerCase()),
        findsOneWidget,
      );
      expect(
        find.text('Estimación ciudadana · Reportes de los últimos 30 minutos.'),
        findsNothing,
      );
      await reveal(tester, find.text('Más información'));
      await tester.tap(find.text('Más información'));
      await tester.pumpAndSettle();
      expect(
        find.text('Estimación ciudadana · Reportes de los últimos 30 minutos.'),
        findsOneWidget,
      );
      expect(find.text('3 personas distintas · Mínimo: 3.'), findsOneWidget);
      expect(
        find.text(
          'No representa un aforo exacto. Se consulta al seleccionar o actualizar.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Datos demostrativos · Sin monitoreo en tiempo real'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final count in [0, 2, 3]) {
    testWidgets(
      'sin información por ${count < 3 ? 'pocos reportes' : 'empate'} count=$count',
      (tester) async {
        await mount(
          tester,
          _Saturation(
            (_) async => GenericResponse(
              success: true,
              data: estimate(
                level: null,
                reason: count < 3 ? 'INSUFFICIENT_REPORTS' : 'TIE',
                count: count,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sin información suficiente'), findsOneWidget);
        await reveal(tester, find.text('Más información'));
        await tester.tap(find.text('Más información'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            count < 3
                ? 'Se necesitan al menos 3 personas distintas con reportes vigentes.'
                : 'Los niveles más votados están empatados.',
          ),
          findsOneWidget,
        );
        expect(find.text('Tranquilo'), findsNothing);
        expect(find.text('Moderado'), findsNothing);
        expect(find.text('Saturado'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('carga y error conservan identificación, reintento actualiza', (
    tester,
  ) async {
    final response = Completer<GenericResponse<SaturationModel>>();
    var calls = 0;
    await mount(
      tester,
      _Saturation(
        (id) => calls++ == 0
            ? response.future
            : Future.value(
                GenericResponse(success: true, data: estimate(id: id)),
              ),
      ),
    );
    expect(find.text('Consultando saturación…'), findsOneWidget);
    expect(find.text('Lugar A'), findsOneWidget);
    response.complete(
      const GenericResponse(
        success: false,
        message: SaturationService.loadError,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(SaturationService.loadError), findsOneWidget);
    await reveal(tester, find.text('Reintentar saturación'));
    await tester.tap(find.text('Reintentar saturación'));
    await tester.pumpAndSettle();
    expect(find.text('Tranquilo'), findsOneWidget);
    expect(calls, 2);
    await reveal(tester, find.byTooltip('Actualizar saturación'));
    await tester.tap(find.byTooltip('Actualizar saturación'));
    await tester.pumpAndSettle();
    expect(calls, 3);
    expect(tester.takeException(), isNull);
  });
  testWidgets('cerrar selección descarta su respuesta tardía', (tester) async {
    final response = Completer<GenericResponse<SaturationModel>>();
    await mount(tester, _Saturation((_) => response.future));
    await tester.tap(find.byTooltip('Cerrar identificación'));
    await tester.pump();
    response.complete(GenericResponse(success: true, data: estimate()));
    await tester.pumpAndSettle();
    expect(find.text('Lugar A'), findsNothing);
    expect(find.text('Tranquilo'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('nuevo marcador no recibe el nivel tardío del marcador anterior', (
    tester,
  ) async {
    final first = Completer<GenericResponse<SaturationModel>>();
    await mount(
      tester,
      _Saturation(
        (id) => id == -1
            ? first.future
            : Future.value(
                GenericResponse(
                  success: true,
                  data: estimate(id: id, level: 'SATURADO'),
                ),
              ),
      ),
    );
    // Ejecutar la acción de selección conserva el contrato del botón del marcador.
    tester
        .widget<IconButton>(find.byKey(const ValueKey('select-place-2')))
        .onPressed!();
    await tester.pumpAndSettle();
    first.complete(GenericResponse(success: true, data: estimate()));
    await tester.pumpAndSettle();
    expect(find.text('Lugar B'), findsOneWidget);
    expect(find.text('Saturado'), findsOneWidget);
    expect(find.text('Tranquilo'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'logout retira identificación y nivel incluso con solicitud pendiente',
    (tester) async {
      final response = Completer<GenericResponse<SaturationModel>>();
      await mount(tester, _Saturation((_) => response.future));
      SessionService.clear();
      await tester.pump();
      response.complete(GenericResponse(success: true, data: estimate()));
      await tester.pumpAndSettle();
      expect(find.text('Lugar A'), findsNothing);
      expect(find.text('Tranquilo'), findsNothing);
      expect(find.byType(MarkerLayer), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    for (final error in [false, true]) {
      testWidgets(
        'estado ${error ? 'error' : 'sin información'} accesible $size texto=2x',
        (tester) async {
          await mount(
            tester,
            _Saturation(
              (_) async => error
                  ? const GenericResponse(
                      success: false,
                      message: SaturationService.loadError,
                    )
                  : GenericResponse(
                      success: true,
                      data: estimate(
                        level: null,
                        reason: 'INSUFFICIENT_REPORTS',
                        count: 0,
                      ),
                    ),
            ),
            size: size,
            textScale: 2,
          );
          await tester.pumpAndSettle();
          final action = error
              ? find.text('Reintentar saturación')
              : find.byTooltip('Actualizar saturación');
          await reveal(tester, action);
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await reveal(tester, find.byTooltip('Cerrar identificación'));
          await tester.tap(find.byTooltip('Cerrar identificación'));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('saturation-selection-scroll')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
    for (final scale in [1.0, 2.0]) {
      testWidgets('selección accesible sin overflow $size texto=$scale', (
        tester,
      ) async {
        await mount(
          tester,
          _Saturation(
            (_) async => GenericResponse(success: true, data: estimate()),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final scroll = find.byKey(
          const ValueKey('saturation-selection-scroll'),
        );
        final bounds = tester.getRect(scroll);
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.bottom, lessThan(size.height));
        await reveal(tester, find.byTooltip('Actualizar saturación'));
        await tester.tap(find.byTooltip('Actualizar saturación'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await reveal(tester, find.byTooltip('Cerrar identificación'));
        await tester.tap(find.byTooltip('Cerrar identificación'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('saturation-selection-scroll')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
