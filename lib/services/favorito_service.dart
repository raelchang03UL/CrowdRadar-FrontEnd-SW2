import 'dart:convert';
import 'package:http/http.dart' as http;
import '../configs/api_config.dart';

class FavoritoService {
  final String baseUrl = "${ApiConfig.baseUrl}/favorites";

  Map<String, String> _getHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<bool> agregarFavorito(String token, int idLugar) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: _getHeaders(token),
        body: jsonEncode({'id_lugar': idLugar}),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>?> obtenerFavoritos(String token) async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<bool> eliminarFavorito(String token, int idLugar) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$idLugar'),
        headers: _getHeaders(token),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}