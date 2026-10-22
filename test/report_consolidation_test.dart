import 'dart:async';
import 'dart:convert';
import 'package:crowdradar/components/report_place_sheet.dart';
import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/services/saturation_report_service.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/models/saturation_model.dart' as saturation;
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:go_router/go_router.dart';

class _Delivery extends SaturationReportService {
  final pending = Completer<GenericResponse<SaturationReportReward>>();
  int calls = 0;
  @override
  Future<GenericResponse<SaturationReportReward>> createReport({
    required int placeId,
    required SaturationLevel level,
  }) {
    calls++;
    return pending.future;
  }
}

const _place = PlaceModel(
  id: -701,
  nombre: 'QA Parque',
  categoria: 'Parque',
  latitud: -12,
  longitud: -77,
  demostrativo: true,
);

void main() {
  setUp(() {
    SessionService.clear();
    SessionService.start(token: 'synthetic-test', user: const UserModel(id: 1));
  });
  tearDown(SessionService.clear);

  Future<void> open(
    WidgetTester tester,
    _Delivery service, {
    Size size = const Size(390, 844),
    double scale = 1,
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
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<bool>(
                context: context,
                isDismissible: false,
                enableDrag: false,
                isScrollControlled: true,
                useSafeArea: true,
                constraints: const BoxConstraints(maxWidth: 520),
                builder: (_) =>
                    ReportPlaceSheet(place: _place, service: service),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  test(
    '201 sin recompensa no inventa puntos; 409 y fallo interno son públicos',
    () async {
      for (final status in [201, 409, 503]) {
        final response = await http.runWithClient(
          () => SaturationReportService().createReport(
            placeId: -701,
            level: SaturationLevel.tranquil,
          ),
          () => MockClient(
            (_) async => http.Response(
              jsonEncode({
                'message': 'private SQL',
                'data': {'id': '1'},
              }),
              status,
            ),
          ),
        );
        expect(response.success, status == 201);
        expect(response.data, isNull);
        if (status != 201) expect(response.message, isNot(contains('private')));
      }
    },
  );
  test(
    'filtros se envían juntos sin perder categoría, nombre ni nivel',
    () async {
      await http.runWithClient(
        () async {
          expect(
            (await PlaceService().queryPlaces(
              nombre: 'QA & Parque',
              categoria: 'Parque',
              nivel: saturation.SaturationLevel.tranquilo,
            )).success,
            isTrue,
          );
        },
        () => MockClient((request) async {
          expect(request.url.queryParameters, {
            'nombre': 'QA & Parque',
            'categoria': 'Parque',
            'nivel': 'TRANQUILO',
          });
          return http.Response('{"data":[]}', 200);
        }),
      );
    },
  );
  testWidgets(
    'doble pulsación y Atrás durante envío no duplican ni cierran el formulario',
    (tester) async {
      final service = _Delivery();
      await open(tester, service);
      await tester.tap(find.text('Tranquilo'));
      await tester.pump();
      await tester.tap(find.text('Enviar reporte'));
      await tester.pump();
      expect(service.calls, 1);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancelar'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(ReportPlaceSheet), findsOneWidget);
      service.pending.complete(const GenericResponse(success: true));
      await tester.pumpAndSettle();
      expect(find.text('Reporte enviado'), findsOneWidget);
      expect(find.textContaining('karma'), findsNothing);
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportPlaceSheet), findsNothing);
    },
  );
  testWidgets(
    'logout limpia datos y una respuesta tardía no muestra éxito ni karma',
    (tester) async {
      final service = _Delivery();
      await open(tester, service);
      await tester.tap(find.text('Tranquilo'));
      await tester.pump();
      await tester.tap(find.text('Enviar reporte'));
      await tester.pump();
      SessionService.clear();
      await tester.pump();
      service.pending.complete(
        const GenericResponse(
          success: true,
          data: SaturationReportReward(pointsAwarded: 10, karmaPoints: 10),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(SaturationReportService.sessionError), findsOneWidget);
      expect(find.text('Reporte enviado'), findsNothing);
      expect(find.textContaining('+10'), findsNothing);
    },
  );
  testWidgets(
    'excepción muestra incertidumbre sin permitir reenviar ni filtrar detalles',
    (tester) async {
      final service = _Delivery();
      await open(tester, service);
      await tester.tap(find.text('Moderado'));
      await tester.pump();
      await tester.tap(find.text('Enviar reporte'));
      await tester.pump();
      service.pending.completeError(StateError('private exception'));
      await tester.pumpAndSettle();
      expect(find.text(SaturationReportService.uncertainError), findsOneWidget);
      expect(find.textContaining('private'), findsNothing);
      expect(find.text('Enviar reporte'), findsNothing);
      expect(find.text('Reporte enviado'), findsNothing);
      expect(find.text('Mis reportes'), findsOneWidget);
      expect(find.text('Cerrar'), findsOneWidget);
      expect(service.calls, 1);
    },
  );
  for (final size in [
    const Size(360, 640),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    testWidgets('formulario accesible sin overflow $size texto 2x', (
      tester,
    ) async {
      await open(tester, _Delivery(), size: size, scale: 2);
      await tester.ensureVisible(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Enviar reporte'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final success in [true, false]) {
    testWidgets(
      'historial personal accesible desde resultado success=$success',
      (tester) async {
        final service = _Delivery();
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    isDismissible: false,
                    enableDrag: false,
                    builder: (_) =>
                        ReportPlaceSheet(place: _place, service: service),
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
            GoRoute(
              path: '/profile/reports',
              builder: (_, _) =>
                  const Scaffold(body: Text('Historial personal QA')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tranquilo'));
        await tester.pump();
        await tester.tap(find.text('Enviar reporte'));
        await tester.pump();
        service.pending.complete(
          GenericResponse(
            success: success,
            error: success ? null : 'REPORT_UNCERTAIN',
          ),
        );
        await tester.pumpAndSettle();
        expect(service.calls, 1);
        if (!success) expect(find.text('Enviar reporte'), findsNothing);
        await tester.ensureVisible(find.text('Mis reportes'));
        await tester.tap(find.text('Mis reportes'));
        await tester.pumpAndSettle();
        expect(find.text('Historial personal QA'), findsOneWidget);
        expect(service.calls, 1);
      },
    );
  }
}
