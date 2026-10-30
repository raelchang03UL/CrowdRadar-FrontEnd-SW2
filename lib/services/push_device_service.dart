import 'dart:convert';

import 'package:http/http.dart' as http;

import '../configs/api_config.dart';

class PushDeviceService {
  Future<void> register({
    required String sessionToken,
    required String deviceToken,
    required String platform,
  }) async {
    final response = await http
        .post(
          ApiConfig.uri(ApiConfig.notificationDevices),
          headers: ApiConfig.authHeaders(sessionToken),
          body: jsonEncode({'token': deviceToken, 'platform': platform}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('No se pudo registrar el dispositivo para alertas.');
    }
  }

  Future<void> unregister({
    required String sessionToken,
    required String deviceToken,
  }) async {
    final response = await http
        .delete(
          ApiConfig.uri(ApiConfig.notificationDevices),
          headers: ApiConfig.authHeaders(sessionToken),
          body: jsonEncode({'token': deviceToken}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 204) {
      throw StateError('No se pudo desactivar este dispositivo para alertas.');
    }
  }
}
