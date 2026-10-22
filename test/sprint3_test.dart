import 'dart:async';
import 'dart:convert';
import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/configs/lima_time.dart';
import 'package:crowdradar/cubits/request_cubit.dart';
import 'package:crowdradar/models/citizen_report.dart';
import 'package:crowdradar/models/saturation_report_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/reports/report_review_page.dart';
import 'package:crowdradar/pages/places/place_history_page.dart';
import 'package:crowdradar/services/api_json_client.dart';
import 'package:crowdradar/services/place_history_service.dart';
import 'package:crowdradar/services/report_review_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

CitizenReport sample({bool own = false, String? decision}) => CitizenReport(
  id: '9007199254740993',
  placeName: 'QA Parque',
  placeId: -701,
  level: 'TRANQUILO',
  createdAt: DateTime.utc(2026, 10, 17),
  confirmations: 0,
  rejections: 0,
  confirmWeight: 0,
  totalWeight: 0,
  isOwn: own,
  alreadyDenounced: false,
  ownDecision: decision,
);

class ReviewFake extends ReportReviewService {
  bool own = false;
  String? decision;
  int votes = 0;
  @override
  Future<GenericResponse<List<CitizenReport>>> list() async =>
      GenericResponse(success: true, data: [sample()]);
  @override
  Future<GenericResponse<CitizenReport>> detail(
    String id, {
    bool ownOnly = false,
  }) async => GenericResponse(
    success: true,
    data: sample(own: own, decision: decision),
  );
  @override
  Future<GenericResponse<Map<String, dynamic>>> vote(
    String id,
    String value,
  ) async {
    votes++;
    decision = value;
    return const GenericResponse(success: true, data: {});
  }
}

final emptyHistory = <String, dynamic>{
  'blocks': <dynamic>[],
  'counts': {'TRANQUILO': 0, 'MODERADO': 0, 'SATURADO': 0},
  'insufficient': 24,
  'sufficient': 0,
  'hasReports': false,
};

class HistoryFake extends PlaceHistoryService {
  String? mode;
  @override
  Future<GenericResponse<Map<String, dynamic>>> load(
    int id,
    String mode,
    Map<String, String> period,
  ) async {
    this.mode = mode;
    return GenericResponse(
      success: true,
      data: mode == 'comparison'
          ? {'first': emptyHistory, 'second': emptyHistory, 'comparable': false}
          : mode == 'quiet-hours'
          ? {'reason': 'INSUFFICIENT_HISTORY', 'recommendations': <dynamic>[]}
          : emptyHistory,
    );
  }
}

