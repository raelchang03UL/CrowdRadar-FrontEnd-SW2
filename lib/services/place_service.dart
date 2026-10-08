import 'dart:convert';
import 'package:http/http.dart' as http;
import '../configs/api_config.dart';
import '../configs/generic_response.dart';
import '../models/place_model.dart';
import 'session_service.dart';

class PlaceService {
  static const loadError =
      'No pudimos cargar los lugares. Comprueba tu conexión y vuelve a intentarlo.';

  Future<GenericResponse<List<PlaceModel>>> getPlaces() async {
    final generation = SessionService.generation;
    final token = SessionService.token;
    if (token == null || !SessionService.isAuthenticated) {
      return const GenericResponse(
        success: false,
        message: 'Inicia sesión para ver los lugares.',
      );
    }
    try {
      final response = await http
          .get(
            ApiConfig.uri(ApiConfig.places),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(const Duration(seconds: 15));
      if (generation != SessionService.generation) return _sessionChanged();
      if (response.statusCode == 401) {
        return const GenericResponse(
          success: false,
          message: 'Tu sesión no es válida. Vuelve a iniciar sesión.',
        );
      }
      if (response.statusCode != 200) {
        return const GenericResponse(success: false, message: loadError);
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic> || body['data'] is! List) {
        throw const FormatException('Respuesta de lugares inválida');
      }
      final places = (body['data'] as List)
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException('Lugar inválido');
            }
            return PlaceModel.fromJson(item);
          })
          .toList(growable: false);
      return GenericResponse(success: true, data: List.unmodifiable(places));
    } catch (_) {
      if (generation != SessionService.generation) return _sessionChanged();
      return const GenericResponse(success: false, message: loadError);
    }
  }

  GenericResponse<List<PlaceModel>> _sessionChanged() => const GenericResponse(
    success: false,
    message: 'La sesión cambió durante la solicitud',
  );
}
