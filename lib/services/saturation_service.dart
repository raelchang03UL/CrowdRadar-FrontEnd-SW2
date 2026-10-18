import 'dart:convert';
import 'package:http/http.dart' as http;
import '../configs/api_config.dart';
import '../configs/generic_response.dart';
import '../models/saturation_model.dart';
import 'session_service.dart';

class SaturationService {
  static const loadError =
      'No pudimos consultar la saturación. Comprueba tu conexión y vuelve a intentarlo.';

  Future<GenericResponse<SaturationModel>> getSaturation(int placeId) async {
    final generation = SessionService.generation;
    final token = SessionService.token;
    if (token == null || !SessionService.isAuthenticated) {
      return const GenericResponse(
        success: false,
        message: 'Inicia sesión para consultar la saturación.',
      );
    }
    if (!SaturationModel.validPlaceId(placeId)) {
      return const GenericResponse(
        success: false,
        message: 'El lugar seleccionado no es válido.',
      );
    }
    try {
      final response = await http
          .get(
            ApiConfig.uri('${ApiConfig.places}/$placeId/saturation'),
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
      if (response.statusCode == 404) {
        return const GenericResponse(
          success: false,
          message: 'Este lugar ya no está disponible.',
        );
      }
      if (response.statusCode != 200) {
        return const GenericResponse(success: false, message: loadError);
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic> ||
          body['data'] is! Map<String, dynamic>) {
        throw const FormatException('Respuesta inválida');
      }
      final data = SaturationModel.fromJson(body['data']);
      if (data.placeId != placeId) {
        throw const FormatException('Respuesta para otro lugar');
      }
      return GenericResponse(success: true, data: data);
    } catch (_) {
      if (generation != SessionService.generation) return _sessionChanged();
      return const GenericResponse(success: false, message: loadError);
    }
  }

  GenericResponse<SaturationModel> _sessionChanged() => const GenericResponse(
    success: false,
    message: 'La sesión cambió durante la solicitud',
  );
}
