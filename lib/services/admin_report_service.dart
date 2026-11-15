import '../configs/generic_response.dart';
import '../models/admin_report.dart';
import 'api_json_client.dart';

class AdminReportService {
  final ApiJsonClient _client;
  AdminReportService({ApiJsonClient? client})
    : _client = client ?? ApiJsonClient();
  GenericResponse<T> _failure<T>(
    GenericResponse<dynamic> result,
  ) => GenericResponse(
    success: false,
    error: result.error,
    message: switch (result.error) {
      'ADMIN_REQUIRED' => 'Esta sección está disponible para administradores.',
      'MODERATION_CITIZEN_ONLY' =>
        'Solo puedes moderar reportes de cuentas ciudadanas.',
      'ADMIN_QUERY_INVALID' => 'Revisa el filtro o la página solicitada.',
      'ADMIN_REPORT_NOT_FOUND' ||
      'ADMIN_REPORT_ID_INVALID' => 'El reporte denunciado no está disponible.',
      'REPORT_STATE_CHANGED' =>
        'El reporte o sus denuncias cambiaron. Actualiza la información antes de decidir.',
      'REPORT_MODERATION_INPUT_INVALID' =>
        'Selecciona una decisión y escribe un motivo de hasta 500 caracteres.',
      _ => result.message,
    },
  );
  Future<GenericResponse<AdminReportPage>> list({
    String state = 'PENDING',
    int? authorId,
    String? before,
  }) async {
    final path = Uri(
      path: '/api/admin/reports',
      queryParameters: {
        'state': state,
        if (authorId != null) 'authorId': '$authorId',
        'before': ?before,
      },
    ).toString();
    final result = await _client.request(path);
    if (!result.success) return _failure(result);
    try {
      final reports = (result.data!['data'] as List)
          .map((e) => AdminReport.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      final next =
          (result.data!['pagination'] as Map<String, dynamic>)['nextBefore'];
      if (reports.length > 20 ||
          (next != null &&
              (!validAdminReportId(next) ||
                  reports.isEmpty ||
                  next != reports.last.id))) {
        throw const FormatException('Página inválida');
      }
      var previous = before == null
          ? BigInt.parse('9223372036854775808')
          : BigInt.parse(before);
      for (final report in reports) {
        final id = BigInt.parse(report.id);
        if (id >= previous ||
            (authorId != null && report.authorId != authorId) ||
            (state != 'ALL' && report.reviewState != state)) {
          throw const FormatException('Reporte fuera del filtro');
        }
        previous = id;
      }
      return GenericResponse(
        success: true,
        data: AdminReportPage(reports, next as String?),
      );
    } catch (_) {
      return const GenericResponse(
        success: false,
        message: 'No pudimos leer los reportes denunciados.',
      );
    }
  }

  Future<GenericResponse<AdminReportDetail>> detail(
    String id, {
    String? beforeHistory,
  }) async {
    final path = Uri(
      path: '/api/admin/reports/$id',
      queryParameters: beforeHistory == null
          ? null
          : {'beforeHistory': beforeHistory},
    ).toString();
    final result = await _client.request(path);
    if (!result.success) return _failure(result);
    try {
      final detail = AdminReportDetail.fromJson(
        result.data!,
        beforeHistory: beforeHistory,
      );
      if (detail.report.id != id) {
        throw const FormatException('Reporte distinto');
      }
      return GenericResponse(success: true, data: detail);
    } catch (_) {
      return const GenericResponse(
        success: false,
        message: 'No pudimos leer la revisión del reporte.',
      );
    }
  }

  Future<GenericResponse<AdminReportDetail>> decide(
    AdminReport report,
    String decision,
    String reason,
  ) async {
    final result = await _client.request(
      '/api/admin/reports/${report.id}/decision',
      body: {
        'decision': decision,
        'reason': reason.trim(),
        'expectedVersion': report.moderationVersion,
        'expectedDenunciationCount': report.denunciationCount,
      },
    );
    const uncertain =
        'No pudimos confirmar si la decisión se guardó. Actualiza el reporte y su historial antes de intentarlo otra vez.';
    if (!result.success) {
      if (['UNAVAILABLE', 'SERVICE_UNAVAILABLE'].contains(result.error)) {
        return const GenericResponse(
          success: false,
          error: 'MODERATION_UNCERTAIN',
          message: uncertain,
        );
      }
      return _failure(result);
    }
    try {
      final detail = AdminReportDetail.fromJson(result.data!);
      if (detail.report.id != report.id ||
          detail.report.moderationVersion != report.moderationVersion + 1 ||
          detail.report.denunciationCount != report.denunciationCount ||
          detail.report.reviewState !=
              (decision == 'KEEP' ? 'KEPT' : 'REMOVED')) {
        throw const FormatException('Decisión incoherente');
      }
      return GenericResponse(success: true, data: detail);
    } catch (_) {
      return const GenericResponse(
        success: false,
        error: 'MODERATION_UNCERTAIN',
        message: uncertain,
      );
    }
  }
}
