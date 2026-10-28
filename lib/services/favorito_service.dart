import 'dart:convert';
import 'package:http/http.dart' as http;
import '../configs/environment.dart'; // Asegúrate de importar tu configuración global de API si existe

class FavoritoService {
  // Se reutiliza la URL base del entorno o la por defecto sin harcodear la IP
  final String baseUrl = Environment.apiUrl ?? "http://10.0.2.2:3000/api";

  // Helper interno para construir los headers con autenticación JWT
  Map<String, String> _getHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // HU 8.1: Guardar favorito (El backend toma el usuario directamente del JWT)
  Future<bool> agregarFavorito(String token, int idLugar) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/favorites'),
        headers: _getHeaders(token),
        body: jsonEncode({'id_lugar': idLugar}),
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Error al agregar favorito: $e');
      return false;
    }
  }

  // HU 8.2: Listar favoritos del usuario autenticado
  Future<List<dynamic>?> obtenerFavoritos(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/favorites'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data; // Retorna la lista (puede ser una lista vacía [])
      } else {
        print('Error en servidor al obtener favoritos: ${response.statusCode}');
        return null; // Retorna null para indicar error de respuesta/servidor y no lista vacía falsa
      }
    } catch (e) {
      print('Error de red al obtener favoritos: $e');
      return null; // Retorna null para manejar el fallo de red en la UI
    }
  }

  // HU 8.4: Eliminar favorito
  Future<bool> eliminarFavorito(String token, int idLugar) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/favorites/$idLugar'),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error al eliminar favorito: $e');
      return false;
    }
  }
}