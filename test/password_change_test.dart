import 'dart:async';
import 'dart:convert';

import 'package:crowdradar/components/auth_fields.dart';
import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/cubits/login_state.dart';
import 'package:crowdradar/cubits/password_change_cubit.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/login/login_page.dart';
import 'package:crowdradar/pages/profile/change_password_page.dart';
import 'package:crowdradar/router/app_router.dart';
import 'package:crowdradar/services/password_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _user = UserModel(id: 1, nombre: 'Prueba', apellido: 'Local');
const _current = '<unit-current-only>';
const _next = ' <unit-next-only> ';
const _changed = PasswordChangeResult(
  success: true,
  message: PasswordService.changedMessage,
);

class _PendingPassword extends PasswordService {
  final response = Completer<PasswordChangeResult>();
  int calls = 0;
  @override
  Future<PasswordChangeResult> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    calls++;
    return response.future;
  }
}

Future<PasswordChangeResult> _request() => PasswordService().changePassword(
  currentPassword: _current,
  newPassword: _next,
  confirmPassword: _next,
);

Future<void> _fill(
  WidgetTester tester, {
  String current = _current,
  String next = _next,
  String? confirmation,
}) async {
  final fields = find.byType(TextFormField);
  for (final entry in [(0, current), (1, next), (2, confirmation ?? next)]) {
    await tester.enterText(fields.at(entry.$1), entry.$2);
  }
}

