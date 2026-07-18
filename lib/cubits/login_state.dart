import '../models/user_model.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthLoggedIn extends AuthState {
  final String token;
  final UserModel user;

  AuthLoggedIn({required this.token, required this.user});
}

class AuthRegistered extends AuthState {}

class AuthLoggedOut extends AuthState {}

class AuthError extends AuthState {
  final String error;

  AuthError({required this.error});
}
