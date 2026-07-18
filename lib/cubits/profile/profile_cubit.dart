import 'package:flutter_bloc/flutter_bloc.dart';

import 'profile_state.dart';

import '../../services/user_service.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final UserService _userService;

  ProfileCubit(this._userService) : super(ProfileInitial());

  Future<void> loadProfile() async {
    emit(ProfileLoading());
    try {
      final res = await _userService.getProfile();
      if (res.success && res.data != null) {
        emit(ProfileLoaded(user: res.data!));
      } else {
        emit(ProfileError(message: res.message));
      }
    } catch (e) {
      emit(ProfileError(message: e.toString()));
    }
  }

  Future<void> updateProfile(Map<String, dynamic> cambios) async {
    emit(ProfileLoading());
    try {
      final res = await _userService.updateProfile(cambios);
      if (res.success && res.data != null) {
        emit(ProfileLoaded(user: res.data!));
      } else {
        emit(ProfileError(message: res.message));
      }
    } catch (e) {
      emit(ProfileError(message: e.toString()));
    }
  }
}
