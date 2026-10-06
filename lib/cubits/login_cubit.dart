import 'package:flutter_bloc/flutter_bloc.dart';

import 'login_state.dart';

import '../services/auth_service.dart';
import '../services/session_service.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService = AuthService();
  int _loginAttempt = 0;

  AuthCubit() : super(AuthInitial());

  bool get isLoading => state is AuthLoading;

  Future<void> login(String email, String password) async {
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
    } catch (e) {
      if (isClosed || attempt != _loginAttempt) return;
      emit(AuthError(error: e.toString()));
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
      if (res.success) {
        emit(AuthRegistered());
      } else {
        emit(AuthError(error: res.message));
      }
    } catch (e) {
      emit(AuthError(error: e.toString()));
    }
  }

  void logout() {
    _loginAttempt++;
    SessionService.clear();
    emit(AuthLoggedOut());
  }
}
