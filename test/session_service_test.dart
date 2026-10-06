import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/cubits/login_state.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = UserModel(id: 1, nombre: 'Usuario de prueba');

  setUp(SessionService.clear);
  tearDown(SessionService.clear);

  test(
    'logout borra token y usuario antes de notificar y emitir el estado',
    () async {
      final cubit = AuthCubit();
      addTearDown(cubit.close);
      SessionService.start(token: 'test-session', user: user);
      var notifications = 0;
      void onSessionChanged() {
        notifications++;
        expect(SessionService.token, isNull);
        expect(SessionService.currentUser, isNull);
        expect(SessionService.isAuthenticated, isFalse);
      }

      SessionService.changes.addListener(onSessionChanged);
      addTearDown(
        () => SessionService.changes.removeListener(onSessionChanged),
      );

      cubit.logout();

      expect(cubit.state, isA<AuthLoggedOut>());
      expect(SessionService.token, isNull);
      expect(SessionService.currentUser, isNull);
      expect(notifications, 1);
    },
  );

  test('cerrar una sesión ya cerrada es seguro', () {
    SessionService.clear();
    SessionService.clear();
    expect(SessionService.token, isNull);
    expect(SessionService.currentUser, isNull);
    expect(SessionService.isAuthenticated, isFalse);
  });

  test(
    'una actualización pendiente no restaura el usuario después del logout',
    () {
      SessionService.start(token: 'old-session', user: user);
      final previousGeneration = SessionService.generation;
      SessionService.clear();
      SessionService.updateUser(
        user,
        sessionToken: 'old-session',
        sessionGeneration: previousGeneration,
      );
      expect(SessionService.currentUser, isNull);
      expect(SessionService.token, isNull);
      expect(SessionService.isAuthenticated, isFalse);

      const otherUser = UserModel(id: 2, nombre: 'Otra sesión');
      SessionService.start(token: 'new-session', user: otherUser);
      SessionService.updateUser(
        user,
        sessionToken: 'old-session',
        sessionGeneration: previousGeneration,
      );
      expect(SessionService.currentUser, same(otherUser));
    },
  );

  test(
    'la actualización de la sesión vigente conserva el usuario actualizado',
    () {
      SessionService.start(token: 'test-session', user: user);
      final updated = user.copyWith(nombre: 'Nombre actualizado');
      SessionService.updateUser(
        updated,
        sessionToken: 'test-session',
        sessionGeneration: SessionService.generation,
      );
      expect(SessionService.currentUser, same(updated));
      expect(SessionService.isAuthenticated, isTrue);
    },
  );

  test('no se abre una sesión con un token vacío', () {
    expect(
      () => SessionService.start(token: ' ', user: user),
      throwsArgumentError,
    );
    expect(SessionService.isAuthenticated, isFalse);
    expect(SessionService.currentUser, isNull);
  });
}
