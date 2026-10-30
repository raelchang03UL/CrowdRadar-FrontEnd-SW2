import 'dart:convert';
import 'package:http/http.dart' as http;
import '../configs/api_config.dart';
import '../configs/generic_response.dart';
import '../models/place_model.dart';
import '../models/saturation_model.dart';
import 'session_service.dart';

class PlaceService {
  static const loadError =
      'No pudimos cargar los lugares. Comprueba tu conexión y vuelve a intentarlo.';
  static const filtroError =
      'El nivel de saturación no es válido. Selecciona nuevamente el filtro.';
  Future<GenericResponse<List<PlaceModel>>> getPlacesBySaturation(
    SaturationLevel nivel,
  ) => _getList(nivel: nivel);
  static const categoriesError =
      'No pudimos cargar las categorías. Vuelve a intentarlo.';
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

  Future<GenericResponse<List<PlaceModel>>> filterPlacesByCategory(
    String categoria,
  ) {
    if (categoria.trim().runes.length > 80) {
      return Future.value(
        const GenericResponse(
          success: false,
          message: 'Selecciona una categoría de hasta 80 caracteres.',
        ),
      );
    }
    return queryPlaces(categoria: categoria.trim());
  }

  Future<GenericResponse<List<PlaceModel>>> queryPlaces({
    String nombre = '',
    String categoria = '',
    SaturationLevel? nivel,
  }) => _getList(nombre: nombre, categoria: categoria, nivel: nivel);

  Future<GenericResponse<List<PlaceModel>>> _getList({
    String endpoint = ApiConfig.places,
    String? nombre,
    String? categoria,
    SaturationLevel? nivel,
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
      final query = {
        if (nombre != null && nombre.isNotEmpty) 'nombre': nombre,
        if (categoria != null && categoria.isNotEmpty) 'categoria': categoria,
        if (nivel != null) 'nivel': nivel.valorApi,
      };
      final response = await http
          .get(
            ApiConfig.uri(
              endpoint,
            ).replace(queryParameters: query.isEmpty ? null : query),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(const Duration(seconds: 15));
      if (generation != SessionService.generation) return _sessionChanged();
      if (response.statusCode == 401) {
        SessionService.rejectIfCurrent(token: token, generation: generation);
        return const GenericResponse(
          success: false,
          message: 'Tu sesión no es válida. Vuelve a iniciar sesión.',
        );
      }
      if (response.statusCode != 200) {
        if (response.statusCode == 400) {
          final body = jsonDecode(utf8.decode(response.bodyBytes));
          if (body is Map && body['code'] == 'SATURATION_FILTER_INVALID') {
            return const GenericResponse(success: false, message: filtroError);
          }
        }
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
        SessionService.rejectIfCurrent(token: token, generation: generation);
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
        SessionService.rejectIfCurrent(token: token, generation: generacion);
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

  static const favoriteAlreadyExists = 'FAVORITE_ALREADY_EXISTS';
  static const favoriteError =
      'No pudimos eliminar el favorito. Comprueba tu conexión y vuelve a intentarlo.';

  Future<GenericResponse<List<PlaceModel>>> getFavorites() =>
      _getList(endpoint: ApiConfig.favorites);

  Future<GenericResponse<bool>> removeFavorite(int placeId) async {
    final generation = SessionService.generation;
    final token = SessionService.token;
    if (token == null || !SessionService.isAuthenticated) {
      return const GenericResponse(success: false, message: 'Inicia sesión para eliminar lugares favoritos.');
    }
    try {
      final response = await http.delete(
        ApiConfig.uri('${ApiConfig.places}/$placeId/favorite'),
        headers: ApiConfig.authHeaders(token),
      ).timeout(const Duration(seconds: 15));
      if (generation != SessionService.generation) return _sessionChanged();
      if (response.statusCode == 401) {
        SessionService.rejectIfCurrent(token: token, generation: generation);
        return const GenericResponse(success: false, message: 'Tu sesión no es válida. Vuelve a iniciar sesión.');
      }
      if (response.statusCode == 204) return const GenericResponse(success: true, data: true);
      return const GenericResponse(success: false, message: favoriteError);
    } catch (_) {
      if (generation != SessionService.generation) return _sessionChanged();
      return const GenericResponse(success: false, message: favoriteError);
    }
  }
  Future<GenericResponse<bool>> addFavorite(int placeId) async {
    final generation = SessionService.generation;
    final token = SessionService.token;
    if (token == null || !SessionService.isAuthenticated) {
      return const GenericResponse(
        success: false,
        message: 'Inicia sesión para guardar lugares favoritos.',
      );
    }
    try {
      final response = await http
          .post(
            ApiConfig.uri('${ApiConfig.places}/$placeId/favorite'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(const Duration(seconds: 15));
      if (generation != SessionService.generation) {
        return const GenericResponse(
          success: false,
          message: 'La sesión cambió durante la solicitud',
        );
      }
      if (response.statusCode == 401) {
        SessionService.rejectIfCurrent(token: token, generation: generation);
        return const GenericResponse(success: false, message: 'Tu sesión no es válida. Vuelve a iniciar sesión.');
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Respuesta de favorito inválida');
      }
      if (response.statusCode == 201 &&
          body['data'] is Map<String, dynamic> &&
          body['data']['esFavorito'] == true) {
        return GenericResponse(
          success: true,
          data: true,
          message: body['message'] is String ? body['message'] as String : '',
        );
      }
      if (response.statusCode == 409 && body['code'] == favoriteAlreadyExists) {
        return GenericResponse(
          success: false,
          message: body['message'] is String
              ? body['message'] as String
              : 'Este lugar ya pertenece a tus favoritos.',
          error: favoriteAlreadyExists,
        );
      }
      if (response.statusCode == 401) {
        return const GenericResponse(
          success: false,
          message: 'Tu sesión no es válida. Vuelve a iniciar sesión.',
        );
      }
      if (response.statusCode == 404) {
        return const GenericResponse(
          success: false,
          message: 'El lugar ya no está disponible.',
        );
      }
      return const GenericResponse(success: false, message: favoriteError);
    } catch (_) {
      if (generation != SessionService.generation) {
        return const GenericResponse(
          success: false,
          message: 'La sesión cambió durante la solicitud',
        );
      }
      return const GenericResponse(success: false, message: favoriteError);
    }
  }

  GenericResponse<T> _sessionChanged<T>() => const GenericResponse(
    success: false,
    message: 'La sesión cambió durante la solicitud',
  );
}
