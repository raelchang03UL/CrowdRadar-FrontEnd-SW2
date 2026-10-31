import 'dart:convert';

import 'package:http/http.dart' as http;

import '../configs/api_config.dart';
import 'session_service.dart';

class PushDeviceService {
  Future<String> register({
    required String sessionToken,
    required String deviceToken,
    required String platform,
    required int generation,
    String targetType = 'fid',
  }) async {
    final response = await http
        .post(
          ApiConfig.uri(ApiConfig.notificationDevices),
          headers: ApiConfig.authHeaders(sessionToken),
          body: jsonEncode({
            'token': deviceToken,
            'platform': platform,
            'targetType': targetType,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      SessionService.rejectIfCurrent(
        token: sessionToken,
        generation: generation,
      );
    }
    if (response.statusCode != 200) {
      throw StateError('No se pudo registrar el dispositivo para alertas.');
    }
    final body = jsonDecode(response.body);
    final data = body is Map ? body['data'] : null;
    final id = data is Map ? data['registrationId'] : null;
    if (id is! String || id.isEmpty) {
      throw const FormatException('Registro inválido');
    }
    return id;
  }

  Future<void> unregister({
    required String sessionToken,
    required String deviceToken,
    required String registrationId,
  }) async {
    final response = await http
        .delete(
          ApiConfig.uri(ApiConfig.notificationDevices),
          headers: ApiConfig.authHeaders(sessionToken),
          body: jsonEncode({
            'token': deviceToken,
            'registrationId': registrationId,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 204) {
      throw StateError('No se pudo desactivar este dispositivo para alertas.');
    }
  }
}
