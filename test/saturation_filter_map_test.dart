import 'dart:async';
import 'dart:ui' show Tristate;
import 'package:crowdradar/components/selector_saturacion.dart';
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
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

const _lugares = [
  PlaceModel(
    id: -1,
    nombre: 'Lugar tranquilo',
    categoria: 'Parque',
    latitud: -12.0464,
    longitud: -77.0428,
    demostrativo: true,
  ),
  PlaceModel(
    id: 2,
    nombre: 'Lugar moderado',
    categoria: 'Plaza',
    latitud: -12.048,
    longitud: -77.044,
    demostrativo: true,
  ),
  PlaceModel(
    id: 3,
    nombre: 'Lugar saturado',
    categoria: 'Cultura',
    latitud: -12.047,
    longitud: -77.043,
    demostrativo: true,
  ),
];

class _Servicio extends PlaceService {
  final Future<GenericResponse<List<PlaceModel>>> Function(SaturationLevel?)
  consultar;
  final solicitudes = <SaturationLevel?>[];
  _Servicio(this.consultar);
  Future<GenericResponse<List<PlaceModel>>> _consultar(SaturationLevel? nivel) {
    solicitudes.add(nivel);
    return consultar(nivel);
  }

  @override
  Future<GenericResponse<List<PlaceModel>>> getPlaces() => _consultar(null);
  @override
  Future<GenericResponse<List<PlaceModel>>> getPlacesBySaturation(
    SaturationLevel nivel,
  ) => _consultar(nivel);
}

class _Saturacion extends SaturationService {
  final Future<GenericResponse<SaturationModel>> Function(int) consultar;
  _Saturacion(this.consultar);
  @override
  Future<GenericResponse<SaturationModel>> getSaturation(int placeId) =>
      consultar(placeId);
}

class _Teselas extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

GenericResponse<List<PlaceModel>> _respuesta(SaturationLevel? nivel) =>
    GenericResponse(
      success: true,
      data: nivel == null ? _lugares : [_lugares[nivel.index]],
    );

