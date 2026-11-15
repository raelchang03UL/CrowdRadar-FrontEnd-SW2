// PRUEBAS UNITARIAS — CAJA NEGRA (partición de equivalencia + valores límite)
// Unidades: PlaceModel.fromJson, SaturationModel.fromJson, SaturationLevel y UserModel.
// El cliente debe rechazar respuestas del servidor que no cumplan el contrato API.
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/saturation_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> lugar([Map<String, dynamic> cambios = const {}]) => {
  'id': 1,
  'nombre': 'Plaza de Armas',
  'categoria': 'Plaza',
  'latitud': -12.0464,
  'longitud': -77.0302,
  'demostrativo': false,
  ...cambios,
};

Map<String, dynamic> estimacion([Map<String, dynamic> cambios = const {}]) => {
  'placeId': 1,
  'level': 'SATURADO',
  'reportCount': 3,
  'windowMinutes': 30,
  'minimumReports': 3,
  'reason': null,
  'evaluatedAt': '2026-11-13T15:00:00.000Z',
  'updatedAt': '2026-11-13T14:55:00.000Z',
  ...cambios,
};

void main() {
  group('PlaceModel.fromJson — clases de equivalencia', () {
    test('CV: lugar completo y válido', () {
      final modelo = PlaceModel.fromJson(
        lugar({'esFavorito': true, 'direccion': 'Jr. Ejemplo 1'}),
      );
      expect(modelo.id, 1);
      expect(modelo.esFavorito, isTrue);
      expect(modelo.latitud, -12.0464);
    });

    test(
      'CV: esFavorito ausente equivale a false; latitud entera se convierte a double',
      () {
        final modelo = PlaceModel.fromJson(lugar({'latitud': -12}));
        expect(modelo.esFavorito, isFalse);
        expect(modelo.latitud, isA<double>());
      },
    );

    final invalidos = <String, Map<String, dynamic>>{
      'id texto': {'id': '1'},
      'nombre vacío': {'nombre': '   '},
      'categoría nula': {'categoria': null},
      'demostrativo no booleano': {'demostrativo': 'no'},
      'esFavorito no booleano': {'esFavorito': 1},
      'dirección vacía': {'direccion': ''},
      'referencia numérica': {'referencia': 5},
      'latitud texto': {'latitud': '-12'},
    };
    invalidos.forEach((nombre, cambios) {
      test('CNV: $nombre → FormatException', () {
        expect(
          () => PlaceModel.fromJson(lugar(cambios)),
          throwsFormatException,
        );
      });
    });
  });

  group('PlaceModel.fromJson — valores límite de coordenadas', () {
    for (final valido in [-90, 90]) {
      test('latitud $valido es válida', () {
        expect(PlaceModel.fromJson(lugar({'latitud': valido})).latitud, valido);
      });
    }
    for (final invalido in [
      -90.000001,
      90.000001,
      double.nan,
      double.infinity,
    ]) {
      test('latitud $invalido es inválida', () {
        expect(
          () => PlaceModel.fromJson(lugar({'latitud': invalido})),
          throwsFormatException,
        );
      });
    }
    for (final valido in [-180, 180]) {
      test('longitud $valido es válida', () {
        expect(
          PlaceModel.fromJson(lugar({'longitud': valido})).longitud,
          valido,
        );
      });
    }
    for (final invalido in [-180.000001, 180.000001]) {
      test('longitud $invalido es inválida', () {
        expect(
          () => PlaceModel.fromJson(lugar({'longitud': invalido})),
          throwsFormatException,
        );
      });
    }
  });

  test('copyWith solo cambia esFavorito', () {
    final original = PlaceModel.fromJson(lugar());
    final copia = original.copyWith(esFavorito: true);
    expect(copia.esFavorito, isTrue);
    expect(copia.nombre, original.nombre);
    expect(original.copyWith().esFavorito, isFalse);
  });

  group('SaturationModel.fromJson', () {
    test('CV: nivel calculado con votos suficientes', () {
      final modelo = SaturationModel.fromJson(estimacion());
      expect(modelo.level, SaturationLevel.saturado);
      expect(modelo.reason, isNull);
    });

    test('CV: sin reportes → INSUFFICIENT_REPORTS y updatedAt nulo', () {
      final modelo = SaturationModel.fromJson(
        estimacion({
          'level': null,
          'reason': 'INSUFFICIENT_REPORTS',
          'reportCount': 0,
          'updatedAt': null,
        }),
      );
      expect(modelo.reason, SaturationReason.insufficientReports);
    });

    test('CV: empate con votos suficientes', () {
      final modelo = SaturationModel.fromJson(
        estimacion({'level': null, 'reason': 'TIE'}),
      );
      expect(modelo.reason, SaturationReason.tie);
    });

    final incoherentes = <String, Map<String, dynamic>>{
      'nivel fuera del conjunto': {'level': 'LLENO'},
      'motivo desconocido': {'level': null, 'reason': 'OTRO'},
      'nivel con menos votos que el mínimo (límite 2 < 3)': {'reportCount': 2},
      'INSUFFICIENT con votos suficientes': {
        'level': null,
        'reason': 'INSUFFICIENT_REPORTS',
      },
      'sin nivel ni motivo': {'level': null},
      'placeId 0': {'placeId': 0},
      'placeId fuera de INTEGER': {'placeId': 2147483648},
      'reportCount negativo': {'reportCount': -1},
      'fecha sin zona UTC': {'evaluatedAt': '2026-11-13T15:00:00'},
      'fecha inexistente': {'evaluatedAt': '2026-02-30T15:00:00Z'},
      'updatedAt posterior a evaluatedAt': {
        'updatedAt': '2026-11-13T15:00:01.000Z',
      },
      'updatedAt fuera de la ventana de 30 min': {
        'updatedAt': '2026-11-13T14:29:59.000Z',
      },
    };
    incoherentes.forEach((nombre, cambios) {
      test('CNV: $nombre → FormatException', () {
        expect(
          () => SaturationModel.fromJson(estimacion(cambios)),
          throwsFormatException,
        );
      });
    });

    test('CNV: falta la clave reason → FormatException', () {
      expect(
        () => SaturationModel.fromJson(estimacion()..remove('reason')),
        throwsFormatException,
      );
    });

    test('valor límite: updatedAt exactamente 30 min antes es válido', () {
      expect(
        () => SaturationModel.fromJson(
          estimacion({'updatedAt': '2026-11-13T14:30:00.000Z'}),
        ),
        returnsNormally,
      );
    });

    test('validPlaceId: límites de INTEGER', () {
      expect(SaturationModel.validPlaceId(2147483647), isTrue);
      expect(SaturationModel.validPlaceId(-2147483648), isTrue);
      expect(SaturationModel.validPlaceId(-2147483649), isFalse);
      expect(SaturationModel.validPlaceId('1'), isFalse);
    });
  });

  test('SaturationLevel: valor de la API y etiqueta de cada miembro', () {
    expect(SaturationLevel.values.map((n) => n.valorApi), [
      'TRANQUILO',
      'MODERADO',
      'SATURADO',
    ]);
    expect(SaturationLevel.moderado.etiqueta, 'Moderado');
  });

  test(
    'UserModel: fromJson/toJson conservan los datos y karma ausente es 0',
    () {
      final json = {'id': 3, 'nombre': 'Ana', 'email': 'ana@crowdradar.test'};
      final usuario = UserModel.fromJson(json);
      expect(usuario.karmaPoints, 0);
      expect(UserModel.fromJson(usuario.toJson()).email, 'ana@crowdradar.test');
      expect(usuario.copyWith(karmaPoints: 20).karmaPoints, 20);
    },
  );
}
