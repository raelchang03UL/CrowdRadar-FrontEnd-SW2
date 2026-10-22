import 'dart:convert';
import 'package:http/http.dart' as http;
import '../configs/api_config.dart';
import '../configs/generic_response.dart';
import 'session_service.dart';

// Transporte compartido de los nuevos recorridos; no decide permisos ni negocio.
class ApiJsonClient {
  Future<GenericResponse<Map<String, dynamic>>> request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final generation = SessionService.generation, token = SessionService.token;
    if (token == null) {
      return const GenericResponse(
        success: false,
        error: 'SESSION_INVALID',
        message: 'Inicia sesión nuevamente.',
      );
    }
    try {
      final response =
          await (body == null
                  ? http.get(
                      ApiConfig.uri(path),
                      headers: ApiConfig.authHeaders(token),
                    )
                  : http.post(
                      ApiConfig.uri(path),
                      headers: ApiConfig.authHeaders(token),
                      body: jsonEncode(body),
                    ))
              .timeout(const Duration(seconds: 15));
      if (generation != SessionService.generation) {
        return const GenericResponse(
          success: false,
          error: 'SESSION_CHANGED',
          message: 'La sesión cambió.',
        );
      }
      if (response.statusCode == 401) {
        return const GenericResponse(
          success: false,
          error: 'SESSION_INVALID',
          message: 'Tu sesión venció. Inicia sesión nuevamente.',
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Respuesta inválida');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final code = response.statusCode >= 500
            ? 'SERVICE_UNAVAILABLE'
            : decoded['code'];
        final message = switch (code) {
          'ALREADY_VALIDATED' =>
            'Ya participaste en la validación de este reporte.',
          'ALREADY_DENOUNCED' => 'Ya enviaste una denuncia sobre este reporte.',
          'SELF_PARTICIPATION' =>
            'No puedes validar ni denunciar tu propio reporte.',
          'REPORT_NOT_FOUND' => 'El reporte no está disponible.',
          'REPORT_FORBIDDEN' =>
            'Esta consulta solo está disponible para el autor.',
          'PERIOD_INVALID' =>
            'Revisa las fechas: un período válido incluye entre 1 y 31 días.',
          'PERIOD_TOO_DENSE' =>
            'Selecciona un período más corto para consultar estos datos.',
          'REASON_INVALID' => 'El motivo admite hasta 500 caracteres.',
          _ => 'No se pudo completar la operación. Inténtalo de nuevo.',
        };
        return GenericResponse(
          success: false,
          error: code is String ? code : 'REQUEST_FAILED',
          message: message,
        );
      }
      return GenericResponse(success: true, data: decoded);
    } catch (_) {
      return const GenericResponse(
        success: false,
        error: 'UNAVAILABLE',
        message:
            'No pudimos conectar o leer la respuesta. Vuelve a intentarlo.',
      );
    }
  }
}
