import 'dart:convert';

import 'package:http/http.dart' as http;

import '../configs/api_config.dart';
import 'session_service.dart';

class PasswordChangeResult {
  final bool success;
  final String message;
  final bool sessionInvalid;
  const PasswordChangeResult({
    required this.success,
    required this.message,
    this.sessionInvalid = false,
  });
}

class PasswordService {
  static const changedMessage =
      'Contraseña actualizada. Inicia sesión nuevamente.';
  static const connectionError =
      'No pudimos conectar. Revisa tu conexión e inténtalo de nuevo.';
  static const serviceError =
      'No pudimos cambiar la contraseña. Inténtalo de nuevo.';
  static const sessionError =
      'Tu sesión no está disponible. Vuelve a iniciar sesión.';

  Future<PasswordChangeResult> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final generation = SessionService.generation;
    final token = SessionService.token;
    if (token == null) {
      return const PasswordChangeResult(
        success: false,
        message: sessionError,
        sessionInvalid: true,
      );
    }
    try {
      final response = await http
          .post(
            ApiConfig.uri(ApiConfig.changePassword),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
              'confirmPassword': confirmPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (generation != SessionService.generation ||
          token != SessionService.token) {
        return const PasswordChangeResult(
          success: false,
          message: sessionError,
        );
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) {
        return const PasswordChangeResult(
          success: false,
          message: serviceError,
        );
      }
      if (response.statusCode == 200 && body['message'] is String) {
        return const PasswordChangeResult(
          success: true,
          message: changedMessage,
        );
      }
      final code = body['code'];
      if (response.statusCode == 401 && code == 'SESSION_INVALID') {
        return const PasswordChangeResult(
          success: false,
          message: sessionError,
          sessionInvalid: true,
        );
      }
      if (response.statusCode == 403 && code == 'CURRENT_PASSWORD_INVALID') {
        return const PasswordChangeResult(
          success: false,
          message: 'La contraseña actual no es correcta.',
        );
      }
      if (response.statusCode == 400) {
        final message = switch (code) {
          'PASSWORD_MISMATCH' =>
            'La confirmación no coincide con la contraseña nueva.',
          'PASSWORD_REUSED' => 'Elige una contraseña diferente de la actual.',
          'PASSWORD_VALIDATION' =>
            'Revisa las contraseñas. Usa al menos 8 caracteres y no superes 72 bytes.',
          _ => serviceError,
        };
        return PasswordChangeResult(success: false, message: message);
      }
      return const PasswordChangeResult(success: false, message: serviceError);
    } on FormatException {
      return const PasswordChangeResult(success: false, message: serviceError);
    } on TypeError {
      return const PasswordChangeResult(success: false, message: serviceError);
    } catch (_) {
      return const PasswordChangeResult(
        success: false,
        message: connectionError,
      );
    }
  }
}
