import 'dart:convert';
import 'package:http/http.dart' as http;
import '../configs/api_config.dart';
import '../configs/generic_response.dart';
import '../models/user_model.dart';
import 'session_service.dart';

class AuthService {
  static const connectionError =
      'No pudimos conectar con el servidor. Comprueba que el backend esté encendido e inténtalo de nuevo.';
  static const invalidResponse =
      'El servidor devolvió una respuesta no válida. Inténtalo de nuevo.';
  static const serverError =
      'No pudimos completar la solicitud. Inténtalo de nuevo.';

  Future<GenericResponse<UserModel>> login(
    String email,
    String password,
  ) async {
    final generation = SessionService.generation;
    try {
      final res = await http
          .post(
            ApiConfig.uri(ApiConfig.login),
            headers: ApiConfig.jsonHeaders,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 401) {
        return const GenericResponse(
          success: false,
          message: 'Correo o contraseña incorrectos.',
        );
      }
      if (res.statusCode == 400) {
        return const GenericResponse(
          success: false,
          message: 'Revisa el correo y la contraseña.',
        );
      }
      if (res.statusCode != 200) {
        return const GenericResponse(success: false, message: serverError);
      }
      final body = _decode(res.bodyBytes);
      final data = body['data'] as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token == null || token.trim().isEmpty) {
        return const GenericResponse(
          success: false,
          message: 'No se recibió un token de sesión válido',
        );
      }
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      if (user.id == null) {
        return const GenericResponse(success: false, message: invalidResponse);
      }
      if (!SessionService.start(
        token: token,
        user: user,
        expectedGeneration: generation,
      )) {
        return const GenericResponse(
          success: false,
          message: 'La sesión cambió durante la solicitud',
        );
      }
      return GenericResponse(
        success: true,
        data: user,
        message: 'Inicio de sesión exitoso.',
      );
    } on FormatException {
      return const GenericResponse(success: false, message: invalidResponse);
    } on TypeError {
      return const GenericResponse(success: false, message: invalidResponse);
    } catch (_) {
      return const GenericResponse(success: false, message: connectionError);
    }
  }

  Future<GenericResponse<UserModel>> register({
    required String nombre,
    required String apellido,
    required String email,
    required String password,
    required String telefono,
    required String distrito,
  }) async {
    try {
      final res = await http
          .post(
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
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 400) {
        String message = 'Revisa los datos del formulario.';
        try {
          if (_decode(res.bodyBytes)['message'] ==
              'El correo ya está registrado.') {
            message =
                'El correo ya está registrado. Inicia sesión o usa otro correo.';
          }
        } catch (_) {
          /* No mostrar detalles internos ni cuerpos no JSON. */
        }
        return GenericResponse(success: false, message: message);
      }
      if (res.statusCode != 201) {
        return const GenericResponse(success: false, message: serverError);
      }
      final body = _decode(res.bodyBytes);
      final user = UserModel.fromJson(body['data'] as Map<String, dynamic>);
      if (user.id == null) {
        return const GenericResponse(success: false, message: invalidResponse);
      }
      return GenericResponse(
        success: true,
        data: user,
        message: 'Usuario registrado correctamente.',
      );
    } on FormatException {
      return const GenericResponse(success: false, message: invalidResponse);
    } on TypeError {
      return const GenericResponse(success: false, message: invalidResponse);
    } catch (_) {
      return const GenericResponse(success: false, message: connectionError);
    }
  }

  Map<String, dynamic> _decode(List<int> bytes) =>
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
}
