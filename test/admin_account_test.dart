import 'dart:async';
import 'dart:convert';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/admin/admin_user_detail_page.dart';
import 'package:crowdradar/services/admin_user_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> account({
  String status = 'ACTIVO',
  String role = 'USUARIO',
  int version = 0,
}) => {
  'id': 2,
  'nombre': 'Bruno',
  'apellido': 'Mendoza',
  'email': 'bruno@example.test',
  'rol': role,
  'status': status,
  'denouncedReportCount': 2,
  'moderationVersion': version,
};
Map<String, dynamic> event(int id, {bool suspend = true}) => {
  'id': '$id',
  'action': suspend ? 'SUSPEND' : 'REACTIVATE',
  'reason': suspend ? 'Motivo comprobado' : null,
  'previousStatus': suspend ? 'ACTIVO' : 'SUSPENDIDO',
  'newStatus': suspend ? 'SUSPENDIDO' : 'ACTIVO',
  'adminId': 1,
  'adminName': 'Admin QA',
  'moderationVersion': id,
  'createdAt': '2026-10-28T14:00:00.000Z',
};
http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
http.Response history(List<Map<String, dynamic>> events, {String? cursor}) =>
    json({
      'data': events,
      'pagination': {'nextBefore': cursor},
    });
Future<void> pumpAccount(WidgetTester tester, {double scale = 1}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const AdminUserDetailPage(id: 2),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapAction(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  setUp(
    () => SessionService.start(
      token: 'synthetic',
      user: const UserModel(id: 1, rol: 'ADMIN'),
    ),
  );
  tearDown(SessionService.clear);

  testWidgets(
    'cancelar no envía; motivo vacío se valida; un envío y su historial',
    (tester) async {
      var current = account(), posts = 0;
      final events = <Map<String, dynamic>>[];
      await http.runWithClient(
        () async {
          await pumpAccount(tester);
          await tapAction(tester, 'Suspender cuenta');
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
          expect(posts, 0);
          await tapAction(tester, 'Suspender cuenta');
          await tester.tap(find.text('Confirmar suspensión'));
          await tester.pumpAndSettle();
          expect(
            find.text('Escribe el motivo de la suspensión.'),
            findsOneWidget,
          );
          expect(posts, 0);
          await tester.enterText(
            find.byType(TextFormField),
            'Motivo comprobado',
          );
          await tester.tap(find.text('Confirmar suspensión'));
          await tester.pumpAndSettle();
          expect(posts, 1);
          expect(find.text('Reactivar cuenta'), findsOneWidget);
          expect(find.text('Cuenta suspendida'), findsOneWidget);
          expect(find.text('Administrador: Admin QA (ID 1)'), findsOneWidget);
          expect(find.text('Motivo: Motivo comprobado'), findsOneWidget);
        },
        () => MockClient((r) async {
          if (r.method == 'POST') {
            posts++;
            expect(r.url.path, '/api/admin/users/2/suspend');
            expect(jsonDecode(r.body), {
              'reason': 'Motivo comprobado',
              'expectedVersion': 0,
            });
            current = account(status: 'SUSPENDIDO', version: 1);
            events.add(event(1));
            return json({'data': current});
          }
          return r.url.path.endsWith('/history')
              ? history(events.reversed.toList())
              : json({'data': current});
        }),
      );
    },
  );

  testWidgets('reactivar sin observación conserva los dos eventos', (
    tester,
  ) async {
    var current = account(status: 'SUSPENDIDO', version: 1), posts = 0;
    final events = [event(1)];
    await http.runWithClient(
      () async {
        await pumpAccount(tester);
        await tapAction(tester, 'Reactivar cuenta');
        expect(find.text('Observación opcional'), findsOneWidget);
        await tester.tap(find.text('Confirmar reactivación'));
        await tester.pumpAndSettle();
        expect(posts, 1);
        expect(find.text('Suspender cuenta'), findsOneWidget);
        expect(find.text('Cuenta reactivada'), findsOneWidget);
        expect(find.text('Cuenta suspendida'), findsOneWidget);
        expect(find.text('Observación: Sin observación'), findsOneWidget);
      },
      () => MockClient((r) async {
        if (r.method == 'POST') {
          posts++;
          expect(jsonDecode(r.body), {'expectedVersion': 1});
          current = account(version: 2);
          events.add(event(2, suspend: false));
          return json({'data': current});
        }
        return r.url.path.endsWith('/history')
            ? history(events.reversed.toList())
            : json({'data': current});
      }),
    );
  });

  testWidgets('guardado pendiente bloquea envío doble y navegación atrás', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var posts = 0;
    await http.runWithClient(
      () async {
        await pumpAccount(tester);
        await tapAction(tester, 'Suspender cuenta');
        await tester.enterText(find.byType(TextFormField), 'Motivo comprobado');
        await tester.tap(find.text('Confirmar suspensión'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(posts, 1);
        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Guardando decisión…'),
        );
        expect(button.onPressed, isNull);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == 'Volver a usuarios',
                ),
              )
              .onPressed,
          isNull,
        );
        pending.complete(json({'code': 'SERVICE_UNAVAILABLE'}, 503));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('No pudimos confirmar si la decisión se guardó'),
          findsOneWidget,
        );
        expect(posts, 1);
      },
      () => MockClient((r) async {
        if (r.method == 'POST') {
          posts++;
          return pending.future;
        }
        return r.url.path.endsWith('/history')
            ? history([])
            : json({'data': account()});
      }),
    );
  });

  testWidgets('respuesta incierta obliga a consultar; actualizar no reenvía', (
    tester,
  ) async {
    var posts = 0, current = account();
    await http.runWithClient(
      () async {
        await pumpAccount(tester);
        await tapAction(tester, 'Suspender cuenta');
        await tester.enterText(find.byType(TextFormField), 'Motivo comprobado');
        await tester.tap(find.text('Confirmar suspensión'));
        await tester.pumpAndSettle();
        expect(find.text('Suspender cuenta'), findsNothing);
        await tester.tap(find.text('Actualizar cuenta e historial'));
        await tester.pumpAndSettle();
        expect(posts, 1);
        expect(find.text('Reactivar cuenta'), findsOneWidget);
      },
      () => MockClient((r) async {
        if (r.method == 'POST') {
          posts++;
          current = account(status: 'SUSPENDIDO', version: 1);
          throw http.ClientException('Respuesta perdida');
        }
        return r.url.path.endsWith('/history')
            ? history(posts == 0 ? [] : [event(1)])
            : json({'data': current});
      }),
    );
  });

  testWidgets(
    'otra cuenta administradora no presenta suspensión ni reactivación',
    (tester) async {
      await http.runWithClient(
        () async {
          await pumpAccount(tester);
          expect(find.text('Suspender cuenta'), findsNothing);
          expect(find.text('Reactivar cuenta'), findsNothing);
          expect(
            find.text(
              'No hay decisiones registradas desde que se habilitó este historial.',
            ),
            findsOneWidget,
          );
        },
        () => MockClient(
          (r) async => r.url.path.endsWith('/history')
              ? history([])
              : json({'data': account(role: 'ADMIN')}),
        ),
      );
    },
  );

  testWidgets('cambio de sesión cierra la confirmación sin enviar', (
    tester,
  ) async {
    var posts = 0;
    await http.runWithClient(
      () async {
        await pumpAccount(tester);
        await tapAction(tester, 'Suspender cuenta');
        SessionService.clear();
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(posts, 0);
      },
      () => MockClient((r) async {
        if (r.method == 'POST') posts++;
        return r.url.path.endsWith('/history')
            ? history([])
            : json({'data': account()});
      }),
    );
  });

  test(
    'historial rechaza orden incorrecto, cursor incongruente y datos faltantes',
    () async {
      for (final body in [
        {
          'data': [event(10), event(11)],
          'pagination': {'nextBefore': null},
        },
        {
          'data': [event(11)],
          'pagination': {'nextBefore': '10'},
        },
        {
          'data': [event(11)..remove('adminName')],
          'pagination': {'nextBefore': null},
        },
      ]) {
        await http.runWithClient(() async {
          expect((await AdminUserService().history(2)).success, isFalse);
        }, () => MockClient((_) async => json(body)));
      }
    },
  );

  for (final width in [360.0, 390.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'confirmación e historial sin overflow: $width texto $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await http.runWithClient(
            () async {
              await pumpAccount(tester, scale: scale);
              await tapAction(tester, 'Suspender cuenta');
              expect(tester.takeException(), isNull);
              await tester.tap(find.text('Cancelar'));
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(
                find.text('Cuenta reactivada'),
                250,
                scrollable: find.byType(Scrollable).first,
              );
              expect(tester.takeException(), isNull);
            },
            () => MockClient(
              (r) async => r.url.path.endsWith('/history')
                  ? history([event(2, suspend: false), event(1)])
                  : json({'data': account(version: 2)}),
            ),
          );
        },
      );
    }
  }
}
