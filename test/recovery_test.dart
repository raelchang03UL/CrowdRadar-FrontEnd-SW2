import 'dart:async';
import 'dart:convert';

import 'package:crowdradar/components/auth_fields.dart';
import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/cubits/login_state.dart';
import 'package:crowdradar/cubits/recovery_cubit.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/login/forgot_password_page.dart';
import 'package:crowdradar/pages/login/login_page.dart';
import 'package:crowdradar/pages/login/reset_password_page.dart';
import 'package:crowdradar/router/app_router.dart';
import 'package:crowdradar/services/recovery_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Valores sintéticos: nunca son credenciales ni enlaces emitidos por un servidor.
final _token = List.filled(64, 'a').join();
final _otherToken = List.filled(64, 'b').join();
const _password = ' <unit-new-only> ';
const _user = UserModel(id: 1, nombre: 'Usuario de prueba');
const _accepted = RecoveryResult(
  success: true,
  message: RecoveryService.requestedMessage,
);
const _valid = RecoveryResult(success: true, message: '');
const _reset = RecoveryResult(
  success: true,
  message: RecoveryService.resetMessage,
);
const _invalid = RecoveryResult(
  success: false,
  message: RecoveryService.invalidLinkMessage,
  invalidToken: true,
);

class _RecoveryDouble extends RecoveryService {
  int requests = 0;
  int validations = 0;
  int resets = 0;
  Future<RecoveryResult> Function()? requestHandler;
  Future<RecoveryResult> Function()? validationHandler;
  Future<RecoveryResult> Function()? resetHandler;

  @override
  Future<RecoveryResult> requestReset({required String email}) {
    requests++;
    return requestHandler?.call() ?? Future.value(_accepted);
  }

  @override
  Future<RecoveryResult> validateToken({required String token}) {
    validations++;
    return validationHandler?.call() ?? Future.value(_valid);
  }

  @override
  Future<RecoveryResult> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) {
    resets++;
    return resetHandler?.call() ?? Future.value(_reset);
  }
}

Future<RecoveryResult> _call(RecoveryService service, String operation) =>
    switch (operation) {
      'forgot' => service.requestReset(email: ' QA@Example.com '),
      'validate' => service.validateToken(token: _token),
      _ => service.resetPassword(
        token: _token,
        newPassword: _password,
        confirmPassword: _password,
      ),
    };

