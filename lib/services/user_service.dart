import 'dart:convert';

import 'package:http/http.dart' as http;

import '../configs/api_config.dart';
import '../configs/generic_response.dart';
import '../models/user_model.dart';
import 'session_service.dart';

class UserService {
  static const connectionError =
      'No pudimos conectar. Revisa tu conexión e inténtalo de nuevo.';
  static const invalidResponse =
      'No pudimos leer tu perfil. Inténtalo de nuevo.';
  static const sessionError =
      'Tu sesión no está disponible. Vuelve a iniciar sesión.';
  static const _timeout = Duration(seconds: 15);

  Future<GenericResponse<UserModel>> getProfile() => _request();

  Future<GenericResponse<UserModel>> updateProfile(
    Map<String, dynamic> cambios,
  ) => _request(changes: cambios);

  Future<GenericResponse<UserModel>> _request({
    Map<String, dynamic>? changes,
  }) async {
    final generation = SessionService.generation;
    final token = SessionService.token;
    if (token == null) {
      return const GenericResponse(success: false, message: sessionError);
    }
    try {
      final uri = ApiConfig.uri(ApiConfig.profile);
      final headers = ApiConfig.authHeaders(token);
      final response =
          await (changes == null
                  ? http.get(uri, headers: headers)
                  : http.put(uri, headers: headers, body: jsonEncode(changes)))
              .timeout(_timeout);
      if (generation != SessionService.generation) {
        return const GenericResponse(success: false, message: sessionError);
      }
      if (response.statusCode == 401) {
        return const GenericResponse(success: false, message: sessionError);
      }
      if (response.statusCode == 404) {
        return const GenericResponse(
          success: false,
          message: 'No encontramos tu perfil. Inténtalo de nuevo.',
        );
      }
      if (response.statusCode == 400 && changes != null) {
        return const GenericResponse(
          success: false,
          message: 'Revisa los datos del formulario e inténtalo de nuevo.',
        );
      }
      if (response.statusCode != 200) {
        return GenericResponse(
          success: false,
          message: changes == null
              ? 'No pudimos cargar tu perfil. Inténtalo de nuevo.'
              : 'No pudimos guardar los cambios. Inténtalo de nuevo.',
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> ||
          decoded['data'] is! Map<String, dynamic>) {
        return const GenericResponse(success: false, message: invalidResponse);
      }
      final user = UserModel.fromJson(decoded['data'] as Map<String, dynamic>);
      if (user.id == null) {
        return const GenericResponse(success: false, message: invalidResponse);
      }
      if (changes != null) {
        SessionService.updateUser(
          user,
          sessionToken: token,
          sessionGeneration: generation,
        );
      }
      return GenericResponse(success: true, data: user);
    } on FormatException {
      return const GenericResponse(success: false, message: invalidResponse);
    } on TypeError {
      return const GenericResponse(success: false, message: invalidResponse);
    } catch (_) {
      return const GenericResponse(success: false, message: connectionError);
    }
  }
}
