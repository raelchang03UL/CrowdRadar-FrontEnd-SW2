import '../configs/generic_response.dart';
import '../models/citizen_report.dart';
import 'api_json_client.dart';

class ReportReviewService {
  final ApiJsonClient _client;
  ReportReviewService({ApiJsonClient? client})
    : _client = client ?? ApiJsonClient();
  Future<GenericResponse<List<CitizenReport>>> list() async {
    final result = await _client.request('/api/reports');
    if (!result.success) {
      return GenericResponse(
        success: false,
        error: result.error,
        message: result.message,
      );
    }
    try {
      return GenericResponse(
        success: true,
        data: (result.data!['data'] as List)
            .map((item) => CitizenReport.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
      );
    } catch (_) {
      return const GenericResponse(
        success: false,
        message: 'No pudimos leer los reportes.',
      );
    }
  }

  Future<GenericResponse<CitizenReport>> detail(
    String id, {
    bool ownOnly = false,
  }) async {
    final result = await _client.request(
      '/api/reports/${Uri.encodeComponent(id)}${ownOnly ? '/own-validation' : ''}',
    );
    if (!result.success) {
      return GenericResponse(
        success: false,
        error: result.error,
        message: result.message,
      );
    }
    try {
      return GenericResponse(
        success: true,
        data: CitizenReport.fromJson(
          result.data!['data'] as Map<String, dynamic>,
        ),
      );
    } catch (_) {
      return const GenericResponse(
        success: false,
        message: 'No pudimos leer este reporte.',
      );
    }
  }

  Future<GenericResponse<Map<String, dynamic>>> vote(
    String id,
    String decision,
  ) => _client.request(
    '/api/reports/${Uri.encodeComponent(id)}/validations',
    body: {'decision': decision},
  );
  Future<GenericResponse<Map<String, dynamic>>> denounce(
    String id,
    String reason,
  ) => _client.request(
    '/api/reports/${Uri.encodeComponent(id)}/denunciations',
    body: {'reason': reason},
  );
}
