import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/recovery_service.dart';
import '../services/session_service.dart';
import 'login_cubit.dart';

abstract class ForgotPasswordState {}

class ForgotPasswordInitial extends ForgotPasswordState {}

class ForgotPasswordLoading extends ForgotPasswordState {}

class ForgotPasswordConfirmed extends ForgotPasswordState {}

class ForgotPasswordError extends ForgotPasswordState {
  final String message;
  ForgotPasswordError(this.message);
}

class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  final RecoveryService _service;
  ForgotPasswordCubit({RecoveryService? service})
    : _service = service ?? RecoveryService(),
      super(ForgotPasswordInitial());

  Future<void> requestReset({required String email}) async {
    if (isClosed ||
        state is ForgotPasswordLoading ||
        state is ForgotPasswordConfirmed) {
      return;
    }
    final generation = SessionService.generation;
    emit(ForgotPasswordLoading());
    RecoveryResult result;
    try {
      result = await _service.requestReset(email: email);
    } catch (_) {
      result = const RecoveryResult(
        success: false,
        message: RecoveryService.connectionError,
      );
    }
    if (isClosed) return;
    if (generation != SessionService.generation) {
      emit(ForgotPasswordError(RecoveryService.sessionChangedMessage));
      return;
    }
    emit(
      result.success
          ? ForgotPasswordConfirmed()
          : ForgotPasswordError(result.message),
    );
  }
}

abstract class ResetPasswordState {}

class ResetPasswordChecking extends ResetPasswordState {}

class ResetPasswordLinkError extends ResetPasswordState {
  final String message;
  final bool invalidToken;
  ResetPasswordLinkError(this.message, {this.invalidToken = false});
}

class ResetPasswordReady extends ResetPasswordState {
  final bool submitting;
  final String? error;
  ResetPasswordReady({this.submitting = false, this.error});
}

class ResetPasswordDone extends ResetPasswordState {
  final int generation;
  ResetPasswordDone(this.generation);
}

class ResetPasswordCubit extends Cubit<ResetPasswordState> {
  final RecoveryService _service;
  final AuthCubit _authCubit;
  String _token = '';
  int _operation = 0;

  ResetPasswordCubit({required AuthCubit authCubit, RecoveryService? service})
    : _authCubit = authCubit,
      _service = service ?? RecoveryService(),
      super(ResetPasswordChecking());

  Future<void> validateToken({required String token}) async {
    if (isClosed) return;
    final operation = ++_operation;
    final generation = SessionService.generation;
    _token = token;
    emit(ResetPasswordChecking());
    if (!RecoveryService.isTokenFormatValid(token)) {
      _token = '';
      emit(
        ResetPasswordLinkError(
          RecoveryService.invalidLinkMessage,
          invalidToken: true,
        ),
      );
      return;
    }
    RecoveryResult result;
    try {
      result = await _service.validateToken(token: token);
    } catch (_) {
      result = const RecoveryResult(
        success: false,
        message: RecoveryService.connectionError,
      );
    }
    if (isClosed || operation != _operation) return;
    if (generation != SessionService.generation) {
      emit(ResetPasswordLinkError(RecoveryService.sessionChangedMessage));
      return;
    }
    if (result.invalidToken) _token = '';
    emit(
      result.success
          ? ResetPasswordReady()
          : ResetPasswordLinkError(
              result.message,
              invalidToken: result.invalidToken,
            ),
    );
  }

  Future<void> retryValidation() => validateToken(token: _token);

  Future<void> resetPassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    final current = state;
    if (isClosed || current is! ResetPasswordReady || current.submitting) {
      return;
    }
    final generation = SessionService.generation;
    final operation = ++_operation;
    emit(ResetPasswordReady(submitting: true));
    RecoveryResult result;
    try {
      result = await _service.resetPassword(
        token: _token,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
    } catch (_) {
      result = const RecoveryResult(
        success: false,
        message: RecoveryService.connectionError,
      );
    }
    if (isClosed || operation != _operation) return;
    if (generation != SessionService.generation) {
      emit(ResetPasswordLinkError(RecoveryService.sessionChangedMessage));
      return;
    }
    if (result.success) {
      _token = '';
      if (_authCubit.isClosed) return;
      _authCubit.logout();
      if (!isClosed) emit(ResetPasswordDone(SessionService.generation));
    } else if (result.invalidToken) {
      _token = '';
      emit(ResetPasswordLinkError(result.message, invalidToken: true));
    } else {
      emit(ResetPasswordReady(error: result.message));
    }
  }

  @override
  Future<void> close() {
    _operation++;
    _token = '';
    return super.close();
  }
}
