import 'dart:convert';
import 'package:http/http.dart' as http;
import '../configs/api_config.dart';
import '../configs/generic_response.dart';
import '../models/place_model.dart';
import 'session_service.dart';

class PlaceService {
  static const loadError =
      'No pudimos cargar los lugares. Comprueba tu conexión y vuelve a intentarlo.';
  static const detailError =
      'No pudimos cargar la información del lugar. Comprueba tu conexión y vuelve a intentarlo.';
  static const invalidSearch = 'Busca por nombre usando hasta 160 caracteres.';

  Future<GenericResponse<List<PlaceModel>>> getPlaces() => _getList();

  Future<GenericResponse<List<PlaceModel>>> searchPlaces(String consulta) {
    final nombre = consulta.trim();
    if (nombre.length > 160) {
      return Future.value(
        const GenericResponse(success: false, message: invalidSearch),
      );
    }
    return _getList(nombre: nombre);
  }

  Future<GenericResponse<List<PlaceModel>>> _getList({String? nombre}) async {
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
            ApiConfig.uri(ApiConfig.places).replace(
              queryParameters: nombre == null ? null : {'nombre': nombre},
            ),
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

  Future<GenericResponse<PlaceModel>> getPlace(int id) async {
    final generation = SessionService.generation;
    final token = SessionService.token;
    if (token == null || !SessionService.isAuthenticated) {
      return const GenericResponse(
        success: false,
        message: 'Inicia sesión para ver los lugares.',
      );
    }
    if (id == 0 || id < -2147483648 || id > 2147483647) {
      return const GenericResponse(
        success: false,
        message: 'El identificador del lugar no es válido.',
      );
    }
    try {
      final response = await http
          .get(
            ApiConfig.uri('${ApiConfig.places}/$id'),
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
          message: 'El lugar no está disponible.',
        );
      }
      if (response.statusCode != 200) {
        return const GenericResponse(success: false, message: detailError);
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic> ||
          body['data'] is! Map<String, dynamic>) {
        throw const FormatException('Detalle inválido');
      }
      final place = PlaceModel.fromJson(body['data'] as Map<String, dynamic>);
      if (place.id != id) {
        throw const FormatException('Lugar diferente al solicitado');
      }
      return GenericResponse(success: true, data: place);
    } catch (_) {
      if (generation != SessionService.generation) return _sessionChanged();
      return const GenericResponse(success: false, message: detailError);
    }
  }

  GenericResponse<T> _sessionChanged<T>() => const GenericResponse(
    success: false,
    message: 'La sesión cambió durante la solicitud',
  );
}
