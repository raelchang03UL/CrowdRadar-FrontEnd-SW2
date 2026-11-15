import 'dart:convert';

import '../configs/api_config.dart';

class RestorableSession {
  const RestorableSession(this.token, this.alertsEnabled);
  final String token;
  final bool alertsEnabled;
}

// Filtro de formato/expiración, nunca verifica autenticidad ni concede acceso.
bool isRestorableJwt(String token, DateTime now) {
  try {
    if (token.length > 8192) return false;
    final parts = token.split('.');
    if (parts.length != 3 ||
        parts.any((part) => !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(part))) {
      return false;
    }
    final header = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
    );
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (base64Url.decode(base64Url.normalize(parts[2])).isEmpty) return false;
    return header is Map<String, dynamic> &&
        header['alg'] == 'HS256' &&
        claims is Map<String, dynamic> &&
        claims['exp'] is int &&
        (claims['exp'] as int) > now.millisecondsSinceEpoch / 1000;
  } catch (_) {
    return false;
  }
}

RestorableSession? decodeStoredSession(String record, DateTime now) {
  try {
    if (record.length > 9000) return null;
    final decoded = jsonDecode(record);
    if (decoded is! Map<String, dynamic> ||
        decoded.keys.any(
          (key) => !{
            'version',
            'apiOrigin',
            'token',
            'alertsEnabledForReload',
          }.contains(key),
        ) ||
        decoded['version'] != 1 ||
        decoded['apiOrigin'] != ApiConfig.baseUrl ||
        decoded['token'] is! String ||
        (decoded.containsKey('alertsEnabledForReload') &&
            decoded['alertsEnabledForReload'] is! bool)) {
      return null;
    }
    final token = decoded['token'] as String;
    return isRestorableJwt(token, now)
        ? RestorableSession(token, decoded['alertsEnabledForReload'] == true)
        : null;
  } catch (_) {
    return null;
  }
}

String encodeStoredSession(String token, bool alertsEnabled) => jsonEncode({
  'version': 1,
  'apiOrigin': ApiConfig.baseUrl,
  'token': token,
  'alertsEnabledForReload': alertsEnabled,
});
