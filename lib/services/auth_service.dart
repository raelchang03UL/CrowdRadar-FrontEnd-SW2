import 'dart:convert';

import 'package:http/http.dart' as http;

import '../configs/api_config.dart';
import '../configs/generic_response.dart';

import '../models/user_model.dart';

import 'session_service.dart';

class AuthService {
  Future<GenericResponse<UserModel>> login(String email, String password) async {
    final res = await http.post(
      ApiConfig.uri(ApiConfig.login),
      headers: ApiConfig.jsonHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );

    final Map<String, dynamic> body = _decode(res.bodyBytes);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final token = data['token'] as String?;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>? ?? {});

      SessionService.token = token;
      SessionService.currentUser = user;

      return GenericResponse<UserModel>(
        success: true,
        data: user,
        message: body['message'] as String? ?? '',
      );
    }

    return GenericResponse<UserModel>(
      success: false,
      message: body['message'] as String? ?? 'Error al iniciar sesión',
    );
  }

  Future<GenericResponse<UserModel>> register({
    required String nombre,
    required String apellido,
    required String email,
    required String password,
    required String telefono,
    required String distrito,
  }) async {
    final res = await http.post(
      ApiConfig.uri(ApiConfig.register),
      headers: ApiConfig.jsonHeaders,
      body: jsonEncode({
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        'password': password,
        'telefono': telefono,
        'distrito': distrito,
      }),
    );

    final Map<String, dynamic> body = _decode(res.bodyBytes);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final user = UserModel.fromJson(body['data'] as Map<String, dynamic>? ?? {});
      return GenericResponse<UserModel>(
        success: true,
        data: user,
        message: body['message'] as String? ?? '',
      );
    }

    return GenericResponse<UserModel>(
      success: false,
      message: body['message'] as String? ?? 'Error al registrar usuario',
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