Future<GoRouter> _mount(
  WidgetTester tester, {
  String location = '/forgot-password',
  RecoveryService? service,
  Size size = const Size(390, 844),
  double scale = 1,
  bool keyboard = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  if (keyboard) tester.view.viewInsets = const FakeViewPadding(bottom: 300);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  final auth = AuthCubit();
  final router = createAppRouter(
    initialLocation: location,
    recoveryService: service ?? _RecoveryDouble(),
  );
  addTearDown(auth.close);
  addTearDown(router.dispose);
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
  await tester.pump();
  return router;
}

Future<void> _fillReset(
  WidgetTester tester, {
  String password = _password,
  String? confirmation,
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.first, password);
  await tester.enterText(fields.last, confirmation ?? password);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

void main() {
  setUp(SessionService.clear);
  tearDown(SessionService.clear);

  test(
    'forgot envía email normalizado sin JWT y confirma uniformemente',
    () async {
      SessionService.start(token: 'synthetic-session', user: _user);
      for (final email in [' QA@Example.com ', 'missing@example.com']) {
        final service = RecoveryService(
          client: MockClient((request) async {
            expect(request.url.path, '/api/auth/password/forgot');
            expect(request.method, 'POST');
            expect(
              request.headers.keys.map((key) => key.toLowerCase()),
              isNot(contains('authorization')),
            );
            expect(jsonDecode(request.body), {
              'email': email.trim().toLowerCase(),
            });
            return http.Response(
              jsonEncode({'message': 'private-api-message'}),
              202,
            );
          }),
        );
        final result = await service.requestReset(email: email);
        expect(result.success, true);
        expect(result.message, RecoveryService.requestedMessage);
        expect(SessionService.token, 'synthetic-session');
      }
    },
  );

  test('validate comprueba token real sin JWT ni cambios de sesión', () async {
    final generation = SessionService.generation;
    final service = RecoveryService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/auth/password/reset/validate');
        expect(jsonDecode(request.body), {'token': _token});
        expect(
          request.headers.keys.map((key) => key.toLowerCase()),
          isNot(contains('authorization')),
        );
        return http.Response('{"valid":true}', 200);
      }),
    );
    expect((await service.validateToken(token: _token)).success, true);
    expect(SessionService.generation, generation);
  });

  test(
    'reset conserva espacios exactos y no abre/cierra sesión desde servicio',
    () async {
      SessionService.start(token: 'synthetic-session', user: _user);
      final generation = SessionService.generation;
      final service = RecoveryService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/auth/password/reset');
          expect(jsonDecode(request.body), {
            'token': _token,
            'newPassword': _password,
            'confirmPassword': _password,
          });
          expect(
            request.headers.keys.map((key) => key.toLowerCase()),
            isNot(contains('authorization')),
          );
          return http.Response('{"message":"private-api-message"}', 200);
        }),
      );
      final result = await _call(service, 'reset');
      expect(result.success, true);
      expect(result.message, RecoveryService.resetMessage);
      expect(SessionService.generation, generation);
      expect(SessionService.currentUser, same(_user));
    },
  );

  test('tokens ausentes/malformados se rechazan antes de HTTP', () async {
    var calls = 0;
    final service = RecoveryService(
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 500);
      }),
    );
    for (final token in [
      '',
      ' ',
      'malformed',
      _token.substring(1),
      _token.toUpperCase(),
      '$_token ',
    ]) {
      final validation = await service.validateToken(token: token);
      final reset = await service.resetPassword(
        token: token,
        newPassword: _password,
        confirmPassword: _password,
      );
      expect(validation.invalidToken, true);
      expect(reset.invalidToken, true);
      expect(validation.message, RecoveryService.invalidLinkMessage);
    }
    expect(calls, 0);
  });

  for (final operation in ['forgot', 'validate', 'reset']) {
    for (final entry in [
      (429, 'RATE_LIMITED', RecoveryService.rateLimitMessage),
      (
        503,
        'SERVICE_UNAVAILABLE',
        operation == 'forgot'
            ? RecoveryService.unavailableMessage
            : RecoveryService.serviceError,
      ),
      (400, 'UNKNOWN', RecoveryService.serviceError),
      (500, 'PRIVATE', RecoveryService.serviceError),
    ]) {
      test('$operation sanea ${entry.$1}/${entry.$2}', () async {
        final service = RecoveryService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({'code': entry.$2, 'message': 'private-token-or-sql'}),
              entry.$1,
            ),
          ),
        );
        final result = await _call(service, operation);
        expect(result.success, false);
        expect(result.message, entry.$3);
        expect(result.message, isNot(contains('private')));
      });
    }
    for (final body in [
      'not-json',
      '[]',
      '{}',
      '{"valid":false}',
      '{"valid":"true"}',
    ]) {
      test('$operation rechaza respuesta incompleta $body', () async {
        final service = RecoveryService(
          client: MockClient(
            (_) async => http.Response(body, operation == 'forgot' ? 202 : 200),
          ),
        );
        expect((await _call(service, operation)).success, false);
      });
    }
    test('$operation oculta excepción de red', () async {
      final service = RecoveryService(
        client: MockClient((_) => throw http.ClientException('private-host')),
      );
      expect(
        (await _call(service, operation)).message,
        RecoveryService.connectionError,
      );
    });
    testWidgets('$operation limita espera a 15 segundos', (tester) async {
      final pending = Completer<http.Response>();
      final service = RecoveryService(
        client: MockClient((_) => pending.future),
      );
      final operationFuture = _call(service, operation);
      await tester.pump(const Duration(seconds: 16));
      expect((await operationFuture).message, RecoveryService.connectionError);
      pending.complete(http.Response('{}', 503));
      await tester.pump();
    });
  }

  test(
    'forgot sin proveedor comunica indisponibilidad y nunca éxito',
    () async {
      final service = RecoveryService(
        client: MockClient(
          (_) async => http.Response(
            '{"code":"RECOVERY_UNAVAILABLE","message":"private"}',
            503,
          ),
        ),
      );
      final result = await service.requestReset(email: 'qa@example.com');
      expect(result.success, false);
      expect(result.message, RecoveryService.unavailableMessage);
    },
  );

  for (final operation in ['validate', 'reset']) {
    test('$operation no distingue token inválido/expirado/usado', () async {
      final service = RecoveryService(
        client: MockClient(
          (_) async => http.Response(
            '{"code":"RESET_TOKEN_INVALID","message":"private"}',
            400,
          ),
        ),
      );
      final result = await _call(service, operation);
      expect(result.invalidToken, true);
      expect(result.message, RecoveryService.invalidLinkMessage);
    });
  }

  for (final entry in [
    ('PASSWORD_VALIDATION', 'Revisa las contraseñas.'),
    ('PASSWORD_MISMATCH', 'La confirmación no coincide'),
    ('PASSWORD_REUSED', 'Elige una contraseña diferente'),
  ]) {
    test('reset traduce ${entry.$1}', () async {
      final service = RecoveryService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'code': entry.$1, 'message': 'private'}),
            400,
          ),
        ),
      );
      final result = await _call(service, 'reset');
      expect(result.success, false);
      expect(result.message, startsWith(entry.$2));
      expect(result.invalidToken, false);
    });
  }

  test(
    'forgot bloquea doble envío, confirma una vez y descarta después de cerrar',
    () async {
      final pending = Completer<RecoveryResult>();
      final service = _RecoveryDouble()..requestHandler = () => pending.future;
      final cubit = ForgotPasswordCubit(service: service);
      final operation = cubit.requestReset(email: 'qa@example.com');
      await cubit.requestReset(email: 'qa@example.com');
      expect(service.requests, 1);
      expect(cubit.state, isA<ForgotPasswordLoading>());
      pending.complete(_accepted);
      await operation;
      expect(cubit.state, isA<ForgotPasswordConfirmed>());
      await cubit.requestReset(email: 'qa@example.com');
      expect(service.requests, 1);
      await cubit.close();
    },
  );

  for (final close in [false, true]) {
    test(
      'forgot descarta respuesta con ${close ? 'vista cerrada' : 'sesión nueva'}',
      () async {
        final pending = Completer<RecoveryResult>();
        final service = _RecoveryDouble()
          ..requestHandler = () => pending.future;
        final cubit = ForgotPasswordCubit(service: service);
        final operation = cubit.requestReset(email: 'qa@example.com');
        if (close) {
          await cubit.close();
        } else {
          SessionService.start(token: 'new-synthetic-session', user: _user);
        }
        pending.complete(_accepted);
        await operation;
        expect(cubit.state, isNot(isA<ForgotPasswordConfirmed>()));
        if (!close) await cubit.close();
      },
    );
  }

  test(
    'reset no permite enviar antes de validar y bloquea doble envío',
    () async {
      final checking = Completer<RecoveryResult>();
      final resetting = Completer<RecoveryResult>();
      final service = _RecoveryDouble()
        ..validationHandler = (() => checking.future)
        ..resetHandler = (() => resetting.future);
      final auth = AuthCubit();
      final cubit = ResetPasswordCubit(authCubit: auth, service: service);
      addTearDown(auth.close);
      addTearDown(cubit.close);
      final validation = cubit.validateToken(token: _token);
      await cubit.resetPassword(
        newPassword: _password,
        confirmPassword: _password,
      );
      expect(service.resets, 0);
      checking.complete(_valid);
      await validation;
      final reset = cubit.resetPassword(
        newPassword: _password,
        confirmPassword: _password,
      );
      await cubit.resetPassword(
        newPassword: _password,
        confirmPassword: _password,
      );
      expect(service.resets, 1);
      resetting.complete(_reset);
      await reset;
      expect(cubit.state, isA<ResetPasswordDone>());
      expect(SessionService.isAuthenticated, false);
      expect(auth.state, isA<AuthLoggedOut>());
    },
  );

  for (final close in [false, true]) {
    test(
      'reset exitoso tardío respeta ${close ? 'vista cerrada' : 'nueva generación con JWT repetido'}',
      () async {
        SessionService.start(token: 'synthetic-session', user: _user);
        final pending = Completer<RecoveryResult>();
        final service = _RecoveryDouble()..resetHandler = () => pending.future;
        final auth = AuthCubit();
        final cubit = ResetPasswordCubit(authCubit: auth, service: service);
        addTearDown(auth.close);
        await cubit.validateToken(token: _token);
        final operation = cubit.resetPassword(
          newPassword: _password,
          confirmPassword: _password,
        );
        if (close) {
          await cubit.close();
        } else {
          SessionService.clear();
          SessionService.start(token: 'synthetic-session', user: _user);
        }
        pending.complete(_reset);
        await operation;
        expect(SessionService.currentUser, same(_user));
        expect(SessionService.token, 'synthetic-session');
        expect(cubit.state, isNot(isA<ResetPasswordDone>()));
        if (!close) await cubit.close();
      },
    );
  }

  test('validaciones fuera de orden no habilitan un enlace anterior', () async {
    final pending = Completer<RecoveryResult>();
    final service = _RecoveryDouble()..validationHandler = () => pending.future;
    final auth = AuthCubit();
    final cubit = ResetPasswordCubit(authCubit: auth, service: service);
    addTearDown(auth.close);
    addTearDown(cubit.close);
    final old = cubit.validateToken(token: _token);
    service.validationHandler = () async => _invalid;
    await cubit.validateToken(token: _otherToken);
    pending.complete(_valid);
    await old;
    expect(cubit.state, isA<ResetPasswordLinkError>());
    expect((cubit.state as ResetPasswordLinkError).invalidToken, true);
  });

  test(
    'cambiar enlace durante reset descarta éxito antiguo sin cerrar sesión',
    () async {
      SessionService.start(token: 'synthetic-session', user: _user);
      final pending = Completer<RecoveryResult>();
      final service = _RecoveryDouble()..resetHandler = () => pending.future;
      final auth = AuthCubit();
      final cubit = ResetPasswordCubit(authCubit: auth, service: service);
      addTearDown(auth.close);
      addTearDown(cubit.close);
      await cubit.validateToken(token: _token);
      final old = cubit.resetPassword(
        newPassword: _password,
        confirmPassword: _password,
      );
      await cubit.validateToken(token: _otherToken);
      pending.complete(_reset);
      await old;
      expect(cubit.state, isA<ResetPasswordReady>());
      expect(SessionService.token, 'synthetic-session');
    },
  );

  testWidgets('login ofrece recuperación pública y formulario valida email', (
    tester,
  ) async {
    final service = _RecoveryDouble();
    final router = await _mount(tester, location: '/login', service: service);
    await tester.pumpAndSettle();
    final action = find.text('Recuperar contraseña');
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/forgot-password',
    );
    expect(find.byType(ForgotPasswordPage), findsOneWidget);
    await _tap(tester, 'forgot-password-submit');
    expect(find.textContaining('Escribe un correo válido'), findsOneWidget);
    expect(service.requests, 0);
  });

  testWidgets(
    'forgot conserva campo deshabilitado durante carga y confirma uniforme',
    (tester) async {
      final pending = Completer<RecoveryResult>();
      final service = _RecoveryDouble()..requestHandler = () => pending.future;
      await _mount(tester, service: service);
      await tester.enterText(find.byType(TextFormField), 'qa@example.com');
      await _tap(tester, 'forgot-password-submit');
      expect(service.requests, 1);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        false,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'qa@example.com',
      );
      await _tap(tester, 'forgot-password-submit');
      expect(service.requests, 1);
      pending.complete(_accepted);
      await tester.pumpAndSettle();
      expect(find.text(RecoveryService.requestedMessage), findsOneWidget);
      expect(find.textContaining('registrado'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final message in [
    RecoveryService.rateLimitMessage,
    RecoveryService.unavailableMessage,
  ]) {
    testWidgets('forgot error público conserva email: $message', (
      tester,
    ) async {
      final service = _RecoveryDouble()
        ..requestHandler = () async =>
            RecoveryResult(success: false, message: message);
      await _mount(tester, service: service);
      await tester.enterText(find.byType(TextFormField), 'qa@example.com');
      await _tap(tester, 'forgot-password-submit');
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'qa@example.com',
      );
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        true,
      );
      expect(find.text(RecoveryService.requestedMessage), findsNothing);
    });
  }

  testWidgets(
    'reset no muestra campos antes de verificación real ni para enlace inválido',
    (tester) async {
      final pending = Completer<RecoveryResult>();
      final service = _RecoveryDouble()
        ..validationHandler = () => pending.future;
      final router = await _mount(
        tester,
        location: '/reset-password?token=$_token',
        service: service,
      );
      expect(service.validations, 1);
      expect(find.byType(AuthPasswordField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Comprobando el enlace…'), findsOneWidget);
      pending.complete(_invalid);
      await tester.pumpAndSettle();
      expect(find.text(RecoveryService.invalidLinkMessage), findsOneWidget);
      expect(find.byType(AuthPasswordField), findsNothing);
      expect(find.textContaining(_token), findsNothing);
      expect(
        tester
            .widget<ResetPasswordPage>(find.byType(ResetPasswordPage))
            .toStringDeep(),
        isNot(contains(_token)),
      );
      await tester.tap(find.text('Solicitar otro enlace'));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/forgot-password',
      );
    },
  );

  for (final location in [
    '/reset-password',
    '/reset-password?token=malformed',
  ]) {
    testWidgets('$location no invoca validación HTTP ni muestra campos', (
      tester,
    ) async {
      final service = _RecoveryDouble();
      await _mount(tester, location: location, service: service);
      await tester.pumpAndSettle();
      expect(service.validations, 0);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text(RecoveryService.invalidLinkMessage), findsOneWidget);
    });
  }

  for (final message in [
    RecoveryService.rateLimitMessage,
    RecoveryService.serviceError,
  ]) {
    testWidgets(
      'validación fallida ofrece reintento sin habilitar formulario: $message',
      (tester) async {
        final service = _RecoveryDouble()
          ..validationHandler = () async =>
              RecoveryResult(success: false, message: message);
        await _mount(
          tester,
          location: '/reset-password?token=$_token',
          service: service,
        );
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsNothing);
        expect(find.text(message), findsOneWidget);
        service.validationHandler = () async => _valid;
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(service.validations, 2);
        expect(find.byType(TextFormField), findsNWidgets(2));
      },
    );
  }

  testWidgets('reset valida Unicode/72 bytes y confirmación sin enviar', (
    tester,
  ) async {
    final service = _RecoveryDouble();
    await _mount(
      tester,
      location: '/reset-password?token=$_token',
      service: service,
    );
    await tester.pumpAndSettle();
    for (final password in [
      List.filled(7, '😀').join(),
      List.filled(19, '😀').join(),
    ]) {
      await _fillReset(tester, password: password);
      await _tap(tester, 'reset-password-submit');
      expect(service.resets, 0);
      expect(
        find.textContaining(
          password.runes.length < 8 ? 'Usa al menos 8' : 'No superes 72',
        ),
        findsOneWidget,
      );
    }
    await _fillReset(tester, confirmation: 'different');
    await _tap(tester, 'reset-password-submit');
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    expect(service.resets, 0);
  });

  testWidgets(
    'reset carga estable/doble envío y 429 conservan contraseñas ocultas',
    (tester) async {
      final pending = Completer<RecoveryResult>();
      final service = _RecoveryDouble()..resetHandler = () => pending.future;
      await _mount(
        tester,
        location: '/reset-password?token=$_token',
        service: service,
      );
      await tester.pumpAndSettle();
      await _fillReset(tester);
      await _tap(tester, 'reset-password-submit');
      expect(service.resets, 1);
      expect(find.byType(AuthPasswordField), findsNWidgets(2));
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        expect(field.enabled, false);
        expect(field.controller!.text, _password);
      }
      for (final field in tester.widgetList<EditableText>(
        find.byType(EditableText),
      )) {
        expect(field.obscureText, true);
      }
      await _tap(tester, 'reset-password-submit');
      expect(service.resets, 1);
      pending.complete(
        const RecoveryResult(
          success: false,
          message: RecoveryService.rateLimitMessage,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(RecoveryService.rateLimitMessage), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        _password,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'token consumido al guardar retira formulario y permite pedir otro',
    (tester) async {
      final service = _RecoveryDouble()..resetHandler = () async => _invalid;
      await _mount(
        tester,
        location: '/reset-password?token=$_token',
        service: service,
      );
      await tester.pumpAndSettle();
      await _fillReset(tester);
      await _tap(tester, 'reset-password-submit');
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text(RecoveryService.invalidLinkMessage), findsOneWidget);
      expect(find.text('Solicitar otro enlace'), findsOneWidget);
    },
  );

  testWidgets('reset exitoso borra sesión/URL y vuelve a login sin autologin', (
    tester,
  ) async {
    SessionService.start(token: 'synthetic-session', user: _user);
    final router = await _mount(
      tester,
      location: '/reset-password?token=$_token',
    );
    await tester.pumpAndSettle();
    await _fillReset(tester);
    await _tap(tester, 'reset-password-submit');
    await tester.pumpAndSettle();
    expect(SessionService.token, isNull);
    expect(SessionService.currentUser, isNull);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/login?notice=passwordReset',
    );
    expect(router.canPop(), false);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text(RecoveryService.resetMessage), findsOneWidget);
    expect(find.byType(ResetPasswordPage), findsNothing);
    expect(find.textContaining(_token), findsNothing);
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(field.controller!.text, isEmpty);
    }
    for (final route in [
      '/map',
      '/validar',
      '/favoritos',
      '/profile',
      '/profile/edit',
      '/profile/password',
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('cambio de query revalida enlace y limpia campos anteriores', (
    tester,
  ) async {
    final service = _RecoveryDouble();
    final router = await _mount(
      tester,
      location: '/reset-password?token=$_token',
      service: service,
    );
    await tester.pumpAndSettle();
    await _fillReset(tester);
    service.validationHandler = () async => _invalid;
    router.go('/reset-password?token=$_otherToken');
    await tester.pumpAndSettle();
    expect(service.validations, 2);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text(RecoveryService.invalidLinkMessage), findsOneWidget);
  });

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final reset in [false, true]) {
        testWidgets(
          '${reset ? 'reset' : 'forgot'} $size texto $scale sin overflow y acción alcanzable',
          (tester) async {
            await _mount(
              tester,
              location: reset
                  ? '/reset-password?token=$_token'
                  : '/forgot-password',
              size: size,
              scale: scale,
            );
            await tester.pumpAndSettle();
            final button = find.byKey(
              ValueKey(
                reset ? 'reset-password-submit' : 'forgot-password-submit',
              ),
            );
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            expect(button.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final reset in [false, true]) {
    testWidgets(
      '${reset ? 'reset' : 'forgot'} teclado y done envían una sola vez',
      (tester) async {
        final pending = Completer<RecoveryResult>();
        final service = _RecoveryDouble()
          ..resetHandler = (() => pending.future)
          ..requestHandler = (() => pending.future);
        await _mount(
          tester,
          location: reset
              ? '/reset-password?token=$_token'
              : '/forgot-password',
          service: service,
          size: const Size(360, 800),
          keyboard: true,
        );
        await tester.pumpAndSettle();
        if (reset) {
          await _fillReset(tester);
        } else {
          await tester.enterText(find.byType(TextFormField), 'qa@example.com');
        }
        await tester.ensureVisible(find.byType(TextFormField).last);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(reset ? service.resets : service.requests, 1);
        expect(tester.takeException(), isNull);
        pending.complete(
          const RecoveryResult(
            success: false,
            message: RecoveryService.connectionError,
          ),
        );
        await tester.pumpAndSettle();
      },
    );
  }
}
