import 'dart:convert';
import 'package:http/http.dart' as http;

class FavoritoService {
  // Ajusta el IP o dominio según donde corra tu Backend Node.js
  final String baseUrl = "http://10.0.2.2:3000/api/favorites"; 

  // HU 8.1: Guardar favorito
  Future<bool> agregarFavorito(int idUsuario, int idLugar) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_usuario': idUsuario, 'id_lugar': idLugar}),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // HU 8.2: Listar favoritos
  Future<List<dynamic>> obtenerFavoritos(int idUsuario) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/$idUsuario'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // HU 8.3: Cambiar alertas
  Future<bool> cambiarAlertas(int idUsuario, bool activadas) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/alertas'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_usuario': idUsuario, 'alertas_activadas': activadas}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // HU 8.4: Eliminar favorito
  Future<bool> eliminarFavorito(int idUsuario, int idLugar) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/$idUsuario/$idLugar'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}