import 'dart:async';

import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/places/place_history_page.dart';
import 'package:crowdradar/services/place_history_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _history = <String, dynamic>{
  'blocks': <dynamic>[],
  'counts': {'TRANQUILO': 0, 'MODERADO': 0, 'SATURADO': 0},
  'insufficient': 24,
  'sufficient': 0,
  'hasReports': false,
};

Map<String, dynamic> _result(String mode) => switch (mode) {
  'comparison' => {'first': _history, 'second': _history, 'comparable': false},
  'quiet-hours' => {
    'reason': 'INSUFFICIENT_HISTORY',
    'recommendations': <dynamic>[],
  },
  _ => _history,
};

class _HistoryService extends PlaceHistoryService {
  final modes = <String>[];
  final periods = <Map<String, String>>[];
  Completer<GenericResponse<Map<String, dynamic>>>? pending;

  @override
  Future<GenericResponse<Map<String, dynamic>>> load(
    int id,
    String mode,
    Map<String, String> period,
  ) async {
    modes.add(mode);
    periods.add(Map.of(period));
    return pending?.future ??
        GenericResponse(success: true, data: _result(mode));
  }
}

void main() {
  setUp(() {
    SessionService.start(
      token: 'synthetic-history-mode',
      user: const UserModel(id: 1),
    );
  });
  tearDown(SessionService.clear);

  Future<_HistoryService> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _HistoryService();
    await tester.pumpWidget(
      MaterialApp(home: PlaceHistoryPage(id: -1, service: service)),
    );
    await tester.pumpAndSettle();
    expect(service.modes, ['history']);
    expect(find.text('Resumen horario'), findsOneWidget);
    return service;
  }

  ChoiceChip chip(WidgetTester tester, String label) =>
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

  for (final target in ['Comparar', 'Horarios']) {
    for (final input in ['', 'fecha-invalida']) {
      testWidgets(
        'Historial cargado: Desde A ${input.isEmpty ? 'vacía' : 'malformada'} '
        'no cambia a $target; corregir permite consultar',
        (tester) async {
          final service = await open(tester);
          final from = find.byType(TextFormField).first;
          final validFrom = tester.widget<TextFormField>(from).controller!.text;
          await tester.enterText(from, input);
          await tester.tap(find.text(target));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Usa AAAA-MM-DD'), findsOneWidget);
          expect(service.modes, ['history']);
          expect(service.periods, hasLength(1));
          expect(chip(tester, 'Historial').selected, isTrue);
          expect(chip(tester, target).selected, isFalse);
          expect(find.text('Resumen horario'), findsOneWidget);
          expect(find.text('Período A'), findsNothing);
          expect(find.textContaining('recomendar horarios:'), findsNothing);

          await tester.enterText(from, validFrom);
          await tester.tap(find.text(target));
          await tester.pumpAndSettle();

          final expectedMode = target == 'Comparar'
              ? 'comparison'
              : 'quiet-hours';
          expect(tester.takeException(), isNull);
          expect(find.text('Usa AAAA-MM-DD'), findsNothing);
          expect(service.modes, ['history', expectedMode]);
          expect(service.periods.last['from'], validFrom);
          expect(chip(tester, target).selected, isTrue);
          expect(find.text('Resumen horario'), findsNothing);
          if (target == 'Comparar') {
            expect(find.text('Período A'), findsOneWidget);
            expect(find.text('Período B'), findsOneWidget);
          } else {
            expect(find.textContaining('recomendar horarios:'), findsOneWidget);
          }
        },
      );
    }
  }

  testWidgets('modo pendiente bloquea otra consulta hasta cargar sus datos', (
    tester,
  ) async {
    final service = await open(tester);
    final pending = Completer<GenericResponse<Map<String, dynamic>>>();
    service.pending = pending;
    await tester.tap(find.text('Comparar'));
    await tester.pump();
    expect(chip(tester, 'Comparar').selected, isTrue);
    expect(chip(tester, 'Horarios').onSelected, isNull);
    await tester.tap(find.text('Horarios'));
    await tester.pump();
    expect(service.modes, ['history', 'comparison']);
    pending.complete(
      GenericResponse(success: true, data: _result('comparison')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(chip(tester, 'Comparar').selected, isTrue);
    expect(find.text('Período A'), findsOneWidget);
    expect(find.text('Resumen horario'), findsNothing);
  });

  for (final rejected in [false, true]) {
    testWidgets(
      'consulta de comparación antigua ${rejected ? 'rechazada' : 'exitosa'} '
      'no restaura datos ni cambia una sesión posterior',
      (tester) async {
        final service = await open(tester);
        final pending = Completer<GenericResponse<Map<String, dynamic>>>();
        service.pending = pending;
        await tester.tap(find.text('Comparar'));
        await tester.pump();
        SessionService.clear();
        SessionService.start(
          token: 'synthetic-new-history-session',
          user: const UserModel(id: 2),
        );
        await tester.pump();
        pending.complete(
          rejected
              ? const GenericResponse(success: false, error: 'SESSION_INVALID')
              : GenericResponse(success: true, data: _result('comparison')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(SessionService.token, 'synthetic-new-history-session');
        expect(service.modes, ['history', 'comparison']);
        expect(find.text('Período A'), findsNothing);
        expect(find.text('Resumen horario'), findsNothing);
      },
    );
  }
}
