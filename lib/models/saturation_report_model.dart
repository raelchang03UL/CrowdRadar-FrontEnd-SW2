class SaturationReportModel {
  final int id;
  final DateTime createdAt;
  final String level;
  final int placeId;
  final String placeName;

  const SaturationReportModel({
    required this.id,
    required this.createdAt,
    required this.level,
    required this.placeId,
    required this.placeName,
  });

  factory SaturationReportModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final level = json['level'];
    final placeId = json['placeId'];
    final placeName = json['placeName'];
    if (id is! int ||
        createdAt == null ||
        level is! String ||
        level.isEmpty ||
        placeId is! int ||
        placeName is! String ||
        placeName.trim().isEmpty) {
      throw const FormatException('Información de reporte inválida');
    }
    return SaturationReportModel(
      id: id,
      createdAt: createdAt,
      level: level,
      placeId: placeId,
      placeName: placeName,
    );
  }

  String get levelLabel => switch (level) {
    'TRANQUILO' => 'Tranquilo',
    'MODERADO' => 'Moderado',
    'SATURADO' => 'Saturado',
    _ => level,
  };
}
