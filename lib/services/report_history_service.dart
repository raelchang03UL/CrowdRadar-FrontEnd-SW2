import 'dart:convert';

import 'package:http/http.dart' as http;

import '../configs/api_config.dart';
import '../configs/generic_response.dart';
import '../models/saturation_report_model.dart';
import 'session_service.dart';

class ReportHistoryService {
  static const sessionError =
      'Tu sesión no está disponible. Vuelve a iniciar sesión.';
  static const invalidResponse =
      'No pudimos leer tu historial. Inténtalo de nuevo.';
  static const connectionError =
      'No pudimos cargar tus reportes. Revisa tu conexión e inténtalo de nuevo.';

  Future<GenericResponse<List<SaturationReportModel>>> getReports() async {
    final generation = SessionService.generation;
    final token = SessionService.token;
    if (token == null || !SessionService.isAuthenticated) {
      return const GenericResponse(success: false, message: sessionError);
    }
    try {
      final response = await http
          .get(
            ApiConfig.uri(ApiConfig.reportHistory),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(const Duration(seconds: 15));
      if (generation != SessionService.generation || response.statusCode == 401) {
        return const GenericResponse(success: false, message: sessionError);
      }
      if (response.statusCode != 200) {
        return const GenericResponse(success: false, message: invalidResponse);
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || decoded['data'] is! List) {
        return const GenericResponse(success: false, message: invalidResponse);
      }
      final reports = (decoded['data'] as List)
          .map((item) => SaturationReportModel.fromJson(item as Map<String, dynamic>))
          .toList();
      return GenericResponse(success: true, data: reports);
    } on FormatException {
      return const GenericResponse(success: false, message: invalidResponse);
    } on TypeError {
      return const GenericResponse(success: false, message: invalidResponse);
    } catch (_) {
      return const GenericResponse(success: false, message: connectionError);
    }
  }
}
