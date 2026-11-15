import 'dart:async';
import 'dart:convert';
import 'package:crowdradar/components/auth_fields.dart';
import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/cubits/login_state.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/login/login_page.dart';
import 'package:crowdradar/pages/register/register_page.dart';
import 'package:crowdradar/services/auth_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _PendingAuth extends AuthService {
  final response = Completer<GenericResponse<UserModel>>();
  int calls = 0;
  @override
  Future<GenericResponse<UserModel>> login(String email, String password) {
    calls++;
    return response.future;
  }

  @override
  Future<GenericResponse<UserModel>> register({
    required String nombre,
    required String apellido,
    required String email,
    required String password,
    required String telefono,
    required String distrito,
  }) {
    calls++;
    return response.future;
  }
}

void main() {
  setUp(SessionService.clear);
  tearDown(SessionService.clear);
  Future<GenericResponse<UserModel>> register(AuthService service) =>
      service.register(
        nombre: 'Rael',
        apellido: 'Chang',
        email: 'unit@example.test',
        password: '<solo-prueba-unitaria>',
        telefono: '900000000',
        distrito: 'Miraflores',
      );

  test(
    'valida todos los requisitos y cuenta bytes UTF-8, sin inventar distritos',
    () {
      expect(AuthValidation.name(' '), isNotNull);
      expect(AuthValidation.name('Rael'), isNull);
      for (final email in ['', 'a@', 'a b@correo.com', 'a@correo']) {
        expect(AuthValidation.email(email), isNotNull);
      }
      expect(AuthValidation.email('test@example.test'), isNull);
      for (final password in [
        '',
        'corta',
        '        ',
        List.filled(37, 'é').join(),
      ]) {
        expect(AuthValidation.password(password), isNotNull);
      }
      expect(AuthValidation.password(List.filled(36, 'é').join()), isNull);
      expect(AuthValidation.phone('123'), isNotNull);
      expect(AuthValidation.phone('900000000'), isNull);
    },
  );

  for (final registering in [false, true]) {
    test(
      'HTTP ${registering ? 'registro' : 'login'} oculta excepciones de red',
      () async {
        await http.runWithClient(
          () async {
            final result = registering
                ? await register(AuthService())
                : await AuthService().login(
                    'unit@example.test',
                    '<solo-prueba-unitaria>',
                  );
            expect(result.success, false);
            expect(result.message, AuthService.connectionError);
            expect(result.message, isNot(contains('SocketException')));
          },
          () => MockClient(
            (_) => throw http.ClientException('SocketException: internal-host'),
          ),
        );
      },
    );
    for (final response in [
      http.Response('internal SQL host', 500),
      http.Response('invalid-json', registering ? 201 : 200),
      http.Response('{}', registering ? 201 : 200),
    ]) {
      test(
        'HTTP ${registering ? 'registro' : 'login'} sanea respuesta ${response.statusCode}/${response.body}',
        () async {
          await http.runWithClient(() async {
            final result = registering
                ? await register(AuthService())
                : await AuthService().login(
                    'unit@example.test',
                    '<solo-prueba-unitaria>',
                  );
            expect(result.success, false);
            expect([
              AuthService.serverError,
              AuthService.invalidResponse,
            ], contains(result.message));
            expect(result.message, isNot(contains('internal')));
            expect(SessionService.token, isNull);
          }, () => MockClient((_) async => response));
        },
      );
    }
  }
  test(
    'correo repetido y credenciales incorrectas tienen mensajes públicos',
    () async {
      await http.runWithClient(
        () async {
          expect(
            (await register(AuthService())).message,
            contains('El correo ya está registrado'),
          );
          expect(
            (await AuthService().login(
              'unit@example.test',
              '<solo-prueba-unitaria>',
            )).message,
            'Correo o contraseña incorrectos.',
          );
        },
        () => MockClient(
          (request) async => request.url.path.endsWith('/register')
              ? http.Response(
                  jsonEncode({'message': 'El correo ya está registrado.'}),
                  400,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                )
              : http.Response('internal detail', 401),
        ),
      );
    },
  );

  test(
    'login reconoce suspensión y usa un mensaje público sin crear sesión',
    () async {
      await http.runWithClient(
        () async {
          final result = await AuthService().login(
            'unit@example.test',
            'synthetic-password',
          );
          expect(result.success, false);
          expect(result.error, 'ACCOUNT_SUSPENDED');
          expect(
            result.message,
            'Tu cuenta está suspendida. Un administrador debe reactivarla para que puedas volver a ingresar.',
          );
          expect(SessionService.isAuthenticated, false);
        },
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'code': 'ACCOUNT_SUSPENDED',
              'message': 'internal SQL detail must not be displayed',
            }),
            403,
          ),
        ),
      );
    },
  );

  test('login no confunde errores desconocidos con suspensión', () async {
    for (final response in [
      http.Response(jsonEncode({'code': 'ACCOUNT_SUSPENDED'}), 401),
      http.Response(
        jsonEncode({'code': 'OTHER', 'message': 'private detail'}),
        403,
      ),
      http.Response('invalid private detail', 403),
    ]) {
      await http.runWithClient(() async {
        final result = await AuthService().login(
          'unit@example.test',
          'synthetic-password',
        );
        expect(result.success, false);
        expect(result.error, isNot('ACCOUNT_SUSPENDED'));
        expect(
          result.message,
          response.statusCode == 401
              ? 'Correo o contraseña incorrectos.'
              : AuthService.serverError,
        );
        expect(SessionService.isAuthenticated, false);
      }, () => MockClient((_) async => response));
    }
  });

  testWidgets(
    'login muestra suspensión conservando el formulario y sin ingresar',
    (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: BlocProvider(
                create: (_) => AuthCubit(),
                child: const LoginPage(),
              ),
            ),
          );
          await tester.enterText(
            find.byType(TextFormField).at(0),
            'unit@example.test',
          );
          await tester.enterText(
            find.byType(TextFormField).at(1),
            'synthetic-password',
          );
          await tester.ensureVisible(
            find.widgetWithText(ElevatedButton, 'Iniciar sesión'),
          );
          await tester.tap(
            find.widgetWithText(ElevatedButton, 'Iniciar sesión'),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              'Tu cuenta está suspendida. Un administrador debe reactivarla para que puedas volver a ingresar.',
            ),
            findsOneWidget,
          );
          expect(find.text('unit@example.test'), findsOneWidget);
          expect(SessionService.isAuthenticated, false);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient(
          (_) async =>
              http.Response(jsonEncode({'code': 'ACCOUNT_SUSPENDED'}), 403),
        ),
      );
    },
  );

  for (final registering in [false, true]) {
    testWidgets(
      '${registering ? 'registro' : 'login'} mantiene formulario, bloquea doble envío y muestra error estable',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = _PendingAuth();
        final cubit = AuthCubit(authService: service);
        addTearDown(cubit.close);
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: registering ? const RegisterPage() : const LoginPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final fields = find.byType(TextFormField);
        final values = registering
            ? [
                'Rael',
                'Chang',
                'unit@example.test',
                '<solo-prueba-unitaria>',
                '900000000',
                'Miraflores',
              ]
            : ['unit@example.test', '<solo-prueba-unitaria>'];
        for (var i = 0; i < values.length; i++) {
          await tester.enterText(fields.at(i), values[i]);
        }
        final button = find.byType(ElevatedButton);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        expect(fields, findsNWidgets(values.length));
        expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
        expect(
          tester.widget<TextFormField>(fields.first).controller!.text,
          values.first,
        );
        expect(tester.widget<TextFormField>(fields.first).enabled, false);
        if (registering) {
          await cubit.register(
            nombre: 'Rael',
            apellido: 'Chang',
            email: values[2],
            password: values[3],
            telefono: values[4],
            distrito: values[5],
          );
        } else {
          await cubit.login(values[0], values[1]);
        }
        expect(service.calls, 1);
        service.response.complete(
          const GenericResponse(
            success: false,
            message: AuthService.connectionError,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(AuthService.connectionError), findsOneWidget);
        expect(tester.widget<TextFormField>(fields.first).enabled, true);
        expect(tester.takeException(), isNull);
        if (registering) {
          await tester.pumpWidget(
            BlocProvider.value(
              value: cubit,
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const LoginPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(AuthService.connectionError), findsNothing);
        }
      },
    );
  }

  testWidgets(
    'contraseña oculta por defecto; mostrar/ocultar no cambia su contenido',
    (tester) async {
      final controller = TextEditingController(text: '<solo-prueba-unitaria>');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AuthPasswordField(controller: controller)),
        ),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        true,
      );
      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        false,
      );
      await tester.tap(find.byTooltip('Ocultar contraseña'));
      await tester.pumpAndSettle();
      expect(controller.text, '<solo-prueba-unitaria>');
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        true,
      );
    },
  );

  test(
    'registro pendiente no emite después de logout ni sobre un cubit cerrado',
    () async {
      for (final close in [false, true]) {
        final service = _PendingAuth();
        final cubit = AuthCubit(authService: service);
        final pending = cubit.register(
          nombre: 'Rael',
          apellido: 'Chang',
          email: 'unit@example.test',
          password: '<solo-prueba-unitaria>',
          telefono: '900000000',
          distrito: 'Miraflores',
        );
        if (close) {
          await cubit.close();
        } else {
          cubit.logout();
        }
        service.response.complete(
          const GenericResponse(success: true, data: UserModel(id: 1)),
        );
        await expectLater(pending, completes);
        if (!close) {
          expect(cubit.state, isA<AuthLoggedOut>());
          await cubit.close();
        }
        expect(SessionService.isAuthenticated, false);
      }
    },
  );
}