void main() {
  setUp(() {
    SessionService.clear();
    SessionService.start(token: 'test-token', user: const UserModel(id: 1));
  });
  tearDown(SessionService.clear);

  Future<void> montar(
    WidgetTester tester,
    _Servicio servicio, {
    Size tamano = const Size(390, 844),
    double escala = 1,
    SaturationService? saturacion,
  }) async {
    tester.view.physicalSize = tamano;
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
        home: MapPage(
          service: servicio,
          tileProvider: _Teselas(),
          saturationService:
              saturacion ??
              _Saturacion(
                (_) async => const GenericResponse(
                  success: false,
                  message: SaturationService.loadError,
                ),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> elegir(WidgetTester tester, SaturationLevel? nivel) async {
    await tester.ensureVisible(find.byTooltip('Filtrar por saturación'));
    await tester.tap(find.byTooltip('Filtrar por saturación'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final opcion = find.byKey(
      ValueKey('opcion-saturacion-${nivel?.valorApi ?? 'TODOS'}'),
    );
    await tester.ensureVisible(opcion);
    await tester.pump();
    await tester.tap(opcion);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final escala in [1.0, 2.0]) {
    testWidgets(
      'selector mantiene Saturado sobre la barra Android de 48 px texto${escala}x',
      (tester) async {
        const margenSistema = 48.0;
        const tamano = Size(390, 844);
        tester.view.viewPadding = const FakeViewPadding(bottom: margenSistema);
        tester.view.padding = const FakeViewPadding(bottom: margenSistema);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
        final servicio = _Servicio((nivel) async => _respuesta(nivel));
        await montar(tester, servicio, tamano: tamano, escala: escala);
        await tester.tap(find.byTooltip('Filtrar por saturación'));
        await tester.pumpAndSettle();
        final opcion = find.byKey(const ValueKey('opcion-saturacion-SATURADO'));
        await tester.ensureVisible(opcion);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(opcion).bottom,
          lessThanOrEqualTo(tamano.height - margenSistema),
        );
        await tester.tap(opcion);
        await tester.pumpAndSettle();
        expect(servicio.solicitudes.last, SaturationLevel.saturado);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final nivel in SaturationLevel.values) {
    testWidgets('mapa filtra ${nivel.etiqueta}, actualiza y quita con Todos', (
      tester,
    ) async {
      final servicio = _Servicio((valor) async => _respuesta(valor));
      await montar(tester, servicio);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
        3,
      );
      await elegir(tester, nivel);
      await tester.pumpAndSettle();
      final marcadores = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers;
      expect(
        marcadores.single.key,
        ValueKey('marker-${_lugares[nivel.index].id}'),
      );
      expect(find.text('Saturación: ${nivel.etiqueta}'), findsOneWidget);
      expect(
        find.text('Datos demostrativos · Sin monitoreo en tiempo real'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Actualizar lugares'));
      await tester.pumpAndSettle();
      expect(servicio.solicitudes, [null, nivel, nivel]);
      await elegir(tester, null);
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
        3,
      );
      expect(
        find.byKey(const ValueKey('filtro-saturacion-activo')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'cambiar nivel sustituye marcadores y quitar por botón restaura Todos',
    (tester) async {
      final servicio = _Servicio((valor) async => _respuesta(valor));
      await montar(tester, servicio);
      await elegir(tester, SaturationLevel.tranquilo);
      await tester.pumpAndSettle();
      await elegir(tester, SaturationLevel.saturado);
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.single.key,
        const ValueKey('marker-3'),
      );
      expect(find.text('Saturación: Saturado'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Quitar filtro de saturación'));
      await tester.tap(find.byTooltip('Quitar filtro de saturación'));
      await tester.pumpAndSettle();
      expect(servicio.solicitudes.last, isNull);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
        3,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'sin coincidencias informa y permite cambiar, quitar o reintentar',
    (tester) async {
      final servicio = _Servicio(
        (nivel) async => nivel == SaturationLevel.moderado
            ? const GenericResponse(success: true, data: [])
            : _respuesta(nivel),
      );
      await montar(tester, servicio);
      await elegir(tester, SaturationLevel.moderado);
      await tester.pumpAndSettle();
      expect(
        find.text('No hay lugares que coincidan con ese nivel de saturación.'),
        findsOneWidget,
      );
      expect(find.byType(MarkerLayer), findsNothing);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(servicio.solicitudes.last, SaturationLevel.moderado);
      await elegir(tester, SaturationLevel.tranquilo);
      await tester.pumpAndSettle();
      expect(find.byType(MarkerLayer), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'error mantiene el filtro y reintento recupera la misma consulta',
    (tester) async {
      var filtradas = 0;
      final servicio = _Servicio((nivel) async {
        if (nivel != null && filtradas++ == 0) {
          return const GenericResponse(
            success: false,
            message: PlaceService.loadError,
          );
        }
        return _respuesta(nivel);
      });
      await montar(tester, servicio);
      await elegir(tester, SaturationLevel.saturado);
      await tester.pumpAndSettle();
      expect(find.text(PlaceService.loadError), findsOneWidget);
      expect(find.text('Saturación: Saturado'), findsOneWidget);
      expect(find.byType(MarkerLayer), findsNothing);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(servicio.solicitudes, [
        null,
        SaturationLevel.saturado,
        SaturationLevel.saturado,
      ]);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.single.key,
        const ValueKey('marker-3'),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('carga retira selección e invalida su saturación tardía', (
    tester,
  ) async {
    final saturacion = Completer<GenericResponse<SaturationModel>>();
    final filtrado = Completer<GenericResponse<List<PlaceModel>>>();
    final servicio = _Servicio(
      (nivel) async => nivel == null ? _respuesta(null) : filtrado.future,
    );
    await montar(
      tester,
      servicio,
      saturacion: _Saturacion((_) => saturacion.future),
    );
    tester
        .widget<IconButton>(find.byKey(const ValueKey('select-place--1')))
        .onPressed!();
    await tester.pump();
    expect(find.text('Lugar tranquilo'), findsOneWidget);
    await elegir(tester, SaturationLevel.saturado);
    expect(find.text('Cargando lugares…'), findsOneWidget);
    expect(find.text('Lugar tranquilo'), findsNothing);
    saturacion.complete(
      GenericResponse(
        success: true,
        data: SaturationModel.fromJson({
          'placeId': -1,
          'level': 'TRANQUILO',
          'reason': null,
          'reportCount': 3,
          'minimumReports': 3,
          'windowMinutes': 30,
          'evaluatedAt': '2026-10-11T17:25:00.000Z',
          'updatedAt': '2026-10-11T17:20:00.000Z',
        }),
      ),
    );
    filtrado.complete(_respuesta(SaturationLevel.saturado));
    await tester.pumpAndSettle();
    expect(find.text('Lugar tranquilo'), findsNothing);
    expect(find.text('Nivel de saturación'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'permite cambiar filtro mientras carga y descarta primera respuesta',
    (tester) async {
      final primera = Completer<GenericResponse<List<PlaceModel>>>();
      final servicio = _Servicio(
        (nivel) async => nivel == SaturationLevel.tranquilo
            ? primera.future
            : _respuesta(nivel),
      );
      await montar(tester, servicio);
      await elegir(tester, SaturationLevel.tranquilo);
      expect(find.text('Cargando lugares…'), findsOneWidget);
      await elegir(tester, SaturationLevel.moderado);
      await tester.pumpAndSettle();
      primera.complete(_respuesta(SaturationLevel.tranquilo));
      await tester.pumpAndSettle();
      expect(find.text('Saturación: Moderado'), findsOneWidget);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.single.key,
        const ValueKey('marker-2'),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('respuesta inmediata del filtro también retira la selección', (
    tester,
  ) async {
    final pendiente = Completer<GenericResponse<SaturationModel>>();
    final servicio = _Servicio((nivel) async => _respuesta(nivel));
    await montar(
      tester,
      servicio,
      saturacion: _Saturacion((_) => pendiente.future),
    );
    tester
        .widget<IconButton>(find.byKey(const ValueKey('select-place--1')))
        .onPressed!();
    await tester.pump();
    expect(find.text('Lugar tranquilo'), findsOneWidget);
    await elegir(tester, SaturationLevel.tranquilo);
    await tester.pump();
    pendiente.complete(
      const GenericResponse(
        success: false,
        message: SaturationService.loadError,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lugar tranquilo'), findsNothing);
    expect(find.text('Nivel de saturación'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('logout retira filtro activo y marcadores filtrados', (
    tester,
  ) async {
    final servicio = _Servicio((nivel) async => _respuesta(nivel));
    await montar(tester, servicio);
    await elegir(tester, SaturationLevel.saturado);
    await tester.pumpAndSettle();
    SessionService.clear();
    await tester.pumpAndSettle();
    expect(find.byType(MarkerLayer), findsNothing);
    expect(
      find.byKey(const ValueKey('filtro-saturacion-activo')),
      findsNothing,
    );
    expect(find.text('Inicia sesión para ver los lugares.'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Saturación'),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('filtro activo con mapa cargado en 360x360 y texto2x', (
    tester,
  ) async {
    final servicio = _Servicio((nivel) async => _respuesta(nivel));
    await montar(tester, servicio, tamano: const Size(360, 360), escala: 2);
    await elegir(tester, SaturationLevel.saturado);
    await tester.pumpAndSettle();
    expect(find.text('Saturación: Saturado'), findsOneWidget);
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.single.key,
      const ValueKey('marker-3'),
    );
    await tester.ensureVisible(find.byTooltip('Quitar filtro de saturación'));
    await tester.tap(find.byTooltip('Quitar filtro de saturación'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
      3,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'retirar vista con selector abierto no aplica selección pendiente',
    (tester) async {
      final servicio = _Servicio((nivel) async => _respuesta(nivel));
      await montar(tester, servicio);
      await tester.tap(find.byTooltip('Filtrar por saturación'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const SizedBox.shrink()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MapPage), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('opcion-saturacion-MODERADO')),
      );
      await tester.pumpAndSettle();
      expect(servicio.solicitudes, [null]);
      expect(tester.takeException(), isNull);
    },
  );
  for (final nuevaSesion in [false, true]) {
    testWidgets(
      'selector abierto no aplica filtro después de logout nueva=$nuevaSesion',
      (tester) async {
        final servicio = _Servicio((nivel) async => _respuesta(nivel));
        await montar(tester, servicio);
        await tester.tap(find.byTooltip('Filtrar por saturación'));
        await tester.pumpAndSettle();
        SessionService.clear();
        if (nuevaSesion) {
          SessionService.start(
            token: 'test-token',
            user: const UserModel(id: 1),
          );
        }
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('opcion-saturacion-SATURADO')),
        );
        await tester.pumpAndSettle();
        expect(servicio.solicitudes, [null]);
        expect(find.byType(MarkerLayer), findsNothing);
        expect(
          find.byKey(const ValueKey('filtro-saturacion-activo')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('cancelar selector conserva el filtro sin una nueva consulta', (
    tester,
  ) async {
    final servicio = _Servicio((nivel) async => _respuesta(nivel));
    await montar(tester, servicio);
    await elegir(tester, SaturationLevel.tranquilo);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filtrar por saturación'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar filtro'));
    await tester.pumpAndSettle();
    expect(servicio.solicitudes, [null, SaturationLevel.tranquilo]);
    expect(find.text('Saturación: Tranquilo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final tamano in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    for (final error in [false, true]) {
      testWidgets(
        'filtro ${error ? 'error' : 'vacío'} sin overflow $tamano texto2x',
        (tester) async {
          final servicio = _Servicio(
            (nivel) async => nivel == null
                ? _respuesta(null)
                : error
                ? const GenericResponse(
                    success: false,
                    message: PlaceService.loadError,
                  )
                : const GenericResponse(success: true, data: []),
          );
          await montar(tester, servicio, tamano: tamano, escala: 2);
          await elegir(tester, SaturationLevel.saturado);
          await tester.pumpAndSettle();
          expect(find.text('Saturación: Saturado'), findsOneWidget);
          if (!error) {
            expect(
              find.text(
                'No hay lugares que coincidan con ese nivel de saturación.',
              ),
              findsOneWidget,
            );
          }
          await tester.ensureVisible(find.text('Reintentar'));
          await tester.tap(find.text('Reintentar'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byTooltip('Quitar filtro de saturación'),
          );
          await tester.tap(find.byTooltip('Quitar filtro de saturación'));
          await tester.pumpAndSettle();
          expect(find.byType(MarkerLayer), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'selector ofrece los cuatro niveles con foco y activación por teclado',
    (tester) async {
      final servicio = _Servicio((nivel) async => _respuesta(nivel));
      await montar(tester, servicio);
      await tester.tap(find.byTooltip('Filtrar por saturación'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectorSaturacion), findsOneWidget);
      for (final etiqueta in ['Todos', 'Tranquilo', 'Moderado', 'Saturado']) {
        expect(find.text(etiqueta), findsOneWidget);
      }
      final semantica = tester.ensureSemantics();
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey('semantica-saturacion-TODOS')),
            )
            .getSemanticsData()
            .flagsCollection
            .isButton,
        isTrue,
      );
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey('semantica-saturacion-TODOS')),
            )
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      semantica.dispose();
      Focus.of(tester.element(find.text('Moderado'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(SelectorSaturacion), findsNothing);
      expect(servicio.solicitudes.last, SaturationLevel.moderado);
      expect(tester.takeException(), isNull);
    },
  );
}
