class PlaceModel {
  final int id;
  final String nombre;
  final String categoria;
  final double latitud;
  final double longitud;
  final bool demostrativo;
  final bool esFavorito;
  final String? direccion;
  final String? referencia;

  const PlaceModel({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.latitud,
    required this.longitud,
    required this.demostrativo,
    this.esFavorito = false,
    this.direccion,
    this.referencia,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nombre = json['nombre'];
    final categoria = json['categoria'];
    final latitud = json['latitud'];
    final longitud = json['longitud'];
    final demostrativo = json['demostrativo'];
    final esFavorito = json['esFavorito'];
    final direccion = json['direccion'];
    final referencia = json['referencia'];
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
        demostrativo is! bool ||
        (esFavorito != null && esFavorito is! bool) ||
        (direccion != null &&
            (direccion is! String || direccion.trim().isEmpty)) ||
        (referencia != null && referencia is! String)) {
      throw const FormatException('Información de lugar inválida');
    }
    return PlaceModel(
      id: id,
      nombre: nombre,
      categoria: categoria,
      latitud: latitud.toDouble(),
      longitud: longitud.toDouble(),
      demostrativo: demostrativo,
      esFavorito: esFavorito == true,
      direccion: direccion as String?,
      referencia: referencia as String?,
    );
  }
  PlaceModel copyWith({bool? esFavorito}) => PlaceModel(
    id: id, nombre: nombre, categoria: categoria, latitud: latitud,
    longitud: longitud, demostrativo: demostrativo,
    direccion: direccion, referencia: referencia,
    esFavorito: esFavorito ?? this.esFavorito,
  );
}
