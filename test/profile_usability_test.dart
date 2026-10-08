import 'dart:async';
import 'dart:convert';

import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/cubits/profile/profile_cubit.dart';
import 'package:crowdradar/cubits/profile/profile_state.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/profile/edit_profile_page.dart';
import 'package:crowdradar/pages/profile/profile_page.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/services/user_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _user = UserModel(
  id: 1,
  nombre: 'Rael',
  apellido: 'Chang',
  email: 'widget@example.test',
  telefono: '900000000',
  distrito: 'Miraflores',
  rol: 'ciudadano',
  status: 'activo',
);

class _UserStub extends UserService {
  int loads = 0;
  int updates = 0;
  Future<GenericResponse<UserModel>> Function()? load;
  Future<GenericResponse<UserModel>> Function()? update;

  @override
  Future<GenericResponse<UserModel>> getProfile() {
    loads++;
    return load?.call() ??
        Future.value(const GenericResponse(success: true, data: _user));
  }

  @override
  Future<GenericResponse<UserModel>> updateProfile(
    Map<String, dynamic> changes,
  ) {
    updates++;
    return update?.call() ??
        Future.value(const GenericResponse(success: true, data: _user));
  }
}

void main() {
  setUp(() {
    SessionService.clear();
    SessionService.start(token: 'widget-test-session', user: _user);
  });
  tearDown(SessionService.clear);

  test('sin sesión no consulta ni actualiza el perfil por HTTP', () async {
    SessionService.clear();
    var requests = 0;
    await http.runWithClient(
      () async {
        expect((await UserService().getProfile()).success, false);
        expect(
          (await UserService().updateProfile({'nombre': 'Rael'})).success,
          false,
        );
        expect(requests, 0);
      },
      () => MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
  });

  for (final updating in [false, true]) {
    Future<GenericResponse<UserModel>> request() => updating
        ? UserService().updateProfile({'nombre': 'Rael'})
        : UserService().getProfile();

    test(
      '${updating ? 'guardar' : 'cargar'} sanea una excepción de red',
      () async {
        await http.runWithClient(
          () async {
            final result = await request();
            expect(result.success, false);
            expect(result.message, UserService.connectionError);
            expect(result.message, isNot(contains('internal-host')));
          },
          () => MockClient((_) => throw http.ClientException('internal-host')),
        );
      },
    );

    testWidgets(
      '${updating ? 'guardar' : 'cargar'} tiene límite de espera de 15 segundos',
      (tester) async {
        final pending = Completer<http.Response>();
        await http.runWithClient(() async {
          final result = request();
          await tester.pump(const Duration(seconds: 16));
          expect((await result).message, UserService.connectionError);
          pending.complete(http.Response('{}', 500));
          await tester.pump();
        }, () => MockClient((_) => pending.future));
      },
    );

    for (final status in [400, 401, 404, 500]) {
      test(
        '${updating ? 'guardar' : 'cargar'} no muestra cuerpo HTTP $status',
        () async {
          await http.runWithClient(
            () async {
              final result = await request();
              expect(result.success, false);
              expect(result.message, isNotEmpty);
              expect(result.message, isNot(contains('SQL-private')));
            },
            () => MockClient(
              (_) async =>
                  http.Response(jsonEncode({'message': 'SQL-private'}), status),
            ),
          );
        },
      );
    }

    for (final body in ['not-json', '{}', '{"data":{"id":"invalid"}}']) {
      test(
        '${updating ? 'guardar' : 'cargar'} rechaza una respuesta inválida $body',
        () async {
          await http.runWithClient(() async {
            final result = await request();
            expect(result.success, false);
            expect(result.message, UserService.invalidResponse);
            expect(SessionService.currentUser, same(_user));
          }, () => MockClient((_) async => http.Response(body, 200)));
        },
      );
    }
  }

  test(
    'el cubit bloquea envíos dobles y no emite datos de una sesión anterior',
    () async {
      final pending = Completer<GenericResponse<UserModel>>();
      final service = _UserStub()..update = () => pending.future;
      final cubit = ProfileCubit(service);
      addTearDown(cubit.close);
      final operation = cubit.updateProfile({'nombre': 'Rael'});
      await cubit.updateProfile({'nombre': 'Segundo envío'});
      await cubit.loadProfile();
      expect(service.updates, 1);
      expect(service.loads, 0);
      SessionService.clear();
      pending.complete(const GenericResponse(success: true, data: _user));
      await operation;
      expect(cubit.state, isNot(isA<ProfileLoaded>()));
      expect(SessionService.currentUser, isNull);
    },
  );

  test('un servicio que lanza no publica la excepción en el cubit', () async {
    final service = _UserStub()..load = () => throw StateError('SQL-private');
    final cubit = ProfileCubit(service);
    addTearDown(cubit.close);
    await cubit.loadProfile();
    expect((cubit.state as ProfileError).message, UserService.connectionError);
  });

  testWidgets(
    'edición conserva campos, impide doble envío y permite corregir tras error',
    (tester) async {
      final pending = Completer<GenericResponse<UserModel>>();
      final service = _UserStub()..update = () => pending.future;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EditProfilePage(user: _user, userService: service),
        ),
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'Rael corregido');
      final save = find.widgetWithText(ElevatedButton, 'Guardar cambios');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      expect(fields, findsNWidgets(5));
      expect(
        tester.widget<TextFormField>(fields.first).controller!.text,
        'Rael corregido',
      );
      expect(tester.widget<TextFormField>(fields.first).enabled, false);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(service.updates, 1);
      pending.complete(
        const GenericResponse(
          success: false,
          message: UserService.connectionError,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(UserService.connectionError), findsOneWidget);
      expect(tester.widget<TextFormField>(fields.first).enabled, true);
      expect(
        tester.widget<TextFormField>(fields.first).controller!.text,
        'Rael corregido',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'edición directa carga datos, reintenta y guarda sin necesitar historial',
    (tester) async {
      final service = _UserStub()
        ..load = () async => const GenericResponse(
          success: false,
          message: UserService.connectionError,
        );
      final router = GoRouter(
        initialLocation: '/profile/edit',
        routes: [
          GoRoute(
            path: '/profile/edit',
            builder: (_, _) => EditProfilePage(userService: service),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const Scaffold(body: Text('Perfil de retorno')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(router.canPop(), false);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text(UserService.connectionError), findsOneWidget);
      service.load = () async =>
          const GenericResponse(success: true, data: _user);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reintentar'));
      await tester.pumpAndSettle();
      expect(service.loads, 2);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Rael',
      );
      final save = find.widgetWithText(ElevatedButton, 'Guardar cambios');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(service.updates, 1);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/profile');
      expect(find.text('Perfil actualizado correctamente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('edición directa permite volver a perfil sin pila anterior', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/profile/edit',
      routes: [
        GoRoute(
          path: '/profile/edit',
          builder: (_, _) =>
              EditProfilePage(user: _user, userService: _UserStub()),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, _) => const Scaffold(body: Text('Perfil de retorno')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/profile');
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final editing in [false, true]) {
        testWidgets(
          '${editing ? 'edición' : 'perfil'} $size texto $scale conserva acciones sin overflow',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final cubit = AuthCubit();
            addTearDown(cubit.close);
            await tester.pumpWidget(
              BlocProvider.value(
                value: cubit,
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: editing
                      ? EditProfilePage(user: _user, userService: _UserStub())
                      : ProfilePage(userService: _UserStub()),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final action = find.text(
              editing ? 'Guardar cambios' : 'Cerrar sesión',
            );
            await tester.scrollUntilVisible(
              action,
              250,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            expect(action.hitTestable(), findsOneWidget);
            if (editing) {
              expect(
                tester
                    .widget<TextFormField>(find.byType(TextFormField).at(2))
                    .enabled,
                false,
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'edición con teclado visible permite desplazarse y enviar por acción done',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final pending = Completer<GenericResponse<UserModel>>();
      final service = _UserStub()..update = () => pending.future;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EditProfilePage(user: _user, userService: service),
        ),
      );
      final district = find.byType(TextFormField).last;
      await tester.ensureVisible(district);
      await tester.enterText(district, 'Miraflores');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(service.updates, 1);
      expect(find.byType(TextFormField), findsNWidgets(5));
      expect(tester.takeException(), isNull);
      pending.complete(
        const GenericResponse(
          success: false,
          message: UserService.connectionError,
        ),
      );
      await tester.pumpAndSettle();
    },
  );
}
