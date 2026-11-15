import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import 'session_storage.dart';
import 'session_token.dart';
import 'session_validation.dart';

enum SessionRestoreStatus { idle, restoring, retryRequired }

class SessionService {
  static String? _token;
  static UserModel? _currentUser;
  static int _generation = 0;
  static bool _wasRejected = false;
  static final ValueNotifier<bool> _authenticated = ValueNotifier(false);
  static final ValueNotifier<int> _changes = ValueNotifier(0);
  static SessionStorage _storage = createSessionStorage();
  static SessionValidator? _validator;
  static DateTime Function() _clock = DateTime.now;
  static RestorableSession? _candidate;
  static SessionRestoreStatus _restoreStatus = SessionRestoreStatus.idle;
  static Future<void>? _restoreInFlight;
  static int _restoreAttempt = 0;
  static bool _restorePrepared = false;
  static bool _alertsEnabledForReload = false;

  static String? get token => _token;
  static UserModel? get currentUser => _currentUser;
  static bool get isAuthenticated => _authenticated.value;
  static Listenable get changes => _changes;
  static int get generation => _generation;
  static bool get wasRejected => _wasRejected;
  static SessionRestoreStatus get restoreStatus => _restoreStatus;
  static bool get alertsEnabledForReload => _alertsEnabledForReload;

  static void _notify() => _changes.value++;

  static void _removeStoredSession() {
    try {
      _storage.clear();
    } catch (_) {
      /* Almacenamiento bloqueado: sesión solo en memoria. */
    }
  }

  static void _persistSession(String token) {
    if (!_storage.enabled) return;
    if (!isRestorableJwt(token, _clock())) {
      _removeStoredSession();
      return;
    }
    try {
      _storage.write(encodeStoredSession(token, _alertsEnabledForReload));
    } catch (_) {
      // Un fallo al guardar B/OFF no debe conservar el registro anterior A/ON.
      _removeStoredSession();
    }
  }

  static void _invalidateRestore() {
    _restoreAttempt++;
    _restoreInFlight = null;
    _candidate = null;
    _restoreStatus = SessionRestoreStatus.idle;
    _restorePrepared = true;
  }

  // Se llama antes de construir el router. El candidato nunca es sesión pública.
  static void prepareRestore() {
    if (_restorePrepared || isAuthenticated || !_storage.enabled) return;
    _restorePrepared = true;
    String? record;
    try {
      record = _storage.read();
    } catch (_) {
      return;
    }
    if (record == null) return;
    final candidate = decodeStoredSession(record, _clock());
    if (candidate == null) {
      _removeStoredSession();
      return;
    }
    _generation++;
    _wasRejected = false;
    _token = null;
    _currentUser = null;
    _alertsEnabledForReload = false;
    _authenticated.value = false;
    _candidate = candidate;
    _restoreStatus = SessionRestoreStatus.restoring;
    _notify();
  }

  static Future<void> restore() {
    if (_restoreInFlight != null) return _restoreInFlight!;
    final candidate = _candidate;
    if (candidate == null || isAuthenticated) return Future.value();
    if (!isRestorableJwt(candidate.token, _clock())) {
      clear();
      return Future.value();
    }
    final attempt = ++_restoreAttempt, generation = _generation;
    final result = Completer<void>();
    _restoreInFlight = result.future;
    _restoreStatus = SessionRestoreStatus.restoring;
    _notify();
    unawaited(() async {
      try {
        bool current() =>
            attempt == _restoreAttempt &&
            generation == _generation &&
            identical(_candidate, candidate) &&
            !isAuthenticated;
        if (!current()) return;
        final validation =
            await (_validator?.call(candidate.token) ??
                validateStoredSession(
                  candidate.token,
                  cacheKey: '${_clock().microsecondsSinceEpoch}-$attempt',
                ));
        if (!current()) return;
        if (validation.status == SessionValidationStatus.invalid) {
          clear(rejected: true);
        } else if (!isRestorableJwt(candidate.token, _clock())) {
          clear();
        } else if (validation.status == SessionValidationStatus.valid &&
            isRestoredUserValid(validation.user)) {
          _generation++;
          _token = candidate.token;
          _currentUser = validation.user;
          _alertsEnabledForReload = candidate.alertsEnabled;
          _candidate = null;
          _restoreStatus = SessionRestoreStatus.idle;
          _wasRejected = false;
          _authenticated.value = true;
          _notify();
        } else {
          _restoreStatus = SessionRestoreStatus.retryRequired;
          _notify();
        }
      } catch (_) {
        if (attempt == _restoreAttempt &&
            generation == _generation &&
            identical(_candidate, candidate)) {
          _restoreStatus = SessionRestoreStatus.retryRequired;
          _notify();
        }
      } finally {
        if (identical(_restoreInFlight, result.future)) _restoreInFlight = null;
        result.complete();
      }
    }());
    return result.future;
  }

  static void setAlertsEnabledForReload(
    bool value, {
    required String token,
    required int generation,
  }) {
    if (!isAuthenticated || _token != token || _generation != generation) {
      return;
    }
    _alertsEnabledForReload = value;
    _persistSession(token);
  }

  @visibleForTesting
  static void configureRestoreForTesting({
    SessionStorage? storage,
    SessionValidator? validator,
    DateTime Function()? clock,
  }) {
    _invalidateRestore();
    _restorePrepared = false;
    _storage = storage ?? createSessionStorage();
    _validator = validator;
    _clock = clock ?? DateTime.now;
    _generation++;
    _token = null;
    _currentUser = null;
    _wasRejected = false;
    _alertsEnabledForReload = false;
    _authenticated.value = false;
    _notify();
  }

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
    _invalidateRestore();
    _wasRejected = false;
    _token = token;
    _currentUser = user;
    _alertsEnabledForReload = false;
    _persistSession(token);
    _authenticated.value = true;
    _notify();
    return true;
  }

  static void clear({bool rejected = false}) {
    _generation++;
    _invalidateRestore();
    _wasRejected = rejected;
    _token = null;
    _currentUser = null;
    _alertsEnabledForReload = false;
    _removeStoredSession();
    _authenticated.value = false;
    _notify();
  }

  // El token puede repetirse: la generación distingue sesiones y hace idempotente
  // el rechazo simultáneo. No navega ni interpreta errores de login.
  static bool rejectIfCurrent({
    required String token,
    required int generation,
  }) {
    if (!isAuthenticated || _generation != generation || _token != token) {
      return false;
    }
    clear(rejected: true);
    return true;
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
