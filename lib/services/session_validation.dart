import 'dart:convert';

import 'package:http/http.dart' as http;

import '../configs/api_config.dart';
import '../models/user_model.dart';

enum SessionValidationStatus { valid, invalid, retryRequired }

class SessionValidationResult {
  const SessionValidationResult.valid(UserModel value)
    : status = SessionValidationStatus.valid,
      user = value;
  const SessionValidationResult.invalid()
    : status = SessionValidationStatus.invalid,
      user = null;
  const SessionValidationResult.retryRequired()
    : status = SessionValidationStatus.retryRequired,
      user = null;
  final SessionValidationStatus status;
  final UserModel? user;
}

typedef SessionValidator =
    Future<SessionValidationResult> Function(String token);

bool isRestoredUserValid(UserModel? user) =>
    user != null &&
    user.id != null &&
    user.id! > 0 &&
    user.id! <= 2147483647 &&
    {'USUARIO', 'ADMIN'}.contains(user.rol) &&
    user.status == 'ACTIVO';

Future<SessionValidationResult> validateStoredSession(
  String token, {
  required String cacheKey,
}) async {
  try {
    final uri = ApiConfig.uri(ApiConfig.profile);
    final response = await http
        .get(
          uri.replace(
            queryParameters: {
              ...uri.queryParameters,
              '_sessionCheck': cacheKey,
            },
          ),
          headers: ApiConfig.authHeaders(token),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      return const SessionValidationResult.invalid();
    }
    if (response.statusCode != 200) {
      return const SessionValidationResult.retryRequired();
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final data = body is Map<String, dynamic> ? body['data'] : null;
    if (data is! Map<String, dynamic>) {
      return const SessionValidationResult.retryRequired();
    }
    final user = UserModel.fromJson(data);
    return isRestoredUserValid(user)
        ? SessionValidationResult.valid(user)
        : const SessionValidationResult.retryRequired();
  } catch (_) {
    return const SessionValidationResult.retryRequired();
  }
}
