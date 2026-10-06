import 'dart:convert';

import 'package:http/http.dart' as http;

import '../configs/api_config.dart';
import '../configs/generic_response.dart';

import '../models/user_model.dart';

import 'session_service.dart';

class UserService {
  Future<GenericResponse<UserModel>> getProfile() async {
    final sessionGeneration = SessionService.generation;
    final token = SessionService.token;
    if (token == null) {
      return const GenericResponse<UserModel>(
        success: false,
        message: 'No hay sesión activa',
      );
    }

    final res = await http.get(
      ApiConfig.uri(ApiConfig.profile),
      headers: ApiConfig.authHeaders(token),
    );

    if (sessionGeneration != SessionService.generation) {
      return const GenericResponse<UserModel>(
        success: false,
        message: 'La sesión cambió durante la solicitud',
      );
    }

    final Map<String, dynamic> body = _decode(res.bodyBytes);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final user = UserModel.fromJson(
        body['data'] as Map<String, dynamic>? ?? {},
      );
      return GenericResponse<UserModel>(
        success: true,
        data: user,
        message: body['message'] as String? ?? '',
      );
    }

    return GenericResponse<UserModel>(
      success: false,
      message: body['message'] as String? ?? 'Error al obtener el perfil',
    );
  }

  Future<GenericResponse<UserModel>> updateProfile(
    Map<String, dynamic> cambios,
  ) async {
    final sessionGeneration = SessionService.generation;
    final token = SessionService.token;
    if (token == null) {
      return const GenericResponse<UserModel>(
        success: false,
        message: 'No hay sesión activa',
      );
    }

    final res = await http.put(
      ApiConfig.uri(ApiConfig.profile),
      headers: ApiConfig.authHeaders(token),
      body: jsonEncode(cambios),
    );

    if (sessionGeneration != SessionService.generation) {
      return const GenericResponse<UserModel>(
        success: false,
        message: 'La sesión cambió durante la solicitud',
      );
    }

    final Map<String, dynamic> body = _decode(res.bodyBytes);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final user = UserModel.fromJson(
        body['data'] as Map<String, dynamic>? ?? {},
      );

      SessionService.updateUser(
        user,
        sessionToken: token,
        sessionGeneration: sessionGeneration,
      );

      return GenericResponse<UserModel>(
        success: true,
        data: user,
        message: body['message'] as String? ?? '',
      );
    }

    return GenericResponse<UserModel>(
      success: false,
      message: body['message'] as String? ?? 'Error al actualizar el perfil',
    );
  }

  Map<String, dynamic> _decode(List<int> bodyBytes) {
    try {
      return jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
