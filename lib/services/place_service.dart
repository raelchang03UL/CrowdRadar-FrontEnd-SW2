import 'dart:convert';
import 'package:http/http.dart' as http;
import '../configs/api_config.dart';
import '../configs/generic_response.dart';
import '../models/place_model.dart';
import 'session_service.dart';

class PlaceService {
  static const loadError =
      'No pudimos cargar los lugares. Comprueba tu conexión y vuelve a intentarlo.';
  static const categoriesError =
      'No pudimos cargar las categorías. Vuelve a intentarlo.';

  Future<GenericResponse<List<PlaceModel>>> getPlaces() => _getPlaces();

  Future<GenericResponse<List<PlaceModel>>> filterPlacesByCategory(
    String categoria,
  ) {
    final filtro = categoria.trim();
    if (filtro.runes.length > 80) {
      return Future.value(
        const GenericResponse(
          success: false,
          message: 'Selecciona una categoría de hasta 80 caracteres.',
        ),
      );
    }
    return _getPlaces(categoria: filtro);
  }

  Future<GenericResponse<List<PlaceModel>>> _getPlaces({
    String? categoria,
  }) async {
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
              queryParameters: categoria == null || categoria.isEmpty
                  ? null
                  : {'categoria': categoria},
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

  Future<GenericResponse<List<String>>> getCategories() async {
    final generacion = SessionService.generation;
    final token = SessionService.token;
    if (token == null || !SessionService.isAuthenticated) {
      return const GenericResponse(
        success: false,
        message: 'Inicia sesión para ver las categorías.',
      );
    }
    try {
      final respuesta = await http
          .get(
            ApiConfig.uri('${ApiConfig.places}/categories'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(const Duration(seconds: 15));
      if (generacion != SessionService.generation) return _sessionChanged();
      if (respuesta.statusCode == 401) {
        return const GenericResponse(
          success: false,
          message: 'Tu sesión no es válida. Vuelve a iniciar sesión.',
        );
      }
      if (respuesta.statusCode != 200) {
        return const GenericResponse(success: false, message: categoriesError);
      }
      final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (cuerpo is! Map<String, dynamic> || cuerpo['data'] is! List) {
        throw const FormatException('Categorías inválidas');
      }
      final categorias = (cuerpo['data'] as List)
          .map((categoria) {
            if (categoria is! String ||
                categoria.trim().isEmpty ||
                categoria != categoria.trim() ||
                categoria.runes.length > 80) {
              throw const FormatException('Categoría inválida');
            }
            return categoria;
          })
          .toSet()
          .toList(growable: false);
      return GenericResponse(
        success: true,
        data: List.unmodifiable(categorias),
      );
    } catch (_) {
      if (generacion != SessionService.generation) return _sessionChanged();
      return const GenericResponse(success: false, message: categoriesError);
    }
  }

  GenericResponse<T> _sessionChanged<T>() => const GenericResponse(
    success: false,
    message: 'La sesión cambió durante la solicitud',
  );
}