void main() {
  setUp(() {
    SessionService.clear();
    SessionService.start(token: 'unit-password-session', user: _user);
  });
  tearDown(SessionService.clear);

  test('la validación cuenta caracteres Unicode, no unidades UTF-16', () {
    expect(AuthValidation.password(List.filled(7, '😀').join()), isNotNull);
    expect(AuthValidation.password(List.filled(8, '😀').join()), isNull);
    expect(AuthValidation.password(List.filled(18, '😀').join()), isNull);
    expect(AuthValidation.password(List.filled(19, '😀').join()), isNotNull);
  });

  test('sin sesión no realiza HTTP', () async {
    SessionService.clear();
    var calls = 0;
    await http.runWithClient(
      () async {
        final result = await _request();
        expect(result.success, false);
        expect(result.sessionInvalid, true);
        expect(calls, 0);
      },
      () => MockClient((_) async {
        calls++;
        return http.Response('{}', 500);
      }),
    );
  });

  test(
    'envía contrato y espacios exactos con JWT; el servicio no muta sesión',
    () async {
      await http.runWithClient(
        () async {
          final generation = SessionService.generation;
          final result = await _request();
          expect(result.success, true);
          expect(result.message, PasswordService.changedMessage);
          expect(SessionService.generation, generation);
          expect(SessionService.currentUser, same(_user));
        },
        () => MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/auth/password/change');
          expect(
            request.headers['Authorization'],
            'Bearer unit-password-session',
          );
          expect(jsonDecode(request.body), {
            'currentPassword': _current,
            'newPassword': _next,
            'confirmPassword': _next,
          });
          return http.Response(
            jsonEncode({'message': 'private-message-never-shown'}),
            200,
          );
        }),
      );
    },
  );

  for (final entry in [
    (400, 'PASSWORD_VALIDATION', 'Revisa las contraseñas.'),
    (400, 'PASSWORD_MISMATCH', 'La confirmación no coincide'),
    (400, 'PASSWORD_REUSED', 'Elige una contraseña diferente'),
    (403, 'CURRENT_PASSWORD_INVALID', 'La contraseña actual no es correcta.'),
    (401, 'SESSION_INVALID', PasswordService.sessionError),
    (503, 'SERVICE_UNAVAILABLE', PasswordService.serviceError),
    (400, 'UNKNOWN', PasswordService.serviceError),
  ]) {
    test(
      'traduce ${entry.$1}/${entry.$2} sin publicar cuerpos internos',
      () async {
        await http.runWithClient(
          () async {
            final result = await _request();
            expect(result.success, false);
            expect(result.message, startsWith(entry.$3));
            expect(result.message, isNot(contains('private-message')));
            expect(result.sessionInvalid, entry.$2 == 'SESSION_INVALID');
          },
          () => MockClient(
            (_) async => http.Response(
              jsonEncode({'code': entry.$2, 'message': 'private-message'}),
              entry.$1,
            ),
          ),
        );
      },
    );
  }

  for (final response in [
    http.Response('not-json', 200),
    http.Response('{}', 200),
    http.Response('[]', 200),
    http.Response('{}', 401),
  ]) {
    test(
      'rechaza contrato inválido ${response.statusCode}/${response.body}',
      () async {
        await http.runWithClient(() async {
          final result = await _request();
          expect(result.success, false);
          expect(result.message, PasswordService.serviceError);
          expect(result.sessionInvalid, false);
        }, () => MockClient((_) async => response));
      },
    );
  }

  test('red devuelve mensaje público sin excepción', () async {
    await http.runWithClient(() async {
      expect((await _request()).message, PasswordService.connectionError);
    }, () => MockClient((_) => throw http.ClientException('private-host')));
  });

  testWidgets('tiempo de espera máximo 15 segundos', (tester) async {
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      final operation = _request();
      await tester.pump(const Duration(seconds: 16));
      expect((await operation).message, PasswordService.connectionError);
      pending.complete(http.Response('{}', 503));
      await tester.pump();
    }, () => MockClient((_) => pending.future));
  });

  for (final result in [
    _changed,
    const PasswordChangeResult(
      success: false,
      message: PasswordService.sessionError,
      sessionInvalid: true,
    ),
  ]) {
    test(
      'cubit ${result.success ? 'éxito' : '401'} borra sesión y bloquea envío doble',
      () async {
        final service = _PendingPassword();
        final auth = AuthCubit();
        final cubit = PasswordChangeCubit(authCubit: auth, service: service);
        addTearDown(auth.close);
        addTearDown(cubit.close);
        final operation = cubit.changePassword(
          currentPassword: _current,
          newPassword: _next,
          confirmPassword: _next,
        );
        await cubit.changePassword(
          currentPassword: _current,
          newPassword: _next,
          confirmPassword: _next,
        );
        expect(service.calls, 1);
        service.response.complete(result);
        await operation;
        expect(SessionService.token, isNull);
        expect(SessionService.currentUser, isNull);
        expect(auth.state, isA<AuthLoggedOut>());
        expect(
          (cubit.state as PasswordChangeSignedOut).changed,
          result.success,
        );
      },
    );

    test(
      'respuesta antigua ${result.success ? 'éxito' : '401'} no cierra otra sesión aunque repita JWT',
      () async {
        final service = _PendingPassword();
        final auth = AuthCubit();
        final cubit = PasswordChangeCubit(authCubit: auth, service: service);
        addTearDown(auth.close);
        addTearDown(cubit.close);
        final operation = cubit.changePassword(
          currentPassword: _current,
          newPassword: _next,
          confirmPassword: _next,
        );
        SessionService.clear();
        const replacement = UserModel(id: 2, nombre: 'Otra sesión');
        SessionService.start(token: 'unit-password-session', user: replacement);
        service.response.complete(result);
        await operation;
        expect(SessionService.currentUser, same(replacement));
        expect(SessionService.isAuthenticated, true);
        expect(cubit.state, isNot(isA<PasswordChangeSignedOut>()));
      },
    );
  }

  test('respuesta después de cerrar el cubit no cierra la sesión', () async {
    final service = _PendingPassword();
    final auth = AuthCubit();
    final cubit = PasswordChangeCubit(authCubit: auth, service: service);
    addTearDown(auth.close);
    final operation = cubit.changePassword(
      currentPassword: _current,
      newPassword: _next,
      confirmPassword: _next,
    );
    await cubit.close();
    service.response.complete(_changed);
    await expectLater(operation, completes);
    expect(SessionService.isAuthenticated, true);
  });

  testWidgets(
    'campos ocultos, formulario estable, botones bloqueados y error corregible',
    (tester) async {
      final service = _PendingPassword();
      final auth = AuthCubit();
      addTearDown(auth.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: auth,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: ChangePasswordPage(service: service),
          ),
        ),
      );
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((field) => field.obscureText),
        true,
      );
      await tester.tap(find.byTooltip('Mostrar contraseña actual'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).obscureText,
        false,
      );
      await tester.tap(find.byTooltip('Ocultar contraseña actual'));
      await tester.pump();
      await _fill(tester);
      final save = find.byKey(const ValueKey('change-password-submit'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      expect(service.calls, 1);
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(tester.widget<ElevatedButton>(save).onPressed, isNull);
      expect(
        tester
            .widgetList<TextFormField>(find.byType(TextFormField))
            .every((field) => !field.enabled),
        true,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        _next,
      );
      service.response.complete(
        const PasswordChangeResult(
          success: false,
          message: 'La contraseña actual no es correcta.',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('La contraseña actual no es correcta.'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(save).onPressed, isNotNull);
      expect(SessionService.isAuthenticated, true);
      expect(tester.takeException(), isNull);
    },
  );

  for (final input in [
    ('', _next, _next),
    (_current, 'corta', 'corta'),
    (_current, List.filled(37, 'é').join(), List.filled(37, 'é').join()),
    (_current, _current, _current),
    (_current, _next, 'otra confirmación'),
    (_current, '        ', '        '),
  ]) {
    testWidgets(
      'validación impide envío inválido caso ${input.$1.isEmpty
          ? 'actual vacía'
          : input.$2 == _current
          ? 'reutilizada'
          : input.$3 != input.$2
          ? 'confirmación'
          : utf8.encode(input.$2).length > 72
          ? 'bytes'
          : input.$2.trim().isEmpty
          ? 'espacios'
          : 'corta'}',
      (tester) async {
        final service = _PendingPassword();
        final auth = AuthCubit();
        addTearDown(auth.close);
        await tester.pumpWidget(
          BlocProvider.value(
            value: auth,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: ChangePasswordPage(service: service),
            ),
          ),
        );
        await _fill(
          tester,
          current: input.$1,
          next: input.$2,
          confirmation: input.$3,
        );
        final save = find.byKey(const ValueKey('change-password-submit'));
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(service.calls, 0);
        expect(find.byType(TextFormField), findsNWidgets(3));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('ruta nueva protegida después de logout y ante entrada directa', (
    tester,
  ) async {
    SessionService.clear();
    final auth = AuthCubit();
    final router = createAppRouter(initialLocation: '/profile/password');
    addTearDown(auth.close);
    addTearDown(router.dispose);
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
    expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
    SessionService.start(token: 'unit-password-session', user: _user);
    router.go('/profile/password');
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordPage), findsOneWidget);
    auth.logout();
    await tester.pumpAndSettle();
    router.go('/profile/password');
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
    expect(find.byType(ChangePasswordPage), findsNothing);
  });

  testWidgets(
    'éxito real del cubit limpia sesión y redirige mostrando aviso fijo',
    (tester) async {
      final service = _PendingPassword();
      final auth = AuthCubit();
      final router = GoRouter(
        initialLocation: '/profile/password',
        refreshListenable: SessionService.changes,
        redirect: (_, state) =>
            !SessionService.isAuthenticated && state.uri.path != '/login'
            ? '/login'
            : null,
        routes: [
          GoRoute(
            path: '/profile/password',
            builder: (_, _) => ChangePasswordPage(service: service),
          ),
          GoRoute(
            path: '/login',
            builder: (_, state) => LoginPage(
              notice: state.uri.queryParameters['notice'] == 'passwordChanged'
                  ? LoginNotice.passwordChanged
                  : null,
            ),
          ),
        ],
      );
      addTearDown(auth.close);
      addTearDown(router.dispose);
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
      await _fill(tester);
      final save = find.byKey(const ValueKey('change-password-submit'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      service.response.complete(_changed);
      await tester.pumpAndSettle();
      expect(SessionService.token, isNull);
      expect(SessionService.currentUser, isNull);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/login?notice=passwordChanged',
      );
      expect(find.text(PasswordService.changedMessage), findsOneWidget);
      expect(find.byType(ChangePasswordPage), findsNothing);
      router.go('/profile/password');
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'cambio contraseña $size texto $scale no desborda y permite alcanzar guardar',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final auth = AuthCubit();
          addTearDown(auth.close);
          await tester.pumpWidget(
            BlocProvider.value(
              value: auth,
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const ChangePasswordPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final save = find.byKey(const ValueKey('change-password-submit'));
          await tester.ensureVisible(save);
          expect(save.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('teclado visible y acción done envían una sola vez', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final auth = AuthCubit();
    addTearDown(auth.close);
    final service = _PendingPassword();
    await tester.pumpWidget(
      BlocProvider.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: ChangePasswordPage(service: service),
        ),
      ),
    );
    await _fill(tester);
    await tester.ensureVisible(find.byType(TextFormField).last);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(service.calls, 1);
    expect(tester.takeException(), isNull);
    service.response.complete(
      const PasswordChangeResult(
        success: false,
        message: PasswordService.connectionError,
      ),
    );
    await tester.pumpAndSettle();
  });
}
