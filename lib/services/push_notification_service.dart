import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../configs/firebase_options.dart';
import '../router/app_router.dart';
import 'push_device_service.dart';
import 'session_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final PushDeviceService _devices = PushDeviceService();
  FirebaseMessaging? _messaging;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _registeredSubscription;
  _RegisteredDevice? _registered;
  int _sessionAttempt = 0;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb) {
      debugPrint(
        'Las alertas push web requieren una configuración Firebase web y no están habilitadas.',
      );
      return;
    }
    final options = FirebaseOptionsConfig.currentPlatform;
    if (options == null) {
      debugPrint(
        'Alertas push no configuradas: define las opciones Firebase de la plataforma móvil.',
      );
      return;
    }
    try {
      await Firebase.initializeApp(options: options);
      _messaging = FirebaseMessaging.instance;
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
      _registeredSubscription = _messaging!.onRegistered.listen(
        _onRegistered,
        onError: (Object error) =>
            debugPrint('No se pudo actualizar el registro push del dispositivo.'),
      );
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
    if (!SessionService.isAuthenticated) {
      final previous = _registered;
      _registered = null;
      if (previous != null) {
        unawaited(_unregister(previous));
      }
      _stopFcmRegistration();
      return;
    }
    unawaited(_registerForCurrentSession(attempt));
  }

  void unregisterForLogout() {
    ++_sessionAttempt;
    final previous = _registered;
    _registered = null;
    if (previous != null) unawaited(_unregister(previous));
    _stopFcmRegistration();
  }

  Future<void> _registerForCurrentSession(int attempt) async {
    final sessionToken = SessionService.token;
    final userId = SessionService.currentUser?.id;
    if (sessionToken == null || userId == null || _messaging == null) return;
    try {
      final authorization = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (authorization.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('El usuario no autorizó las alertas push.');
        return;
      }
      if (!_isCurrentSession(attempt, sessionToken, userId)) return;
      await _messaging!.register();
    } catch (error) {
      debugPrint('No se pudo registrar el dispositivo para alertas push.');
    }
  }

  void _onRegistered(String token) {
    unawaited(_registerTokenForCurrentSession(token));
  }

  void _stopFcmRegistration() {
    final messaging = _messaging;
    if (messaging == null) return;
    unawaited(
      messaging.unregister().catchError((Object error) {
        debugPrint('No se pudo detener el registro push del dispositivo.');
      }),
    );
  }

  Future<void> _registerTokenForCurrentSession(String token) async {
    final sessionToken = SessionService.token;
    final userId = SessionService.currentUser?.id;
    final attempt = _sessionAttempt;
    if (sessionToken == null || userId == null || !SessionService.isAuthenticated) {
      return;
    }
    final previous = _registered;
    if (previous?.deviceToken == token &&
        previous?.userId == userId &&
        previous?.sessionToken == sessionToken) {
      return;
    }
    try {
      if (previous != null && previous.deviceToken != token) {
        await _unregister(previous);
      }
      await _devices.register(
        sessionToken: sessionToken,
        deviceToken: token,
        platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      );
      final registration = _RegisteredDevice(
        userId: userId,
        sessionToken: sessionToken,
        deviceToken: token,
      );
      if (!_isCurrentSession(attempt, sessionToken, userId)) {
        await _unregister(registration);
        return;
      }
      _registered = registration;
    } catch (error) {
      debugPrint('No se pudo registrar el dispositivo para alertas push.');
    }
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
      );
    } catch (error) {
      debugPrint('No se pudo desactivar el dispositivo para alertas push.');
    }
  }

  void _showForegroundMessage(RemoteMessage message) {
    final context = appRouter.routerDelegate.navigatorKey.currentContext;
    final placeId = _placeId(message);
    if (context == null || placeId == null) {
      debugPrint('La alerta push no incluye un lugar válido.');
      return;
    }
    final title = message.notification?.title ?? 'Cambió la saturación';
    final body =
        message.notification?.body ?? 'Actualiza la información del lugar.';
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('$title: $body'),
        action: SnackBarAction(
          label: 'Ver lugar',
          onPressed: () => _openPlace(message),
        ),
      ),
    );
  }

  void _openPlace(RemoteMessage message) {
    final placeId = _placeId(message);
    if (placeId == null) {
      debugPrint('Se descartó una alerta push con un identificador inválido.');
      return;
    }
    appRouter.push('/places/$placeId');
  }

  int? _placeId(RemoteMessage message) {
    final id = int.tryParse(message.data['placeId'] ?? '');
    if (id == null || id < -2147483648 || id > 2147483647) return null;
    return id;
  }

  Future<void> dispose() async {
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

  const _RegisteredDevice({
    required this.userId,
    required this.sessionToken,
    required this.deviceToken,
  });
}