void main() {
  setUp(
    () => SessionService.start(
      token: 'synthetic-s03',
      user: const UserModel(id: 1),
    ),
  );
  tearDown(SessionService.clear);
  test(
    'cliente no muestra SQL ni datos internos en errores;401 se identifica',
    () async {
      for (final status in [401, 403, 409, 500]) {
        final result = await http.runWithClient(
          () => ApiJsonClient().request('/api/reports/1'),
          () => MockClient(
            (_) async => http.Response(
              jsonEncode({
                'code': status == 409 ? 'ALREADY_VALIDATED' : 'PRIVATE',
                'message': 'SQL password private',
              }),
              status,
            ),
          ),
        );
        expect(result.success, isFalse);
        expect(result.message, isNot(contains('SQL')));
        expect(result.message, isNot(contains('password')));
        if (status == 401) expect(result.error, 'SESSION_INVALID');
      }
    },
  );
  test(
    'JSON incompleto de historial se rechaza antes de construir pantallas',
    () async {
      final result = await http.runWithClient(
        () => PlaceHistoryService().load(-1, 'history', {
          'from': '2026-10-12',
          'to': '2026-10-12',
        }),
        () => MockClient((_) async => http.Response('{"data":{}}', 200)),
      );
      expect(result.success, isFalse);
    },
  );
  test('BIGINT textual no se trunca; hora de Lima explícita', () {
    final report = SaturationReportModel.fromJson({
      'id': '9007199254740993',
      'createdAt': '2026-10-18T00:52:00Z',
      'level': 'TRANQUILO',
      'placeId': -1,
      'placeName': 'QA',
    });
    expect(report.id, '9007199254740993');
    expect(limaDate(report.createdAt), '17/10/2026 19:52');
  });
  test(
    'petición nueva gana; respuesta de otra sesión no repuebla estado',
    () async {
      final a = Completer<GenericResponse<int>>(),
          b = Completer<GenericResponse<int>>();
      var calls = 0;
      final cubit = RequestCubit<int>(() => calls++ == 0 ? a.future : b.future);
      final first = cubit.load(), second = cubit.load();
      b.complete(const GenericResponse(success: true, data: 2));
      await second;
      a.complete(const GenericResponse(success: true, data: 1));
      await first;
      expect(cubit.state.data, 2);
      SessionService.clear();
      expect(cubit.state.data, isNull);
      await cubit.close();
    },
  );
  test(
    'escritura única mientras espera; logout descarta éxito tardío',
    () async {
      final pending = Completer<GenericResponse<dynamic>>();
      var calls = 0;
      final cubit = RequestCubit<int>(
        () async => const GenericResponse(success: true, data: 1),
      );
      await cubit.load();
      final first = cubit.perform(() {
        calls++;
        return pending.future;
      });
      expect(
        await cubit.perform(() async {
          calls++;
          return const GenericResponse(success: true);
        }),
        isFalse,
      );
      expect(calls, 1);
      SessionService.clear();
      pending.complete(const GenericResponse(success: true));
      expect(await first, isFalse);
      expect(cubit.state.data, isNull);
      await cubit.close();
    },
  );
  test(
    '401 vigente cierra sesión;401 de sesión antigua no cierra la nueva',
    () async {
      final cubit = RequestCubit<int>(
        () async =>
            const GenericResponse(success: false, error: 'SESSION_INVALID'),
      );
      await cubit.load();
      expect(SessionService.isAuthenticated, isFalse);
      await cubit.close();
      SessionService.start(token: 'first', user: const UserModel(id: 1));
      final pending = Completer<GenericResponse<int>>();
      final other = RequestCubit<int>(() => pending.future);
      final load = other.load();
      SessionService.clear();
      SessionService.start(token: 'second', user: const UserModel(id: 2));
      pending.complete(
        const GenericResponse(success: false, error: 'SESSION_INVALID'),
      );
      await load;
      expect(SessionService.token, 'second');
      await other.close();
    },
  );
  Future<void> viewport(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> reveal(
    WidgetTester tester,
    Finder target, {
    bool up = false,
  }) async {
    await tester.scrollUntilVisible(
      target,
      up ? -240 : 240,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 50,
    );
    await tester.pumpAndSettle();
  }

  Widget app(Widget page) => MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(2)),
      child: child!,
    ),
    home: page,
  );
  testWidgets('voto actualiza selección y no permite votar de nuevo', (
    tester,
  ) async {
    final service = ReviewFake();
    await tester.pumpWidget(app(ReportReviewPage(id: '1', service: service)));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Confirmar reporte'));
    await tester.tap(find.text('Confirmar reporte'));
    await tester.pumpAndSettle();
    expect(service.votes, 1);
    expect(find.textContaining('Ya participaste: Confirmaste'), findsOneWidget);
    expect(find.text('Confirmar reporte'), findsNothing);
  });
  testWidgets('autor consulta conteos sin botones de autovoto/denuncia', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        ReportReviewPage(
          id: '1',
          service: ReviewFake()..own = true,
          ownOnly: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.textContaining('Este es tu reporte'));
    expect(find.textContaining('Este es tu reporte'), findsOneWidget);
    expect(find.text('Confirmar reporte'), findsNothing);
    expect(find.text('Denunciar reporte'), findsNothing);
  });
  for (final size in [
    const Size(360, 640),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    testWidgets('revisión responsive $size texto2x', (tester) async {
      await viewport(tester, size);
      await tester.pumpWidget(
        app(ReportReviewPage(id: '1', service: ReviewFake())),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Actualizar estado'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets('lista de validación responsive $size texto2x', (tester) async {
      await viewport(tester, size);
      await tester.pumpWidget(app(ReportHubPage(service: ReviewFake())));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('QA Parque'));
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'historial/comparación/horarios responsive $size texto2x y vacíos honestos',
      (tester) async {
        await viewport(tester, size);
        final service = HistoryFake();
        await tester.pumpWidget(
          app(PlaceHistoryPage(id: -1, service: service)),
        );
        await tester.pumpAndSettle();
        await reveal(
          tester,
          find.text('No existe información histórica para este período.'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await reveal(tester, find.text('Comparar'), up: true);
        await tester.tap(find.text('Comparar'));
        await tester.pumpAndSettle();
        expect(service.mode, 'comparison');
        await reveal(
          tester,
          find.text(
            'No hay información suficiente para comparar ambos períodos.',
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await reveal(tester, find.text('Horarios'), up: true);
        await tester.tap(find.text('Horarios'));
        await tester.pumpAndSettle();
        expect(service.mode, 'quiet-hours');
        await reveal(
          tester,
          find.textContaining('No existen datos suficientes para recomendar'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
