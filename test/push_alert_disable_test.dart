import 'dart:async';
import 'dart:convert';

import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/router/app_router.dart';
import 'package:crowdradar/services/push_device_service.dart';
import 'package:crowdradar/services/push_notification_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// Inyección de streams del adaptador transitivo ya usado por Firebase Messaging.
// ignore: depend_on_referenced_packages
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/push_alert_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () =>
        SessionService.start(token: 'session-a', user: const UserModel(id: 1)),
  );
  tearDown(SessionService.clear);

  test(
    'baja espera confirmación, bloquea alta/doble baja y conserva captura exacta',
    () async {
      final f = PushTestFixture();
      addTearDown(f.push.dispose);
      await f.activate();
      final generation = SessionService.generation;
      f.devices.removalGate = Completer<void>();
      final pending = f.push.disableForCurrentSession();
      expect(f.push.status.value, PushAlertStatus.disabling);
      expect(await f.push.disableForCurrentSession(), isFalse);
      expect(await f.push.enableForCurrentSession(), isFalse);
      expect(f.devices.removed, [
        (session: 'session-a', token: 'device-1', binding: 'binding-1'),
      ]);
      expect(f.messaging.operations.where((e) => e == 'deleteToken'), isEmpty);
      f.devices.removalGate!.complete();
      expect(await pending, isTrue);
      await flushPush();
      expect(f.push.status.value, PushAlertStatus.inactive);
      expect(f.messaging.operations.last, 'deleteToken');
      expect(SessionService.generation, generation);
      expect(SessionService.isAuthenticated, isTrue);
      f.devices.removalGate = null;
      expect(await f.push.enableForCurrentSession(), isTrue);
      expect(f.push.status.value, PushAlertStatus.active);
      expect(f.devices.registered, ['device-1', 'device-2']);
    },
  );

  for (final failure in [StateError('503'), TimeoutException('uncertain')]) {
    test(
      'baja ${failure.runtimeType} no confirma ni reactiva y reintenta mismo binding',
      () async {
        final f = PushTestFixture();
        addTearDown(f.push.dispose);
        await f.activate();
        f.devices.removalError = failure;
        expect(await f.push.disableForCurrentSession(), isFalse);
        expect(f.push.status.value, PushAlertStatus.disableUnconfirmed);
        expect(await f.push.enableForCurrentSession(), isFalse);
        expect(SessionService.isAuthenticated, isTrue);
        expect(
          f.messaging.operations.where((e) => e == 'deleteToken'),
          isEmpty,
        );
        f.devices.removalError = null;
        expect(await f.push.disableForCurrentSession(), isTrue);
        expect(f.devices.removed.length, 2);
        expect(f.devices.removed.first, f.devices.removed.last);
      },
    );
  }

  test(
    '204 antiguo no limpia token ni estado de cuenta B ya activada',
    () async {
      final f = PushTestFixture();
      addTearDown(f.push.dispose);
      await f.activate();
      final gate = Completer<void>();
      f.devices.removalGate = gate;
      final old = f.push.disableForCurrentSession();
      SessionService.start(token: 'session-b', user: const UserModel(id: 2));
      f.devices.removalGate = null;
      expect(await f.push.enableForCurrentSession(), isTrue);
      final operations = [...f.messaging.operations];
      gate.complete();
      expect(await old, isFalse);
      await flushPush();
      expect(f.messaging.operations, operations);
      expect(f.push.status.value, PushAlertStatus.active);
      expect(f.devices.removed.every((d) => d.binding == 'binding-1'), isTrue);
      expect(SessionService.currentUser?.id, 2);
    },
  );

  test(
    'guarda dentro de cola omite cleanup cuando sesión cambia tras el 204',
    () async {
      final f = PushTestFixture();
      addTearDown(f.push.dispose);
      await f.activate();
      final gate = Completer<void>();
      f.devices.removalGate = gate;
      final old = f.push.disableForCurrentSession();
      gate.complete();
      scheduleMicrotask(
        () => SessionService.start(token: 'b', user: const UserModel(id: 2)),
      );
      expect(await old, isTrue);
      await flushPush();
      // Solo cleanup de cambio de sesión; no un segundo delete de la baja vieja.
      expect(f.messaging.operations.where((e) => e == 'deleteToken').length, 1);
      expect(f.push.status.value, PushAlertStatus.inactive);
      expect(await f.push.enableForCurrentSession(), isTrue);
    },
  );

  test('cleanup SDK pendiente precede la nueva obtención del token', () async {
    final f = PushTestFixture();
    addTearDown(f.push.dispose);
    await f.activate();
    f.messaging.deleteGate = Completer<void>();
    expect(await f.push.disableForCurrentSession(), isTrue);
    await flushPush();
    final enabled = f.push.enableForCurrentSession();
    await flushPush();
    expect(f.messaging.operations.where((e) => e == 'getToken').length, 1);
    f.messaging.deleteGate!.complete();
    expect(await enabled, isTrue);
    expect(f.messaging.operations, [
      'permission',
      'getToken',
      'deleteToken',
      'permission',
      'getToken',
    ]);
  });

  testWidgets(
    'baja bloquea mensajes/acciones viejas y cierra solo snackbar push',
    (tester) async {
      final f = PushTestFixture();
      addTearDown(f.push.dispose);
      await f.activate();
      final messenger = GlobalKey<ScaffoldMessengerState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appRouter.routerDelegate.navigatorKey,
          scaffoldMessengerKey: messenger,
          home: const Scaffold(body: Text('Prueba')),
        ),
      );
      const message = RemoteMessage(
        data: {
          'userId': '1',
          'placeId': '-2005',
          'registrationId': 'binding-1',
        },
        notification: RemoteNotification(
          title: 'Alerta de prueba',
          body: 'Estado cambiado',
        ),
      );
      FirebaseMessagingPlatform.onMessage.add(message);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Cambió la saturación de un favorito. Consulta su nivel actual.',
        ),
        findsOneWidget,
      );
      final action = tester
          .widget<SnackBarAction>(find.byType(SnackBarAction))
          .onPressed;
      messenger.currentState!.showSnackBar(
        const SnackBar(content: Text('Aviso ajeno')),
      );
      f.devices.removalGate = Completer<void>();
      final pending = f.push.disableForCurrentSession();
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Cambió la saturación de un favorito. Consulta su nivel actual.',
        ),
        findsNothing,
      );
      expect(find.text('Aviso ajeno'), findsOneWidget);
      final uri = appRouter.routeInformationProvider.value.uri;
      action();
      FirebaseMessagingPlatform.onMessageOpenedApp.add(message);
      FirebaseMessagingPlatform.onMessage.add(message);
      await tester.pump();
      expect(appRouter.routeInformationProvider.value.uri, uri);
      expect(
        find.text(
          'Cambió la saturación de un favorito. Consulta su nivel actual.',
        ),
        findsNothing,
      );
      f.devices.removalGate!.complete();
      expect(await pending, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final status in [200, 401, 503, 204]) {
    test(
      'transporte DELETE exige 204 (respuesta $status), sin logout ni otros destinos',
      () async {
        final generation = SessionService.generation;
        await http.runWithClient(
          () async {
            final result = PushDeviceService().unregister(
              sessionToken: 'session-a',
              deviceToken: 'only-this-token',
              registrationId: 'only-this-binding',
            );
            if (status == 204) {
              await result;
            } else {
              await expectLater(result, throwsStateError);
            }
          },
          () => MockClient((request) async {
            expect(request.method, 'DELETE');
            expect(request.url.path, '/api/notifications/devices');
            expect(request.headers['Authorization'], 'Bearer session-a');
            expect(jsonDecode(request.body), {
              'token': 'only-this-token',
              'registrationId': 'only-this-binding',
            });
            return http.Response('', status);
          }),
        );
        expect(SessionService.generation, generation);
        expect(SessionService.isAuthenticated, isTrue);
      },
    );
  }

  test(
    '401 de baja explícita invalida solo la generación que hizo la petición',
    () async {
      final old = Completer<http.Response>();
      await http.runWithClient(() async {
        final pending = PushDeviceService().unregister(
          sessionToken: 'session-a',
          deviceToken: 'device-1',
          registrationId: 'binding-1',
          generation: SessionService.generation,
        );
        final rejected = expectLater(pending, throwsStateError);
        SessionService.start(token: 'session-a', user: const UserModel(id: 2));
        old.complete(http.Response('', 401));
        await rejected;
        expect(SessionService.currentUser?.id, 2);
        expect(SessionService.isAuthenticated, isTrue);
      }, () => MockClient((_) => old.future));
      await http.runWithClient(() async {
        await expectLater(
          PushDeviceService().unregister(
            sessionToken: 'session-a',
            deviceToken: 'device-2',
            registrationId: 'binding-2',
            generation: SessionService.generation,
          ),
          throwsStateError,
        );
        expect(SessionService.isAuthenticated, isFalse);
        expect(SessionService.wasRejected, isTrue);
      }, () => MockClient((_) async => http.Response('', 401)));
    },
  );
}
