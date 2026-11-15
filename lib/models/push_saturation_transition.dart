import 'saturation_model.dart';

enum PushSaturationLevel {
  noData(null),
  tranquilo(SaturationLevel.tranquilo),
  moderado(SaturationLevel.moderado),
  saturado(SaturationLevel.saturado);

  final SaturationLevel? _level;
  const PushSaturationLevel(this._level);

  String get apiValue => _level?.valorApi ?? 'SIN_DATOS';
  String get label => _level?.etiqueta ?? 'Sin datos';

  static PushSaturationLevel? parse(Object? value) {
    for (final level in values) {
      if (value == level.apiValue) return level;
    }
    return null;
  }
}

// Datos históricos de la alerta, distintos de la estimación actual de la API.
class PushSaturationTransition {
  final PushSaturationLevel previousLevel;
  final PushSaturationLevel newLevel;

  const PushSaturationTransition._(this.previousLevel, this.newLevel);

  static PushSaturationTransition? fromPayload(Map<String, dynamic> data) {
    final previous = PushSaturationLevel.parse(data['previousLevel']);
    final next = PushSaturationLevel.parse(data['newLevel']);
    if (previous == null || next == null || previous == next) return null;
    return PushSaturationTransition._(previous, next);
  }
}
