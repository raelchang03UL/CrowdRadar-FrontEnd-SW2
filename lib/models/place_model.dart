class PlaceModel {
  final int id;
  final String nombre;
  final String categoria;
  final double latitud;
  final double longitud;
  final bool demostrativo;

  const PlaceModel({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.latitud,
    required this.longitud,
    required this.demostrativo,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nombre = json['nombre'];
    final categoria = json['categoria'];
    final latitud = json['latitud'];
    final longitud = json['longitud'];
    final demostrativo = json['demostrativo'];
    if (id is! int ||
        nombre is! String ||
        nombre.trim().isEmpty ||
        categoria is! String ||
        categoria.trim().isEmpty ||
        latitud is! num ||
        !latitud.isFinite ||
        latitud < -90 ||
        latitud > 90 ||
        longitud is! num ||
        !longitud.isFinite ||
        longitud < -180 ||
        longitud > 180 ||
        demostrativo is! bool) {
      throw const FormatException('Información de lugar inválida');
    }
    return PlaceModel(
      id: id,
      nombre: nombre,
      categoria: categoria,
      latitud: latitud.toDouble(),
      longitud: longitud.toDouble(),
      demostrativo: demostrativo,
    );
  }
}
