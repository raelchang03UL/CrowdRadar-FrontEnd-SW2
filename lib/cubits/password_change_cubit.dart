import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/password_service.dart';
import '../services/session_service.dart';
import 'login_cubit.dart';

abstract class PasswordChangeState {}

class PasswordChangeInitial extends PasswordChangeState {}

class PasswordChangeLoading extends PasswordChangeState {}

class PasswordChangeError extends PasswordChangeState {
  final String message;
  PasswordChangeError(this.message);
}

class PasswordChangeSignedOut extends PasswordChangeState {
  final bool changed;
  final int generation;
  PasswordChangeSignedOut({required this.changed, required this.generation});
}

class PasswordChangeCubit extends Cubit<PasswordChangeState> {
  final PasswordService _service;
  final AuthCubit _authCubit;
  PasswordChangeCubit({required AuthCubit authCubit, PasswordService? service})
    : _authCubit = authCubit,
      _service = service ?? PasswordService(),
      super(PasswordChangeInitial());

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (isClosed || state is PasswordChangeLoading) return;
    final generation = SessionService.generation;
    final token = SessionService.token;
    emit(PasswordChangeLoading());
    try {
      final result = await _service.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      if (isClosed ||
          generation != SessionService.generation ||
          token != SessionService.token) {
        return;
      }
      if (result.success || result.sessionInvalid) {
        if (_authCubit.isClosed) return;
        _authCubit.logout();
        if (!isClosed) {
          emit(
            PasswordChangeSignedOut(
              changed: result.success,
              generation: SessionService.generation,
            ),
          );
        }
      } else {
        emit(PasswordChangeError(result.message));
      }
    } catch (_) {
      if (isClosed ||
          generation != SessionService.generation ||
          token != SessionService.token) {
        return;
      }
      emit(PasswordChangeError(PasswordService.connectionError));
    }
  }
}
