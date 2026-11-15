import 'dart:async';
import 'dart:convert';

import 'package:crowdradar/pages/places/place_detail_page.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/router/app_router.dart';
import 'package:crowdradar/services/push_message_guard.dart';
import 'package:crowdradar/services/push_notification_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// Inyecta los streams del paquete ya resuelto, sin dependencia nueva ni red.
// ignore: depend_on_referenced_packages
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart'
    show FirebaseMessagingPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/push_alert_fakes.dart';

const _banner = 'Cambio que originó esta alerta';
const _validText = 'Cambió la saturación: Saturado → Moderado.';
const _fallbackText =
    'Cambió la saturación de un favorito. Consulta su nivel actual.';
const _data = <String, dynamic>{
  'userId': '1',
  'placeId': '-2005',
  'registrationId': 'binding-1',
  'previousLevel': 'SATURADO',
  'newLevel': 'MODERADO',
};

RemoteMessage _message([Map<String, dynamic> data = _data]) => RemoteMessage(
  data: data,
  notification: const RemoteNotification(
    title: 'Título arbitrario no autorizado',
    body: 'Cuerpo arbitrario no autorizado',
  ),
);

void _expectNoArbitraryText() {
  expect(find.textContaining('Título arbitrario'), findsNothing);
  expect(find.textContaining('Cuerpo arbitrario'), findsNothing);
}

Future<void> _withApp(
  WidgetTester tester,
  Future<void> Function(PushTestFixture fixture) action,
) async {
  final fixture = PushTestFixture();
  await http.runWithClient(
    () async {
      try {
        await tester.runAsync(fixture.activate);
        expect(fixture.push.status.value, PushAlertStatus.active);
        appRouter.go('/places/1');
        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: appRouter,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Lugar 1'), findsOneWidget);
        await action(fixture);
        expect(tester.takeException(), isNull);
      } finally {
        // Los streams del fixture nacen en runAsync: drenar también sus cierres.
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        final gate = fixture.devices.removalGate;
        if (gate != null && !gate.isCompleted) gate.complete();
        fixture.push.unregisterForLogout();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(fixture.push.dispose);
        appRouter.go('/login');
        await tester.pump();
      }
    },
    () => MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, isIn(['/api/places/1', '/api/places/-2005']));
      expect(
        request.headers['Authorization'],
        'Bearer integration-test-session',
      );
      final id = int.parse(request.url.pathSegments.last);
      return http.Response(
        jsonEncode({
          'data': {
            'id': id,
            'nombre': 'Lugar $id',
            'categoria': 'Parque',
            'latitud': -12.12,
            'longitud': -77.03,
            'demostrativo': true,
          },
        }),
        200,
      );
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SessionService.clear();
    SessionService.start(
      token: 'integration-test-session',
      user: const UserModel(id: 1),
    );
  });
  tearDown(SessionService.clear);
  tearDownAll(appRouter.dispose);

  for (final foreground in [true, false]) {
    testWidgets(
      'mensaje ${foreground ? 'foreground con acción' : 'abierto'} llega a la ruta con contexto tipado',
      (tester) async {
        await _withApp(tester, (fixture) async {
          final message = _message();
          if (foreground) {
            FirebaseMessagingPlatform.onMessage.add(message);
            await tester.pumpAndSettle();
            expect(find.text(_validText), findsOneWidget);
            _expectNoArbitraryText();
            await tester.tap(find.widgetWithText(SnackBarAction, 'Ver lugar'));
          } else {
            FirebaseMessagingPlatform.onMessageOpenedApp.add(message);
          }
          await tester.pumpAndSettle();
          expect(find.text('Lugar -2005'), findsOneWidget);
          final page = tester.widget<PlaceDetailPage>(
            find.byType(PlaceDetailPage),
          );
          expect(page.pushTransition, isA<AuthorizedPushTransition>());
          expect(page.pushTransition!.isCurrentForPlace(-2005), isTrue);
          expect(find.text(_banner), findsOneWidget);
          expect(find.text('Saturado → Moderado'), findsOneWidget);
          _expectNoArbitraryText();
        });
      },
    );
  }

  for (final incomplete in [true, false]) {
    testWidgets(
      'mensaje ${incomplete ? 'sin niveles' : 'con nivel desconocido'} abre detalle normal y texto fijo',
      (tester) async {
        await _withApp(tester, (fixture) async {
          final data = {..._data};
          if (incomplete) {
            data.remove('previousLevel');
            data.remove('newLevel');
          } else {
            data['newLevel'] = 'Texto arbitrario en nivel';
          }
          FirebaseMessagingPlatform.onMessage.add(_message(data));
          await tester.pumpAndSettle();
          expect(find.text(_fallbackText), findsOneWidget);
          expect(
            find.textContaining('Texto arbitrario en nivel'),
            findsNothing,
          );
          _expectNoArbitraryText();
          await tester.tap(find.widgetWithText(SnackBarAction, 'Ver lugar'));
          await tester.pumpAndSettle();
          expect(find.text('Lugar -2005'), findsOneWidget);
          final page = tester.widget<PlaceDetailPage>(
            find.byType(PlaceDetailPage),
          );
          expect(page.pushTransition, isNull);
          expect(find.text(_banner), findsNothing);
        });
      },
    );
  }

  testWidgets(
    'baja local retira SnackBar y banner y bloquea acción/eventos antiguos',
    (tester) async {
      await _withApp(tester, (fixture) async {
        final message = _message();
        FirebaseMessagingPlatform.onMessageOpenedApp.add(message);
        await tester.pumpAndSettle();
        expect(find.text(_banner), findsOneWidget);
        FirebaseMessagingPlatform.onMessage.add(message);
        await tester.pumpAndSettle();
        expect(find.text(_validText), findsOneWidget);
        final oldAction = tester
            .widget<SnackBarAction>(find.byType(SnackBarAction))
            .onPressed;
        fixture.devices.removalGate = Completer<void>();
        final pending = fixture.push.disableForCurrentSession();
        expect(fixture.push.status.value, PushAlertStatus.disabling);
        await tester.pumpAndSettle();
        expect(find.text(_validText), findsNothing);
        expect(find.text(_banner), findsNothing);
        expect(find.text('Lugar -2005'), findsOneWidget);
        final matches =
            appRouter.routerDelegate.currentConfiguration.matches.length;
        final uri = appRouter.routeInformationProvider.value.uri;
        oldAction();
        FirebaseMessagingPlatform.onMessageOpenedApp.add(message);
        FirebaseMessagingPlatform.onMessage.add(message);
        await tester.pumpAndSettle();
        expect(appRouter.routeInformationProvider.value.uri, uri);
        expect(
          appRouter.routerDelegate.currentConfiguration.matches.length,
          matches,
        );
        expect(find.text(_validText), findsNothing);
        expect(find.text(_banner), findsNothing);
        fixture.devices.removalGate!.complete();
        await tester.pump();
        expect(await pending, isTrue);
        expect(fixture.push.status.value, PushAlertStatus.inactive);
      });
    },
  );
}
