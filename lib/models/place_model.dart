class PlaceModel {
  final int id;
  final String nombre;
  final String categoria;
  final String? referencia;
  final double latitud;
  final double longitud;
  final bool demostrativo;
  final bool esFavorito;

  const PlaceModel({
    required this.id,
    required this.nombre,
    required this.categoria,
    this.referencia,
    required this.latitud,
    required this.longitud,
    required this.demostrativo,
    this.esFavorito = false,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nombre = json['nombre'];
    final categoria = json['categoria'];
    final referencia = switch (json['referencia']) {
      null => null,
      String value => value,
      _ => throw const FormatException('Referencia de lugar inválida'),
    };
    final latitud = json['latitud'];
    final longitud = json['longitud'];
    final demostrativo = json['demostrativo'];
    final esFavorito = json['esFavorito'];
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
        esFavorito is! bool) {
      throw const FormatException('Información de lugar inválida');
    }
    return PlaceModel(
      id: id,
      nombre: nombre,
      categoria: categoria,
      referencia: referencia,
      latitud: latitud.toDouble(),
      longitud: longitud.toDouble(),
      demostrativo: demostrativo,
      esFavorito: esFavorito,
    );
  }

  PlaceModel copyWith({bool? esFavorito}) => PlaceModel(
    id: id,
    nombre: nombre,
    categoria: categoria,
    referencia: referencia,
    latitud: latitud,
    longitud: longitud,
    demostrativo: demostrativo,
    esFavorito: esFavorito ?? this.esFavorito,
  );
}
