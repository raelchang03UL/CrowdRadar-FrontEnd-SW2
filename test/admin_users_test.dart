import 'dart:async';
import 'dart:convert';
import 'package:crowdradar/cubits/admin/admin_users_cubit.dart';
import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/admin/admin_users_page.dart';
import 'package:crowdradar/pages/admin/admin_user_detail_page.dart';
import 'package:crowdradar/pages/login/login_page.dart';
import 'package:crowdradar/router/app_router.dart';
import 'package:crowdradar/services/admin_user_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const admin = UserModel(id: 1, nombre: 'Administración', rol: 'ADMIN');
const citizen = UserModel(id: 2, nombre: 'Bruno', rol: 'USUARIO');
Map<String, dynamic> user({int id = 2, String name = 'Bruno'}) => {
  'id': id,
  'nombre': name,
  'apellido': 'Mendoza',
  'email': 'bruno@example.test',
  'rol': 'USUARIO',
  'status': 'ACTIVO',
  'denouncedReportCount': 1,
  'moderationVersion': 0,
};
http.Response json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
http.Response page(
  List<Map<String, dynamic>> users, {
  int number = 1,
  bool next = false,
}) => json({
  'data': users,
  'pagination': {'page': number, 'limit': 20, 'hasNext': next},
});

void main() {
  setUp(() => SessionService.start(token: 'synthetic-admin', user: admin));
  tearDown(SessionService.clear);

  test(
    'búsqueda preserva literales y combina estado; lista vacía es éxito',
    () async {
      await http.runWithClient(
        () async {
          final result = await AdminUserService().list(
            q: '  Ana %_+  ',
            status: 'SUSPENDIDO',
          );
          expect(result.success, isTrue);
          expect(result.data!.users, isEmpty);
        },
        () => MockClient((request) async {
          expect(request.url.path, '/api/admin/users');
          expect(request.url.queryParameters, {
            'q': 'Ana %_+',
            'status': 'SUSPENDIDO',
            'page': '1',
            'limit': '20',
          });
          expect(request.headers['Authorization'], 'Bearer synthetic-admin');
          return page([]);
        }),
      );
    },
  );

  test('no presenta páginas malformadas ni detalle de otro usuario', () async {
    for (final body in [
      {
        'data': [user(), user()],
        'pagination': {'page': 1, 'limit': 20, 'hasNext': false},
      },
      {
        'data': [user()..['denouncedReportCount'] = -1],
        'pagination': {'page': 1, 'limit': 20, 'hasNext': false},
      },
      {
        'data': [user()],
        'pagination': {'page': 2, 'limit': 20, 'hasNext': false},
      },
    ]) {
      await http.runWithClient(() async {
        expect((await AdminUserService().list()).success, isFalse);
      }, () => MockClient((_) async => json(body)));
    }
    await http.runWithClient(() async {
      expect((await AdminUserService().detail(3)).success, isFalse);
    }, () => MockClient((_) async => json({'data': user()})));
  });

  test('denegación de rol conserva sesión y entrega un mensaje útil', () async {
    await http.runWithClient(() async {
      final result = await AdminUserService().list();
      expect(result.error, 'ADMIN_REQUIRED');
      expect(result.message, contains('administradores'));
      expect(SessionService.isAuthenticated, isTrue);
    }, () => MockClient((_) async => json({'code': 'ADMIN_REQUIRED'}, 403)));
  });

  test(
    'la búsqueda reciente gana; una respuesta anterior no repone datos',
    () async {
      final responses = [
        Completer<http.Response>(),
        Completer<http.Response>(),
      ];
      var calls = 0;
      await http.runWithClient(() async {
        final cubit = AdminUsersCubit(AdminUserService());
        addTearDown(cubit.close);
        final first = cubit.search(q: 'Bruno', status: '');
        final second = cubit.search(q: 'zzzz', status: '');
        responses[1].complete(page([]));
        await second;
        responses[0].complete(page([user()]));
        await first;
        expect(cubit.state.data!.users, isEmpty);
      }, () => MockClient((_) => responses[calls++].future));
    },
  );

  for (final responseStatus in [200, 401]) {
    test(
      'respuesta $responseStatus de sesión anterior no afecta otra cuenta',
      () async {
        final response = Completer<http.Response>();
        await http.runWithClient(() async {
          final cubit = AdminUsersCubit(AdminUserService());
          addTearDown(cubit.close);
          final pending = cubit.load();
          SessionService.clear();
          SessionService.start(token: 'synthetic-new', user: citizen);
          response.complete(
            responseStatus == 200 ? page([user()]) : json({}, 401),
          );
          await pending;
          expect(cubit.state.data, isNull);
          expect(SessionService.currentUser, same(citizen));
        }, () => MockClient((_) => response.future));
      },
    );
  }

  test('paginación no pierde filtros y cerrar sesión borra datos', () async {
    final requests = <Uri>[];
    await http.runWithClient(
      () async {
        final cubit = AdminUsersCubit(AdminUserService());
        addTearDown(cubit.close);
        await cubit.search(q: 'Bruno', status: 'ACTIVO');
        await cubit.next();
        expect(cubit.state.data!.page, 2);
        expect(requests.last.queryParameters['q'], 'Bruno');
        expect(requests.last.queryParameters['status'], 'ACTIVO');
        await cubit.previous();
        expect(cubit.state.data!.page, 1);
        SessionService.clear();
        expect(cubit.state.data, isNull);
      },
      () => MockClient((r) async {
        requests.add(r.url);
        final number = int.parse(r.url.queryParameters['page']!);
        return page(
          [user(id: number + 1)],
          number: number,
          next: number == 1,
        );
      }),
    );
  });

  testWidgets(
    'Enter aplica búsqueda, vacío visible y detalle separado con vuelta',
    (tester) async {
      final auth = AuthCubit(),
          router = createAppRouter(initialLocation: '/admin/users');
      addTearDown(auth.close);
      addTearDown(router.dispose);
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            BlocProvider.value(
              value: auth,
              child: MaterialApp.router(
                theme: AppTheme.lightTheme,
                routerConfig: router,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Bruno Mendoza'), findsOneWidget);
          await tester.enterText(find.byType(TextField), 'zzzz');
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await tester.pumpAndSettle();
          expect(
            find.text('No hay resultados con estos criterios.'),
            findsOneWidget,
          );
          expect(find.text('Bruno Mendoza'), findsNothing);
          await tester.enterText(find.byType(TextField), 'bruno');
          await tester.tap(find.text('Buscar'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Bruno Mendoza'));
          await tester.tap(find.text('Bruno Mendoza'));
          await tester.pumpAndSettle();
          expect(find.byType(AdminUserDetailPage), findsOneWidget);
          expect(find.byType(TextField), findsNothing);
          expect(find.text('Reportes denunciados'), findsOneWidget);
          await tester.tap(find.byTooltip('Volver a usuarios'));
          await tester.pumpAndSettle();
          expect(find.byType(AdminUsersPage), findsOneWidget);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'bruno',
          );
        },
        () => MockClient(
          (r) async => r.url.path == '/api/admin/users/2'
              ? json({'data': user()})
              : page(r.url.queryParameters['q'] == 'zzzz' ? [] : [user()]),
        ),
      );
    },
  );

  testWidgets('401 vigente devuelve al login y elimina datos administrativos', (
    tester,
  ) async {
    final auth = AuthCubit(),
        router = createAppRouter(initialLocation: '/admin/users');
    addTearDown(auth.close);
    addTearDown(router.dispose);
    await http.runWithClient(() async {
      await tester.pumpWidget(
        BlocProvider.value(
          value: auth,
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(AdminUsersPage), findsNothing);
      expect(SessionService.isAuthenticated, isFalse);
    }, () => MockClient((_) async => json({}, 401)));
  });

  testWidgets('ciudadano no abre administración ni recibe su lista', (
    tester,
  ) async {
    SessionService.start(token: 'synthetic-citizen', user: citizen);
    final auth = AuthCubit(),
        router = createAppRouter(initialLocation: '/admin/users');
    addTearDown(auth.close);
    addTearDown(router.dispose);
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          BlocProvider.value(
            value: auth,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/profile');
        expect(find.byType(AdminUsersPage), findsNothing);
        expect(find.text('Administrar usuarios'), findsNothing);
      },
      () => MockClient((r) async {
        expect(r.url.path.startsWith('/api/admin'), isFalse);
        return json({'data': citizen.toJson()});
      }),
    );
  });

  for (final width in [360.0, 390.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('lista y detalle sin overflow: ancho $width texto $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = AuthCubit(),
            router = createAppRouter(initialLocation: '/admin/users');
        addTearDown(auth.close);
        addTearDown(router.dispose);
        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              BlocProvider.value(
                value: auth,
                child: MaterialApp.router(
                  theme: AppTheme.lightTheme,
                  routerConfig: router,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            router.go('/admin/users/2');
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byType(AdminUserDetailPage), findsOneWidget);
          },
          () => MockClient((r) async {
            final record = user(name: 'Bruno con un nombre bastante largo')
              ..['email'] =
                  'correolargoparaverificareldiseniodeldetalle@example.test';
            return r.url.path.endsWith('/2')
                ? json({'data': record})
                : page([record]);
          }),
        );
      });
    }
  }
}
