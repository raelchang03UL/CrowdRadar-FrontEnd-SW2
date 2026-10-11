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
      'Ya registraste un reporte para este lugar. Inténtalo más tarde.';
  static const genericError =
      'No pudimos enviar el reporte. Inténtalo de nuevo.';

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
        return const GenericResponse<SaturationReportReward>(
          success: false,
          message: sessionError,
        );
      }
      if (response.statusCode == 409) {
        return const GenericResponse<SaturationReportReward>(
          success: false,
          message: cooldownError,
        );
      }
      if (response.statusCode != 201) {
        return const GenericResponse<SaturationReportReward>(
          success: false,
          message: genericError,
        );
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final data = body is Map<String, dynamic> ? body['data'] : null;
      if (body is! Map<String, dynamic> || body['message'] is! String) {
        throw const FormatException('Respuesta de reporte inválida');
      }
      return GenericResponse(
        success: true,
        message: body['message'] as String,
        data: data is Map<String, dynamic> &&
                data['pointsAwarded'] is num &&
                data['karmaPoints'] is num
            ? SaturationReportReward(
                pointsAwarded: (data['pointsAwarded'] as num).toInt(),
                karmaPoints: (data['karmaPoints'] as num).toInt(),
              )
            : const SaturationReportReward(pointsAwarded: 10, karmaPoints: 10),
      );
    } catch (_) {
      if (generation != SessionService.generation) {
        return const GenericResponse(success: false, message: sessionError);
      }
      return const GenericResponse<SaturationReportReward>(
        success: false,
        message: genericError,
      );
    }
  }
}
