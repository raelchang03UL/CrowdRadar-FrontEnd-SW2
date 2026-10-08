class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String profile = '/api/users/profile';
  static const String places = '/api/places';

  static Uri uri(String path) => Uri.parse('$baseUrl$path');

  static const Map<String, String> jsonHeaders = {
    'Content-Type': 'application/json',
  };

  static Map<String, String> authHeaders(String token) => {
    ...jsonHeaders,
    'Authorization': 'Bearer $token',
  };
}
