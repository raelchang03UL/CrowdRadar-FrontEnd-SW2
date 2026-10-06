import 'dart:async';
import 'dart:convert';

import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/cubits/login_state.dart';
import 'package:crowdradar/cubits/profile/profile_cubit.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/services/user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const user = UserModel(id: 1, nombre: 'Usuario de prueba');

  setUp(SessionService.clear);
  tearDown(SessionService.clear);

  test('un login pendiente no restaura la sesión después de logout', () async {
    final requested = Completer<void>();
    final response = Completer<http.Response>();
    await http.runWithClient(
      () async {
        final cubit = AuthCubit();
        addTearDown(cubit.close);
        final login = cubit.login('test@example.com', 'test-only-password');
        await requested.future;
        cubit.logout();
        response.complete(
          http.Response(
            jsonEncode({
              'data': {'token': 'test-session', 'user': user.toJson()},
            }),
            200,
          ),
        );
        await login;

        expect(SessionService.token, isNull);
        expect(SessionService.currentUser, isNull);
        expect(SessionService.isAuthenticated, isFalse);
        expect(cubit.state, isA<AuthLoggedOut>());
      },
      () => MockClient((request) {
        expect(request.method, 'POST');
        requested.complete();
        return response.future;
      }),
    );
  });

  test(
    'una actualización antigua se descarta incluso si el JWT se repite',
    () async {
      final requested = Completer<void>();
      final response = Completer<http.Response>();
      await http.runWithClient(
        () async {
          SessionService.start(token: 'reused-test-token', user: user);
          final update = UserService().updateProfile({
            'nombre': 'Respuesta antigua',
          });
          await requested.future;
          SessionService.clear();
          const newUser = UserModel(id: 1, nombre: 'Sesión nueva');
          SessionService.start(token: 'reused-test-token', user: newUser);
          response.complete(
            http.Response(
              jsonEncode({
                'data': user.copyWith(nombre: 'Respuesta antigua').toJson(),
              }),
              200,
            ),
          );
          final result = await update;

          expect(result.success, isFalse);
          expect(result.data, isNull);
          expect(SessionService.currentUser, same(newUser));
          expect(SessionService.isAuthenticated, isTrue);
        },
        () => MockClient((request) {
          expect(request.method, 'PUT');
          requested.complete();
          return response.future;
        }),
      );
    },
  );

  test(
    'el perfil pendiente no emite sobre un cubit cerrado al salir',
    () async {
      final requested = Completer<void>();
      final response = Completer<http.Response>();
      await http.runWithClient(
        () async {
          SessionService.start(token: 'test-session', user: user);
          final cubit = ProfileCubit(UserService());
          addTearDown(cubit.close);
          final load = cubit.loadProfile();
          await requested.future;
          SessionService.clear();
          await cubit.close();
          response.complete(
            http.Response(jsonEncode({'data': user.toJson()}), 200),
          );

          await expectLater(load, completes);
          expect(SessionService.currentUser, isNull);
        },
        () => MockClient((request) {
          expect(request.method, 'GET');
          requested.complete();
          return response.future;
        }),
      );
    },
  );

  test('un login vigente sigue guardando token, usuario y estado', () async {
    await http.runWithClient(
      () async {
        final cubit = AuthCubit();
        addTearDown(cubit.close);
        await cubit.login('test@example.com', 'test-only-password');
        expect(SessionService.token, 'test-session');
        expect(SessionService.currentUser?.id, user.id);
        expect(cubit.state, isA<AuthLoggedIn>());
      },
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': {'token': 'test-session', 'user': user.toJson()},
          }),
          200,
        ),
      ),
    );
  });

  test(
    'una actualización vigente sigue guardando el usuario recibido',
    () async {
      await http.runWithClient(
        () async {
          SessionService.start(token: 'test-session', user: user);
          final result = await UserService().updateProfile({
            'nombre': 'Actualizado',
          });
          expect(result.success, isTrue);
          expect(SessionService.currentUser?.nombre, 'Actualizado');
        },
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({'data': user.copyWith(nombre: 'Actualizado').toJson()}),
            200,
          ),
        ),
      );
    },
  );
}
