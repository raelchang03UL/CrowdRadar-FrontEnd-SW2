import 'dart:convert';

import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/router/app_router.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    SessionService.clear();
    SessionService.start(
      token: 'push-detail-test',
      user: const UserModel(id: 1, nombre: 'Usuario'),
    );
  });
  tearDown(SessionService.clear);

  testWidgets('la ruta de alerta abre el lugar consultado al backend', (
    tester,
  ) async {
    final router = createAppRouter(initialLocation: '/places/7');
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
        expect(find.text('Parque Central'), findsOneWidget);
        expect(find.text('Cambio de saturación'), findsNothing);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/places/7');
        expect(request.headers['Authorization'], 'Bearer push-detail-test');
        return http.Response(
          jsonEncode({
            'data': {
              'id': 7,
              'nombre': 'Parque Central',
              'categoria': 'Parque',
              'referencia': 'Junto a la plaza',
              'latitud': -12.0464,
              'longitud': -77.0428,
              'demostrativo': false,
            },
          }),
          200,
        );
      }),
    );
  });
}
