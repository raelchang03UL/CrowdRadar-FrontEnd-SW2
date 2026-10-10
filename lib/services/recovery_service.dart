import 'dart:convert';

import 'package:http/http.dart' as http;

import '../configs/api_config.dart';

class RecoveryResult {
  final bool success;
  final String message;
  final bool invalidToken;
  const RecoveryResult({
    required this.success,
    required this.message,
    this.invalidToken = false,
  });
}

class RecoveryService {
  static const requestedMessage =
      'Si el correo corresponde a una cuenta, recibirás un enlace para restablecer tu contraseña.';
  static const resetMessage =
      'Contraseña restablecida. Inicia sesión nuevamente.';
  static const invalidLinkMessage =
      'El enlace no es válido o ha expirado. Solicita uno nuevo.';
  static const unavailableMessage =
      'La recuperación no está disponible por ahora. Inténtalo más tarde.';
  static const rateLimitMessage =
      'Has realizado demasiados intentos. Espera unos minutos antes de intentarlo de nuevo.';
  static const connectionError =
      'No pudimos conectar. Revisa tu conexión e inténtalo de nuevo.';
  static const serviceError =
      'No pudimos completar la solicitud. Inténtalo de nuevo.';
  static const sessionChangedMessage =
      'Tu sesión cambió. Vuelve a abrir esta página para continuar.';

  final http.Client? _client;
  final Duration _timeout;

  RecoveryService({
    http.Client? client,
    Duration timeout = const Duration(seconds: 15),
  }) : _client = client,
       _timeout = timeout;

  static bool isTokenFormatValid(String token) =>
      token.length == 64 && RegExp(r'^[a-f0-9]{64}$').hasMatch(token);

  Future<RecoveryResult> requestReset({required String email}) => _post(
    path: ApiConfig.forgotPassword,
    body: {'email': email.trim().toLowerCase()},
    expectedStatus: 202,
    successMessage: requestedMessage,
    requesting: true,
  );

  Future<RecoveryResult> validateToken({required String token}) {
    if (!isTokenFormatValid(token)) return Future.value(_invalidLink);
    return _post(
      path: ApiConfig.validateResetToken,
      body: {'token': token},
      expectedStatus: 200,
      successMessage: '',
      validating: true,
    );
  }

  Future<RecoveryResult> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) {
    if (!isTokenFormatValid(token)) return Future.value(_invalidLink);
    return _post(
      path: ApiConfig.resetPassword,
      body: {
        'token': token,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
      expectedStatus: 200,
      successMessage: resetMessage,
    );
  }

  static const _invalidLink = RecoveryResult(
    success: false,
    message: invalidLinkMessage,
    invalidToken: true,
  );

  Future<RecoveryResult> _post({
    required String path,
    required Map<String, String> body,
    required int expectedStatus,
    required String successMessage,
    bool requesting = false,
    bool validating = false,
  }) async {
    try {
      final uri = ApiConfig.uri(path);
      final encoded = jsonEncode(body);
      final response =
          await (_client == null
                  ? http.post(
                      uri,
                      headers: ApiConfig.jsonHeaders,
                      body: encoded,
                    )
                  : _client.post(
                      uri,
                      headers: ApiConfig.jsonHeaders,
                      body: encoded,
                    ))
              .timeout(_timeout);
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) {
        return const RecoveryResult(success: false, message: serviceError);
      }
      if (response.statusCode == expectedStatus &&
          (validating ? data['valid'] == true : data['message'] is String)) {
        return RecoveryResult(success: true, message: successMessage);
      }
      final code = data['code'];
      if (response.statusCode == 400 && code == 'RESET_TOKEN_INVALID') {
        return _invalidLink;
      }
      if (response.statusCode == 429 && code == 'RATE_LIMITED') {
        return const RecoveryResult(success: false, message: rateLimitMessage);
      }
      if (response.statusCode == 503) {
        return RecoveryResult(
          success: false,
          message: requesting ? unavailableMessage : serviceError,
        );
      }
      if (response.statusCode == 400) {
        return RecoveryResult(
          success: false,
          message: switch (code) {
            'PASSWORD_VALIDATION' =>
              'Revisa las contraseñas. Usa al menos 8 caracteres y no superes 72 bytes.',
            'PASSWORD_MISMATCH' =>
              'La confirmación no coincide con la contraseña nueva.',
            'PASSWORD_REUSED' =>
              'Elige una contraseña diferente de la anterior.',
            _ => serviceError,
          },
        );
      }
      return const RecoveryResult(success: false, message: serviceError);
    } on FormatException {
      return const RecoveryResult(success: false, message: serviceError);
    } on TypeError {
      return const RecoveryResult(success: false, message: serviceError);
    } catch (_) {
      return const RecoveryResult(success: false, message: connectionError);
    }
  }
}
