import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../configs/firebase_options.dart';
import '../components/push_alert_notice.dart';
import '../router/app_router.dart';
import 'push_alert_status.dart';
import 'push_device_service.dart';
import 'push_message_guard.dart';
import 'push_web_bridge.dart';
import 'session_service.dart';

export 'push_alert_status.dart';

class PushNotificationService {
  PushNotificationService._()
    : _devices = PushDeviceService(),
      _isWeb = kIsWeb,
      _vapidKey = FirebaseOptionsConfig.vapidKey,
      _hasFidRegistration = (() =>
          hasPushFidRegistration(FirebaseOptionsConfig.webAppId));

  @visibleForTesting
  PushNotificationService.forTesting(
    this._devices,
    FirebaseMessaging messaging, {
    bool isWeb = kIsWeb,
    String? vapidKey,
    Future<bool> Function()? hasFidRegistration,
  }) : _messaging = messaging,
       _isWeb = isWeb,
       _vapidKey = vapidKey ?? FirebaseOptionsConfig.vapidKey,
       _hasFidRegistration = hasFidRegistration ?? (() async => false);

  static final PushNotificationService instance = PushNotificationService._();

  final PushDeviceService _devices;
  final bool _isWeb;
  final String _vapidKey;
  final Future<bool> Function() _hasFidRegistration;
  FirebaseMessaging? _messaging;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _registeredSubscription;
  _RegisteredDevice? _registered;
  _RegisteredDevice? _pendingDisable;
  final _status = ValueNotifier(PushAlertStatus.inactive);
  PushAlertNotice? _pushSnackBar;
  bool _disposed = false;
  int _sessionAttempt = 0;
  bool _initialized = false;
  int? _fcmAttempt;
  Completer<bool>? _enableResult;
  Future<void> _sdkQueue = Future.value();
  Future<void> _registrationQueue = Future.value();
  bool _webTokenModeReady = false;
  bool _webTokenRequested = false;

  ValueListenable<PushAlertStatus> get status => _status;

  void _setStatus(PushAlertStatus value) {
    if (!_disposed) _status.value = value;
  }

