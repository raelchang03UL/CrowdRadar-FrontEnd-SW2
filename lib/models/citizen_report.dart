class CitizenReport {
  final String id, placeName, level;
  final int placeId, confirmations, rejections, confirmWeight, totalWeight;
  final DateTime createdAt;
  final bool isOwn, alreadyDenounced;
  final String? ownDecision, reliability;
  const CitizenReport({
    required this.id,
    required this.placeName,
    required this.placeId,
    required this.level,
    required this.createdAt,
    required this.confirmations,
    required this.rejections,
    required this.confirmWeight,
    required this.totalWeight,
    required this.isOwn,
    required this.alreadyDenounced,
    this.ownDecision,
    this.reliability,
  });
  factory CitizenReport.fromJson(Map<String, dynamic> data) {
    final confidence = data['reliability'] as Map<String, dynamic>;
    int count(dynamic value) {
      if (value is! int || value < 0) {
        throw const FormatException('Conteo inválido');
      }
      return value;
    }

    final id = data['id'];
    if (id is! String || !RegExp(r'^[1-9]\d*$').hasMatch(id)) {
      throw const FormatException('ID inválido');
    }
    if (!['TRANQUILO', 'MODERADO', 'SATURADO'].contains(data['level']) ||
        ![null, 'ALTO', 'MEDIO', 'BAJO'].contains(confidence['level']) ||
        ![null, 'CONFIRM', 'REJECT'].contains(data['ownDecision'])) {
      throw const FormatException('Nivel inválido');
    }
    return CitizenReport(
      id: id,
      placeId: data['placeId'] as int,
      placeName: data['placeName'] as String,
      level: data['level'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
      confirmations: count(data['confirmations']),
      rejections: count(data['rejections']),
      confirmWeight: count(confidence['confirmWeight']),
      totalWeight: count(confidence['totalWeight']),
      isOwn: data['isOwn'] as bool,
      alreadyDenounced: data['alreadyDenounced'] as bool,
      ownDecision: data['ownDecision'] as String?,
      reliability: confidence['level'] as String?,
    );
  }
}
