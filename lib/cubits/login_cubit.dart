import 'package:flutter_bloc/flutter_bloc.dart';

import 'login_state.dart';

import '../services/auth_service.dart';
import '../services/session_service.dart';

enum AuthOperation { login, register }

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;
  int _loginAttempt = 0;
  AuthOperation? lastOperation;

  AuthCubit({AuthService? authService})
    : _authService = authService ?? AuthService(),
      super(AuthInitial());

  bool get isLoading => state is AuthLoading;

  Future<void> login(String email, String password) async {
    if (isClosed || isLoading) return;
    lastOperation = AuthOperation.login;
    final attempt = ++_loginAttempt;
    emit(AuthLoading());
    try {
      final res = await _authService.login(email, password);
      if (isClosed || attempt != _loginAttempt) return;
      if (res.success && res.data != null) {
        emit(AuthLoggedIn(token: SessionService.token ?? '', user: res.data!));
      } else {
        emit(AuthError(error: res.message));
      }
    } catch (_) {
      if (isClosed || attempt != _loginAttempt) return;
      emit(AuthError(error: AuthService.connectionError));
    }
  }

  Future<void> register({
    required String nombre,
    required String apellido,
    required String email,
    required String password,
    required String telefono,
    required String distrito,
  }) async {
    if (isClosed || isLoading) return;
    lastOperation = AuthOperation.register;
    final attempt = ++_loginAttempt;
    emit(AuthLoading());
    try {
      final res = await _authService.register(
        nombre: nombre,
        apellido: apellido,
        email: email,
        password: password,
        telefono: telefono,
        distrito: distrito,
      );
      if (isClosed || attempt != _loginAttempt) return;
      if (res.success) {
        emit(AuthRegistered());
      } else {
        emit(AuthError(error: res.message));
      }
    } catch (_) {
      if (isClosed || attempt != _loginAttempt) return;
      emit(AuthError(error: AuthService.connectionError));
    }
  }

  void logout() {
    _loginAttempt++;
    SessionService.clear();
    emit(AuthLoggedOut());
  }
}
