import 'dart:convert';

import 'package:http/http.dart' as http;

import '../configs/api_config.dart';
import '../configs/generic_response.dart';
import 'session_service.dart';

class SaturationReportReward {
  final int pointsAwarded;
  final int karmaPoints;

  const SaturationReportReward({
    required this.pointsAwarded,
    required this.karmaPoints,
  });
}

enum SaturationLevel {
  tranquil,
  moderate,
  saturated;

  String get wireValue => switch (this) {
    SaturationLevel.tranquil => 'TRANQUILO',
    SaturationLevel.moderate => 'MODERADO',
    SaturationLevel.saturated => 'SATURADO',
  };

  String get label => switch (this) {
    SaturationLevel.tranquil => 'Tranquilo',
    SaturationLevel.moderate => 'Moderado',
    SaturationLevel.saturated => 'Saturado',
  };
}

class SaturationReportService {
  static const sessionError =
      'Tu sesión no está disponible. Vuelve a iniciar sesión.';
  static const cooldownError =
      'Este intento no registró otro reporte ni añadió puntos porque ya tienes un reporte reciente para este lugar.';
  static const cooldownCode = 'REPORT_COOLDOWN';
  static const uncertainCode = 'REPORT_UNCERTAIN';
  static const uncertainError =
      'No pudimos confirmar si el reporte se guardó. Revisa Mis reportes antes de volver a enviarlo.';
  static const genericError = uncertainError;

  Future<GenericResponse<SaturationReportReward>> createReport({
    required int placeId,
    required SaturationLevel level,
  }) async {
    final generation = SessionService.generation;
    final token = SessionService.token;
    if (token == null || !SessionService.isAuthenticated) {
      return const GenericResponse<SaturationReportReward>(
        success: false,
        message: sessionError,
      );
    }
    try {
      final response = await http
          .post(
            ApiConfig.uri('${ApiConfig.places}/$placeId/reports'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode({'level': level.wireValue}),
          )
          .timeout(const Duration(seconds: 15));
      if (generation != SessionService.generation) {
        return const GenericResponse<SaturationReportReward>(
          success: false,
          message: sessionError,
        );
      }
      if (response.statusCode == 401) {
        SessionService.rejectIfCurrent(token: token, generation: generation);
        return const GenericResponse<SaturationReportReward>(
          success: false,
          message: sessionError,
        );
      }
      // Un fallo de transporte/servidor no demuestra que la transacción falló.
      // El código de negocio, no solo el HTTP 409, confirma el cooldown.
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 409) {
        if (body is Map<String, dynamic> && body['code'] == cooldownCode) {
          return const GenericResponse<SaturationReportReward>(
            success: false,
            message: cooldownError,
            error: cooldownCode,
          );
        }
        return _uncertain;
      }
      if (response.statusCode != 201) {
        return _uncertain;
      }
      final data = body is Map<String, dynamic> ? body['data'] : null;
      if (body is! Map<String, dynamic> ||
          body['message'] is! String ||
          (body['message'] as String).trim().isEmpty ||
          data is! Map<String, dynamic> ||
          !RegExp(r'^[1-9]\d*$').hasMatch('${data['id']}') ||
          (data.containsKey('placeId') && data['placeId'] != placeId) ||
          (data.containsKey('level') && data['level'] != level.wireValue)) {
        throw const FormatException('Respuesta de reporte inválida');
      }
      return GenericResponse(
        success: true,
        message: 'Reporte enviado correctamente.',
        data:
            data['pointsAwarded'] is int &&
                (data['pointsAwarded'] as int) >= 0 &&
                data['karmaPoints'] is int &&
                (data['karmaPoints'] as int) >= 0
            ? SaturationReportReward(
                pointsAwarded: (data['pointsAwarded'] as num).toInt(),
                karmaPoints: (data['karmaPoints'] as num).toInt(),
              )
            : null,
      );
    } catch (_) {
      if (generation != SessionService.generation) {
        return const GenericResponse(success: false, message: sessionError);
      }
      return _uncertain;
    }
  }

  static const _uncertain = GenericResponse<SaturationReportReward>(
    success: false,
    message: uncertainError,
    error: uncertainCode,
  );
}
