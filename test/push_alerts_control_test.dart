import 'dart:async';

import 'package:crowdradar/components/push_alerts_control.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/services/push_notification_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/push_alert_fakes.dart';

void main() {
  setUp(() => SessionService.start(token: 'a', user: const UserModel(id: 1)));
  tearDown(SessionService.clear);

  Future<void> mount(
    WidgetTester tester,
    PushTestFixture f, {
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PushAlertsControl(service: f.push),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'estado inicial no solicita permiso; activar confirma y no repite alta',
    (tester) async {
      final f = PushTestFixture();
      addTearDown(f.push.dispose);
      await f.push.initialize();
      await mount(tester, f);
      expect(f.messaging.operations, isEmpty);
      expect(find.text('Alertas inactivas en esta sesión'), findsOneWidget);
      await tester.tap(find.text('Activar alertas'));
      await tester.pumpAndSettle();
      expect(
        find.text('Alertas activadas en este dispositivo'),
        findsOneWidget,
      );
      expect(find.text('Desactivar alertas'), findsOneWidget);
      expect(f.devices.registered.length, 1);
      expect(await f.push.enableForCurrentSession(), isTrue);
      expect(f.messaging.operations, ['permission', 'getToken']);
    },
  );

  testWidgets(
    'cancelar conserva activo; confirmar bloquea doble clic hasta respuesta',
    (tester) async {
      final f = PushTestFixture();
      addTearDown(f.push.dispose);
      await f.activate();
      await mount(tester, f);
      await tester.tap(find.text('Desactivar alertas'));
      await tester.pumpAndSettle();
      expect(
        find.text('¿Desactivar alertas en este dispositivo?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(f.devices.removed, isEmpty);
      expect(f.push.status.value, PushAlertStatus.active);
      await tester.tap(find.text('Desactivar alertas'));
      await tester.pumpAndSettle();
      f.devices.removalGate = Completer<void>();
      await tester.tap(find.text('Confirmar desactivar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Desactivando…'), findsOneWidget);
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Desactivando…'),
      );
      expect(button.onPressed, isNull);
      expect(f.devices.removed.length, 1);
      f.devices.removalGate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Alertas desactivadas en este dispositivo.'),
        findsOneWidget,
      );
      expect(find.text('Activar alertas'), findsOneWidget);
      expect(SessionService.isAuthenticated, isTrue);
    },
  );

  testWidgets(
    'fallo no muestra éxito ni reactivación y permite reintentar baja',
    (tester) async {
      final f = PushTestFixture();
      addTearDown(f.push.dispose);
      await f.activate();
      await mount(tester, f);
      f.devices.removalError = TimeoutException('no confirmation');
      await tester.tap(find.text('Desactivar alertas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar desactivar'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Baja no confirmada en el servidor. Las alertas están bloqueadas en esta sesión.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Alertas desactivadas en este dispositivo.'),
        findsNothing,
      );
      expect(find.text('Activar alertas'), findsNothing);
      f.devices.removalError = null;
      await tester.tap(find.text('Reintentar desactivación'));
      await tester.pumpAndSettle();
      expect(f.devices.removed.length, 2);
      expect(f.devices.removed.first, f.devices.removed.last);
      expect(f.push.status.value, PushAlertStatus.inactive);
    },
  );

  testWidgets(
    'cambio de cuenta cierra confirmación y no confirma por la cuenta nueva',
    (tester) async {
      final f = PushTestFixture();
      addTearDown(f.push.dispose);
      await f.activate();
      await mount(tester, f);
      await tester.tap(find.text('Desactivar alertas'));
      await tester.pumpAndSettle();
      SessionService.start(token: 'b', user: const UserModel(id: 2));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      // Solo la baja best effort del cambio de sesión, ninguna acción del diálogo.
      expect(f.devices.removed.length, 1);
      expect(
        find.text('Alertas desactivadas en este dispositivo.'),
        findsNothing,
      );
      expect(find.text('Alertas inactivas en esta sesión'), findsOneWidget);
    },
  );

  testWidgets(
    'baja tardía no muestra mensaje ni estado anterior sobre nueva sesión',
    (tester) async {
      final f = PushTestFixture();
      addTearDown(f.push.dispose);
      await f.activate();
      await mount(tester, f);
      final gate = Completer<void>();
      f.devices.removalGate = gate;
      await tester.tap(find.text('Desactivar alertas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar desactivar'));
      await tester.pump();
      SessionService.start(token: 'b', user: const UserModel(id: 2));
      f.devices.removalGate = null;
      await f.push.enableForCurrentSession();
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Alertas desactivadas en este dispositivo.'),
        findsNothing,
      );
      expect(find.textContaining('falta confirmar'), findsNothing);
      expect(
        find.text('Alertas activadas en este dispositivo'),
        findsOneWidget,
      );
    },
  );

  testWidgets('control y diálogo caben a 360 px con texto 2×', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = PushTestFixture();
    addTearDown(f.push.dispose);
    await f.activate();
    await mount(tester, f, scale: 2);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Desactivar alertas'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar desactivar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });
}