  void _clearLocalAuthorization() {
    _registered = null;
    clearPushBridge();
    _pushSnackBar?.close();
    _pushSnackBar = null;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final options = FirebaseOptionsConfig.currentPlatform;
    if (options == null && _messaging == null) {
      debugPrint(
        'Alertas push no configuradas: define las opciones Firebase de la plataforma móvil.',
      );
      return;
    }
    try {
      initializePushBridge(() => _activeRegistrationId ?? '', (raw) {
        try {
          final data = jsonDecode(raw);
          if (data is Map<String, dynamic>) _openData(data);
        } catch (_) {}
      });
      if (_messaging == null) {
        await Firebase.initializeApp(options: options);
        _messaging = FirebaseMessaging.instance;
      }
      SessionService.changes.addListener(_onSessionChanged);
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _openPlace,
        onError: (Object error) =>
            debugPrint('No se pudo procesar la alerta push recibida.'),
      );
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _showForegroundMessage,
        onError: (Object error) =>
            debugPrint('No se pudo mostrar la alerta push recibida.'),
      );
      if (!_isWeb) {
        _registeredSubscription = _messaging!.onRegistered.listen(
          _onRegistered,
          onError: (Object error) => debugPrint(
            'No se pudo actualizar el registro push del dispositivo.',
          ),
        );
      }
      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openPlace(initialMessage);
        });
      }
      _onSessionChanged();
    } on FirebaseException catch (error) {
      debugPrint('No se pudo inicializar Firebase para alertas: ${error.code}');
    } catch (error) {
      debugPrint('No se pudo inicializar Firebase para alertas.');
    }
  }

  void _onSessionChanged() {
    final attempt = ++_sessionAttempt;
    _fcmAttempt = null;
    _finishEnable(false);
    final previous = _registered ?? _pendingDisable;
    _pendingDisable = null;
    _clearLocalAuthorization();
    _setStatus(PushAlertStatus.inactive);
    if (previous != null) {
      unawaited(_unregister(previous));
    }
    unawaited(_stopFcmRegistration());
    if (!SessionService.isAuthenticated || _isWeb) return;
    unawaited(_registerForCurrentSession(attempt));
  }

  void unregisterForLogout() {
    ++_sessionAttempt;
    _fcmAttempt = null;
    _finishEnable(false);
    final previous = _registered ?? _pendingDisable;
    _pendingDisable = null;
    _clearLocalAuthorization();
    _setStatus(PushAlertStatus.inactive);
    if (previous != null) unawaited(_unregister(previous));
    unawaited(_stopFcmRegistration());
  }

  bool get isConfigured =>
      _messaging != null && (!_isWeb || _vapidKey.isNotEmpty);

  Future<bool> enableForCurrentSession() async {
    if (!isConfigured ||
        _disposed ||
        !SessionService.isAuthenticated ||
        _enableResult != null ||
        _status.value == PushAlertStatus.disabling ||
        _pendingDisable != null) {
      return false;
    }
    if (_activeRegistrationId != null) return true;
    final result = Completer<bool>();
    final attempt = ++_sessionAttempt;
    _enableResult = result;
    _setStatus(PushAlertStatus.enabling);
    void failIfCurrent() {
      if (attempt == _sessionAttempt && identical(_enableResult, result)) {
        _finishEnable(false);
      }
    }

    // El plazo incluye el permiso del navegador, no solo el evento de registro.
    unawaited(
      _registerForCurrentSession(attempt).then<void>((registered) {
        if (!registered) failIfCurrent();
      }, onError: (Object error, StackTrace stack) => failIfCurrent()),
    );
    return result.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        if (attempt == _sessionAttempt && identical(_enableResult, result)) {
          // Un permiso aceptado tarde no puede registrar este intento vencido.
          ++_sessionAttempt;
          _fcmAttempt = null;
          _finishEnable(false);
          unawaited(_stopFcmRegistration());
        }
        return false;
      },
    );
  }

  Future<bool> disableForCurrentSession() async {
    if (_disposed || !SessionService.isAuthenticated || _status.value.isBusy) {
      return false;
    }
    final device = _registered ?? _pendingDisable;
    if (device == null ||
        device.generation != SessionService.generation ||
        device.sessionToken != SessionService.token ||
        device.userId != SessionService.currentUser?.id) {
      return false;
    }
    final attempt = ++_sessionAttempt;
    _fcmAttempt = null;
    _pendingDisable = device;
    // El deseo de no recibir más alertas rige localmente desde este momento.
    // La captura privada se conserva hasta obtener el 204 o cambiar de sesión.
    _clearLocalAuthorization();
    _setStatus(PushAlertStatus.disabling);
    bool current() =>
        !_disposed &&
        device.generation == SessionService.generation &&
        _isCurrentSession(attempt, device.sessionToken, device.userId);
    try {
      // No usar _unregister: logout tolera errores, la baja explícita debe
      // distinguir un 204 confirmado de un resultado incierto.
      await _devices.unregister(
        sessionToken: device.sessionToken,
        deviceToken: device.deviceToken,
        registrationId: device.registrationId,
        generation: device.generation,
      );
      if (!current()) return false;
      _pendingDisable = null;
      // Se encola antes de permitir otra activación. La guarda se revalida
      // dentro de la cola: una respuesta tardía no borra el token de otra sesión.
      unawaited(_stopFcmRegistration(current: current));
      _setStatus(PushAlertStatus.inactive);
      return true;
    } catch (_) {
      if (current()) _setStatus(PushAlertStatus.disableUnconfirmed);
      return false;
    }
  }

  Future<bool> _registerForCurrentSession(int attempt) async {
    final sessionToken = SessionService.token;
    final userId = SessionService.currentUser?.id;
    final generation = SessionService.generation;
    if (sessionToken == null || userId == null || _messaging == null) {
      return false;
    }
    try {
      final authorization = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (authorization.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('El usuario no autorizó las alertas push.');
        return false;
      }
      bool current() =>
          generation == SessionService.generation &&
          _isCurrentSession(attempt, sessionToken, userId);
      if (!current()) return false;
      final token = await _withSdk<String?>(() async {
        if (!current()) return null;
        if (_isWeb) {
          await preparePushWorker(FirebaseOptionsConfig.workerPath);
          if (!current()) return null;
          if (!_webTokenModeReady) {
            // Transición única de la API FID anterior; después solo getToken/deleteToken.
            if (await _hasFidRegistration()) await _messaging!.unregister();
            _webTokenModeReady = true;
          }
          if (!current()) return null;
          _webTokenRequested = true;
          // Compatibilidad Web comprobada con recepción real; no equivale al FID.
          // ignore: deprecated_member_use
          return _messaging!.getToken(
            vapidKey: _vapidKey,
            serviceWorkerScriptPath: FirebaseOptionsConfig.workerPath,
          );
        }
        _fcmAttempt = attempt;
        await _messaging!.register();
        return null;
      });
      if (!current()) return false;
      if (_isWeb) {
        if (token == null || token.isEmpty) return false;
        _fcmAttempt = attempt;
        await _queueRegistration(token, attempt);
      }
      return true;
    } catch (error) {
      debugPrint('No se pudo registrar el dispositivo para alertas push.');
      return false;
    }
  }

  void _onRegistered(String token) {
    if (_isWeb || _fcmAttempt != _sessionAttempt) return;
    unawaited(_queueRegistration(token, _sessionAttempt));
  }

  Future<void> _queueRegistration(String token, int attempt) {
    _registrationQueue = _registrationQueue
        .then((_) async {
          if (_fcmAttempt != attempt || _sessionAttempt != attempt) return;
          await _registerTokenForCurrentSession(token);
        })
        .catchError((Object error) {
          if (attempt == _sessionAttempt) _finishEnable(false);
        });
    return _registrationQueue;
  }

  Future<T> _withSdk<T>(Future<T> Function() operation) {
    final result = _sdkQueue.then((_) => operation());
    _sdkQueue = result.then<void>((_) {}, onError: (Object error) {});
    return result;
  }

  Future<void> _stopFcmRegistration({bool Function()? current}) {
    final messaging = _messaging;
    if (messaging == null || (current != null && !current())) {
      return Future.value();
    }
    return _withSdk<void>(() async {
      if (current != null && !current()) return;
      if (_isWeb) {
        if (!_webTokenRequested) return;
        // ignore: deprecated_member_use
        await messaging.deleteToken();
        _webTokenRequested = false;
      } else {
        await messaging.unregister();
      }
    }).catchError((Object error) {
      debugPrint('No se pudo detener el registro push del dispositivo.');
    });
  }

  Future<void> _registerTokenForCurrentSession(String token) async {
    final sessionToken = SessionService.token;
    final userId = SessionService.currentUser?.id;
    final attempt = _sessionAttempt;
    final generation = SessionService.generation;
    if (sessionToken == null ||
        userId == null ||
        !SessionService.isAuthenticated) {
      return;
    }
    final previous = _registered;
    if (previous?.deviceToken == token &&
        previous?.userId == userId &&
        previous?.sessionToken == sessionToken &&
        previous?.generation == generation) {
      _finishEnable(true);
      return;
    }
    try {
      if (previous != null && previous.deviceToken != token) {
        await _unregister(previous);
      }
      if (!_isCurrentSession(attempt, sessionToken, userId) ||
          generation != SessionService.generation) {
        return;
      }
      final registrationId = await _devices.register(
        sessionToken: sessionToken,
        deviceToken: token,
        platform: _isWeb
            ? 'web'
            : defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        generation: generation,
        targetType: _isWeb ? 'fcm-token' : 'fid',
      );
      final registration = _RegisteredDevice(
        userId: userId,
        sessionToken: sessionToken,
        deviceToken: token,
        generation: generation,
        registrationId: registrationId,
      );
      if (!_isCurrentSession(attempt, sessionToken, userId) ||
          generation != SessionService.generation) {
        await _unregister(registration);
        return;
      }
      _registered = registration;
      _finishEnable(true);
    } catch (error) {
      debugPrint('No se pudo registrar el dispositivo para alertas push.');
      if (attempt == _sessionAttempt) _finishEnable(false);
    }
  }

  String? get _activeRegistrationId =>
      SessionService.isAuthenticated &&
          _registered?.generation == SessionService.generation &&
          _registered?.userId == SessionService.currentUser?.id &&
          _registered?.sessionToken == SessionService.token
      ? _registered?.registrationId
      : null;

  void _finishEnable(bool success) {
    final result = _enableResult;
    _enableResult = null;
    _setStatus(success ? PushAlertStatus.active : PushAlertStatus.inactive);
    if (result != null && !result.isCompleted) result.complete(success);
  }

  bool _isCurrentSession(int attempt, String token, int userId) =>
      attempt == _sessionAttempt &&
      SessionService.isAuthenticated &&
      SessionService.token == token &&
      SessionService.currentUser?.id == userId;

  Future<void> _unregister(_RegisteredDevice device) async {
    try {
      await _devices.unregister(
        sessionToken: device.sessionToken,
        deviceToken: device.deviceToken,
        registrationId: device.registrationId,
      );
    } catch (error) {
      debugPrint('No se pudo desactivar el dispositivo para alertas push.');
    }
  }

  void _showForegroundMessage(RemoteMessage message) {
    final context = appRouter.routerDelegate.navigatorKey.currentContext;
    final placeId = authorizedPushPlace(message.data, _activeRegistrationId);
    if (context == null || placeId == null) {
      debugPrint('La alerta push no incluye un lugar válido.');
      return;
    }
    final transition = _transitionFor(message.data)?.transition;
    final text = transition == null
        ? 'Cambió la saturación de un favorito. Consulta su nivel actual.'
        : 'Cambió la saturación: ${transition.previousLevel.label} → ${transition.newLevel.label}.';
    _pushSnackBar?.close();
    _pushSnackBar = PushAlertNotice.show(
      context,
      text: text,
      onOpen: () => _openPlace(message),
    );
  }

  void _openPlace(RemoteMessage message) => _openData(message.data);

  void _openData(Map<String, dynamic> data) {
    final placeId = authorizedPushPlace(data, _activeRegistrationId);
    if (placeId != null) {
      appRouter.push('/places/$placeId', extra: _transitionFor(data));
    }
  }

  AuthorizedPushTransition? _transitionFor(Map<String, dynamic> data) =>
      authorizedPushTransition(
        data,
        _activeRegistrationId,
        currentRegistrationId: () => _activeRegistrationId,
        authorizationChanges: status,
      );

  Future<void> dispose() async {
    unregisterForLogout();
    _disposed = true;
    _status.dispose();
    SessionService.changes.removeListener(_onSessionChanged);
    await _openedSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _registeredSubscription?.cancel();
  }
}

class _RegisteredDevice {
  final int userId;
  final String sessionToken;
  final String deviceToken;
  final int generation;
  final String registrationId;

  const _RegisteredDevice({
    required this.userId,
    required this.sessionToken,
    required this.deviceToken,
    required this.generation,
    required this.registrationId,
  });
}
