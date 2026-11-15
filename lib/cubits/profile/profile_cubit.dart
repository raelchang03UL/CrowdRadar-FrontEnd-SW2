import 'package:flutter_bloc/flutter_bloc.dart';

import 'profile_state.dart';

import '../../services/user_service.dart';
import '../../services/session_service.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final UserService _userService;

  ProfileCubit(this._userService) : super(ProfileInitial());

  Future<void> loadProfile() async {
    if (isClosed || state is ProfileLoading) return;
    final generation = SessionService.generation;
    emit(ProfileLoading());
    try {
      final res = await _userService.getProfile();
      if (isClosed || generation != SessionService.generation) return;
      if (res.success && res.data != null) {
        emit(ProfileLoaded(user: res.data!));
      } else {
        emit(ProfileError(message: res.message));
      }
    } catch (_) {
      if (isClosed || generation != SessionService.generation) return;
      emit(ProfileError(message: UserService.connectionError));
    }
  }

  Future<void> updateProfile(Map<String, dynamic> cambios) async {
    if (isClosed || state is ProfileLoading) return;
    final generation = SessionService.generation;
    emit(ProfileLoading());
    try {
      final res = await _userService.updateProfile(cambios);
      if (isClosed || generation != SessionService.generation) return;
      if (res.success && res.data != null) {
        emit(ProfileLoaded(user: res.data!));
      } else {
        emit(ProfileError(message: res.message));
      }
    } catch (_) {
      if (isClosed || generation != SessionService.generation) return;
      emit(ProfileError(message: UserService.connectionError));
    }
  }
}
