import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

class SessionService {
  static String? _token;
  static UserModel? _currentUser;
  static int _generation = 0;
  static final ValueNotifier<bool> _authenticated = ValueNotifier(false);

  static String? get token => _token;
  static UserModel? get currentUser => _currentUser;
  static bool get isAuthenticated => _authenticated.value;
  static Listenable get changes => _authenticated;
  static int get generation => _generation;

  static bool start({
    required String token,
    required UserModel user,
    int? expectedGeneration,
  }) {
    if (expectedGeneration != null && expectedGeneration != _generation) {
      return false;
    }
    if (token.trim().isEmpty) {
      throw ArgumentError.value(
        token,
        'token',
        'El token no puede estar vacío',
      );
    }
    _generation++;
    _token = token;
    _currentUser = user;
    _authenticated.value = true;
    return true;
  }

  static void clear() {
    _generation++;
    _token = null;
    _currentUser = null;
    _authenticated.value = false;
  }

  static void updateUser(
    UserModel user, {
    required String sessionToken,
    required int sessionGeneration,
  }) {
    // Una respuesta pendiente no debe restaurar el usuario tras cerrar sesión.
    if (isAuthenticated &&
        _token == sessionToken &&
        _generation == sessionGeneration) {
      _currentUser = user;
    }
  }
}
