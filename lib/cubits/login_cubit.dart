import 'package:flutter_bloc/flutter_bloc.dart';

import 'login_state.dart';

import '../services/auth_service.dart';
import '../services/session_service.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService = AuthService();

  AuthCubit() : super(AuthInitial());

  bool get isLoading => state is AuthLoading;

  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
      final res = await _authService.login(email, password);
      if (res.success && res.data != null) {
        emit(AuthLoggedIn(token: SessionService.token ?? '', user: res.data!));
      } else {
        emit(AuthError(error: res.message));
      }
    } catch (e) {
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
    SessionService.token = null;
    SessionService.currentUser = null;
    emit(AuthLoggedOut());
  }
}
