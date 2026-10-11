enum SaturationLevel { tranquilo, moderado, saturado }

enum SaturationReason { insufficientReports, tie }

// Estimación recibida de la API; el cliente no calcula votos ni aforo.
class SaturationModel {
  final int placeId;
  final SaturationLevel? level;
  final int reportCount;
  final int windowMinutes;
  final int minimumReports;
  final SaturationReason? reason;
  final DateTime evaluatedAt;
  final DateTime? updatedAt;

  const SaturationModel({
    required this.placeId,
    required this.level,
    required this.reportCount,
    required this.windowMinutes,
    required this.minimumReports,
    required this.reason,
    required this.evaluatedAt,
    required this.updatedAt,
  });

  factory SaturationModel.fromJson(Map<String, dynamic> json) {
    final placeId = json['placeId'];
    final reportCount = json['reportCount'];
    final windowMinutes = json['windowMinutes'];
    final minimumReports = json['minimumReports'];
    if (!validPlaceId(placeId) ||
        !_positiveInteger(windowMinutes) ||
        !_positiveInteger(minimumReports) ||
        reportCount is! int ||
        reportCount < 0 ||
        reportCount > 2147483647 ||
        !json.containsKey('level') ||
        !json.containsKey('reason') ||
        !json.containsKey('updatedAt')) {
      throw const FormatException('Estimación inválida');
    }
    final level = switch (json['level']) {
      null => null,
      'TRANQUILO' => SaturationLevel.tranquilo,
      'MODERADO' => SaturationLevel.moderado,
      'SATURADO' => SaturationLevel.saturado,
      _ => throw const FormatException('Nivel inválido'),
    };
    final reason = switch (json['reason']) {
      null => null,
      'INSUFFICIENT_REPORTS' => SaturationReason.insufficientReports,
      'TIE' => SaturationReason.tie,
      _ => throw const FormatException('Motivo inválido'),
    };
    if ((level != null && (reason != null || reportCount < minimumReports)) ||
        (level == null && reason == null) ||
        (reason == SaturationReason.insufficientReports &&
            reportCount >= minimumReports) ||
        (reason == SaturationReason.tie && reportCount < minimumReports)) {
      throw const FormatException('Estimación incoherente');
    }
    final evaluatedAt = _utcDate(json['evaluatedAt']);
    final updatedAt = json['updatedAt'] == null
        ? null
        : _utcDate(json['updatedAt']);
    if ((reportCount == 0) != (updatedAt == null) ||
        (updatedAt != null &&
            (updatedAt.isAfter(evaluatedAt) ||
                updatedAt.isBefore(
                  evaluatedAt.subtract(Duration(minutes: windowMinutes)),
                )))) {
      throw const FormatException('Fecha de estimación incoherente');
    }
    return SaturationModel(
      placeId: placeId as int,
      level: level,
      reportCount: reportCount,
      windowMinutes: windowMinutes,
      minimumReports: minimumReports,
      reason: reason,
      evaluatedAt: evaluatedAt,
      updatedAt: updatedAt,
    );
  }

  static bool validPlaceId(Object? value) =>
      value is int && value != 0 && value >= -2147483648 && value <= 2147483647;

  static bool _positiveInteger(Object? value) =>
      value is int && value > 0 && value <= 2147483647;

  static DateTime _utcDate(Object? value) {
    if (value is! String ||
        !RegExp(
          r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$',
        ).hasMatch(value)) {
      throw const FormatException('Fecha inválida');
    }
    final result = DateTime.tryParse(value);
    if (result == null || !result.isUtc) {
      throw const FormatException('Fecha inválida');
    }
    // DateTime.parse normaliza fechas fuera de rango: no aceptarlas del servidor.
    final datePart = value.substring(0, 19);
    if (result.toIso8601String().substring(0, 19) != datePart) {
      throw const FormatException('Fecha fuera de rango');
    }
    return result;
  }
}
