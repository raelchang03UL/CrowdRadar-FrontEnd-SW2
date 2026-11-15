import 'dart:async';
import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/places/place_detail_page.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _lugares = [
  PlaceModel(
    id: 1,
    nombre: 'Primer lugar',
    categoria: 'Parque',
    latitud: -12.046,
    longitud: -77.042,
    demostrativo: true,
  ),
  PlaceModel(
    id: 2,
    nombre: 'Segundo lugar',
    categoria: 'Plaza',
    latitud: -12.046,
    longitud: -77.042,
    demostrativo: true,
  ),
];

class _Servicio extends PlaceService {
  final solicitudes = <int>[];
  Future<GenericResponse<PlaceModel>>? pendiente;
  @override
  Future<GenericResponse<PlaceModel>> getPlace(int id) async {
    solicitudes.add(id);
    if (id == 1 && pendiente != null) return await pendiente!;
    return GenericResponse(success: true, data: _lugares[id - 1]);
  }
}

void main() {
  setUp(() {
    SessionService.clear();
    SessionService.start(token: 'test-token', user: const UserModel(id: 1));
  });
  tearDown(SessionService.clear);
  for (final pendiente in [false, true]) {
    testWidgets(
      'cambiar ID de ruta reemplaza detalle y descarta anterior pendiente=$pendiente',
      (tester) async {
        final servicio = _Servicio();
        final respuesta = Completer<GenericResponse<PlaceModel>>();
        if (pendiente) servicio.pendiente = respuesta.future;
        final router = GoRouter(
          initialLocation: '/places/1',
          routes: [
            GoRoute(
              path: '/places/:id',
              builder: (_, estado) => PlaceDetailPage(
                id: int.parse(estado.pathParameters['id']!),
                service: servicio,
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
        );
        await tester.pump();
        if (!pendiente) await tester.pumpAndSettle();
        expect(servicio.solicitudes, [1]);
        if (!pendiente) expect(find.text('Primer lugar'), findsOneWidget);
        router.go('/places/2');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(servicio.solicitudes, [1, 2]);
        expect(find.text('Segundo lugar'), findsOneWidget);
        expect(find.text('Primer lugar'), findsNothing);
        if (pendiente) {
          respuesta.complete(GenericResponse(success: true, data: _lugares[0]));
          await tester.pumpAndSettle();
          expect(find.text('Segundo lugar'), findsOneWidget);
          expect(find.text('Primer lugar'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
