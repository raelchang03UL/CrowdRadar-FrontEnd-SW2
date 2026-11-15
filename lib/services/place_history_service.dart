import '../configs/generic_response.dart';
import 'api_json_client.dart';

class PlaceHistoryService {
  final ApiJsonClient _client;
  PlaceHistoryService({ApiJsonClient? client})
    : _client = client ?? ApiJsonClient();
  Future<GenericResponse<Map<String, dynamic>>> load(
    int id,
    String mode,
    Map<String, String> period,
  ) async {
    final query = Uri(queryParameters: period).query;
    final result = await _client.request('/api/places/$id/$mode?$query');
    if (!result.success) {
      return result;
    }
    final data = result.data?['data'];
    if (data is! Map<String, dynamic> || !_valid(mode, data)) {
      return const GenericResponse(
        success: false,
        message: 'No pudimos leer el análisis.',
      );
    }
    return GenericResponse(success: true, data: data);
  }

  bool _valid(String mode, Map<String, dynamic> data) {
    bool count(dynamic value) => value is int && value >= 0;
    bool instant(dynamic value) =>
        value is String && DateTime.tryParse(value) != null;
    bool history(dynamic value) {
      if (value is! Map<String, dynamic> ||
          value['counts'] is! Map ||
          value['blocks'] is! List ||
          value['hasReports'] is! bool) {
        return false;
      }
      final counts = value['counts'] as Map;
      if (![
            'TRANQUILO',
            'MODERADO',
            'SATURADO',
          ].every((key) => count(counts[key])) ||
          !count(value['sufficient']) ||
          !count(value['insufficient'])) {
        return false;
      }
      final blocks = value['blocks'] as List;
      return blocks.length <= 744 &&
          blocks.every(
            (item) =>
                item is Map &&
                instant(item['start']) &&
                instant(item['end']) &&
                count(item['reportCount']) &&
                [
                  null,
                  'TRANQUILO',
                  'MODERADO',
                  'SATURADO',
                ].contains(item['level']),
          );
    }

    if (mode == 'history') return history(data);
    if (mode == 'comparison') {
      return data['comparable'] is bool &&
          history(data['first']) &&
          history(data['second']);
    }
    if (mode == 'quiet-hours') {
      return [
            null,
            'INSUFFICIENT_HISTORY',
            'NO_QUIET_HOURS',
          ].contains(data['reason']) &&
          data['recommendations'] is List &&
          (data['recommendations'] as List).every(
            (item) =>
                item is Map &&
                item['hour'] is int &&
                item['hour'] >= 0 &&
                item['hour'] < 24 &&
                item['days'] is int &&
                item['days'] >= 3 &&
                item['days'] <= 31 &&
                count(item['quietDays']) &&
                item['quietDays'] <= item['days'] &&
                item['rank'] is int &&
                item['rank'] > 0,
          );
    }
    return false;
  }
}
