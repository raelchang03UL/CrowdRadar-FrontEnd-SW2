import '../../models/user_model.dart';

abstract class ProfileState {}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final UserModel user;

  ProfileLoaded({required this.user});

  ProfileLoaded copyWith({UserModel? user}) {
    return ProfileLoaded(user: user ?? this.user);
  }
}

class ProfileError extends ProfileState {
  final String message;

  ProfileError({required this.message});
}
