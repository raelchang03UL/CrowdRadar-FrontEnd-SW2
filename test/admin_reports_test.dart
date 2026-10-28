import 'dart:async';
import 'dart:convert';
import 'package:crowdradar/cubits/admin/admin_reports_cubit.dart';
import 'package:crowdradar/models/admin_report.dart';
import 'package:crowdradar/models/citizen_report.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/admin/admin_report_detail_page.dart';
import 'package:crowdradar/pages/admin/admin_reports_page.dart';
import 'package:crowdradar/pages/reports/report_history_page.dart';
import 'package:crowdradar/pages/reports/report_review_page.dart';
import 'package:crowdradar/services/admin_report_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> report({
  String state = 'PENDING',
  int version = 0,
  int total = 3,
  int reviewed = 0,
}) => {
  'id': '9007199254740993',
  'placeId': 1,
  'placeName': 'Parque QA',
  'level': 'SATURADO',
  'createdAt': '2026-10-28T05:00:00.000Z',
  'author': {'id': 2, 'name': 'Bruno QA', 'rol': 'USUARIO'},
  'reviewState': state,
  'isPublic': state != 'REMOVED',
  'moderationVersion': version,
  'denunciationCount': total,
  'reviewedDenunciationCount': reviewed,
};
Map<String, dynamic> action(int id, String decision) => {
  'id': '$id',
  'decision': decision,
  'reason': 'Decisión revisada',
  'adminId': 1,
  'adminName': 'Admin QA',
  'createdAt': '2026-10-28T05:01:00.000Z',
  'reviewedDenunciationCount': 3,
  'moderationVersion': id,
};
Map<String, dynamic> detail(
  Map<String, dynamic> row, {
  List<Map<String, dynamic>> events = const [],
}) => {
  'data': {
    ...row,
    'reasons': [
      {'reason': 'No coincide', 'count': 2},
      {'reason': null, 'count': 1},
      if (row['denunciationCount'] == 4) {'reason': 'Motivo nuevo', 'count': 1},
    ],
  },
  'history': events,
  'historyPagination': {'nextBefore': null},
};
http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
http.Response page(List<Map<String, dynamic>> rows) => json({
  'data': rows,
  'pagination': {'nextBefore': null},
});
Future<void> pumpDetail(WidgetTester tester, {double scale = 1}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const AdminReportDetailPage(id: '9007199254740993'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Map<String, dynamic> ownReport() => {
  'id': '1',
  'placeId': 1,
  'placeName': 'Parque QA',
  'level': 'SATURADO',
  'createdAt': '2026-10-28T05:00:00.000Z',
  'isOwn': true,
  'confirmations': 0,
  'rejections': 0,
  'ownDecision': null,
  'alreadyDenounced': false,
  'removedFromPublic': true,
  'reliability': {'level': null, 'confirmWeight': 0, 'totalWeight': 0},
};
void main() {
  setUp(
    () => SessionService.start(
      token: 'synthetic',
      user: const UserModel(id: 1, rol: 'ADMIN'),
    ),
  );
  tearDown(SessionService.clear);
  test(
    'contrato: BIGINT textual, suma de grupos y orden de historial',
    () async {
      final model = AdminReportDetail.fromJson(detail(report()));
      expect(model.report.id, '9007199254740993');
      expect(model.reasons.fold<int>(0, (sum, g) => sum + g.count), 3);
      final bad = detail(report());
      (bad['data'] as Map<String, dynamic>)['reasons'] = [
        {'reason': 'No coincide', 'count': 2},
      ];
      expect(() => AdminReportDetail.fromJson(bad), throwsFormatException);
      final duplicate = detail(
        report(version: 2),
        events: [action(1, 'KEEP'), action(2, 'REMOVE')],
      );
      expect(
        () => AdminReportDetail.fromJson(duplicate),
        throwsFormatException,
      );
      expect(
        () => CitizenReport.fromJson(ownReport()..['isOwn'] = false),
        throwsFormatException,
      );
    },
  );
  test(
    'servicio rechaza resultados fuera del filtro de autor y preserva revisión/total al decidir',
    () async {
      await http.runWithClient(() async {
        expect((await AdminReportService().list(authorId: 3)).success, isFalse);
      }, () => MockClient((_) async => page([report()])));
      await http.runWithClient(
        () async {
          final result = await AdminReportService().decide(
            AdminReport.fromJson(report()),
            'REMOVE',
            ' Motivo revisado ',
          );
          expect(result.success, isTrue);
        },
        () => MockClient((r) async {
          expect(jsonDecode(r.body), {
            'decision': 'REMOVE',
            'reason': 'Motivo revisado',
            'expectedVersion': 0,
            'expectedDenunciationCount': 3,
          });
          return json(
            detail(
              report(state: 'REMOVED', version: 1, reviewed: 3),
              events: [action(1, 'REMOVE')],
            ),
          );
        }),
      );
    },
  );
  test(
    'la última consulta gana y una sesión nueva no recibe resultados anteriores',
    () async {
      final responses = [
        Completer<http.Response>(),
        Completer<http.Response>(),
      ];
      var calls = 0;
      await http.runWithClient(() async {
        final cubit = AdminReportsCubit(AdminReportService());
        addTearDown(cubit.close);
        final old = cubit.load(), recent = cubit.filter('REMOVED');
        responses[1].complete(page([]));
        await recent;
        responses[0].complete(page([report()]));
        await old;
        expect(cubit.state.data!.reports, isEmpty);
        SessionService.clear();
        expect(cubit.state.data, isNull);
      }, () => MockClient((_) => responses[calls++].future));
    },
  );
  testWidgets('lista vacía y filtro de estado funcionan', (tester) async {
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AdminReportsPage(),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('No hay reportes denunciados con estos criterios.'),
          findsOneWidget,
        );
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Retirados').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aplicar filtro'));
        await tester.pumpAndSettle();
        expect(find.text('Autor: Bruno QA (ID 2)'), findsOneWidget);
      },
      () => MockClient(
        (r) async => page(
          r.url.queryParameters['state'] == 'REMOVED'
              ? [report(state: 'REMOVED', version: 1, reviewed: 3)]
              : [],
        ),
      ),
    );
  });
  testWidgets(
    'conservar exige motivo; denuncia nueva devuelve Pendiente; retirar conserva historial',
    (tester) async {
      var current = report(), posts = 0;
      final events = <Map<String, dynamic>>[];
      await http.runWithClient(
        () async {
          await pumpDetail(tester);
          expect(find.text('Total de denuncias recibidas'), findsOneWidget);
          expect(find.text('2 denuncias · No coincide'), findsOneWidget);
          expect(find.text('1 denuncia · Sin motivo'), findsOneWidget);
          await tapVisible(tester, 'Conservar reporte');
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
          expect(posts, 0);
          await tapVisible(tester, 'Conservar reporte');
          await tester.tap(find.text('Confirmar conservación'));
          await tester.pumpAndSettle();
          expect(
            find.text('Escribe el motivo de la decisión.'),
            findsOneWidget,
          );
          await tester.enterText(
            find.byType(TextFormField),
            'Decisión revisada',
          );
          await tester.tap(find.text('Confirmar conservación'));
          await tester.pumpAndSettle();
          expect(find.text('Revisión: Conservado'), findsOneWidget);
          expect(find.text('Conservar reporte'), findsNothing);
          expect(find.text('Reporte conservado'), findsOneWidget);
          current = report(total: 4, reviewed: 3, version: 1);
          await tapVisible(tester, 'Actualizar revisión');
          await tester.scrollUntilVisible(
            find.textContaining('Denuncias posteriores'),
            -200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('Denuncias posteriores'), findsOneWidget);
          await tapVisible(tester, 'Retirar de vista pública');
          await tester.enterText(
            find.byType(TextFormField),
            'Decisión revisada',
          );
          await tester.tap(find.text('Confirmar retiro'));
          await tester.pumpAndSettle();
          expect(posts, 2);
          await tester.scrollUntilVisible(
            find.text('Revisión: Retirado de la vista pública'),
            -200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(
            find.text('Revisión: Retirado de la vista pública'),
            findsOneWidget,
          );
          expect(find.text('Retirar de vista pública'), findsNothing);
          await tester.scrollUntilVisible(
            find.text('Reporte retirado'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(find.text('Reporte retirado'), findsOneWidget);
          expect(find.text('Reporte conservado'), findsOneWidget);
        },
        () => MockClient((r) async {
          if (r.method == 'POST') {
            posts++;
            final body = jsonDecode(r.body);
            expect(body['expectedDenunciationCount'], posts == 1 ? 3 : 4);
            current = report(
              state: body['decision'] == 'KEEP' ? 'KEPT' : 'REMOVED',
              version: posts,
              total: posts == 1 ? 3 : 4,
              reviewed: posts == 1 ? 3 : 4,
            );
            events.insert(0, action(posts, body['decision'] as String));
          }
          return json(detail(current, events: events));
        }),
      );
    },
  );
  testWidgets('respuesta incierta pide actualizar sin repetir la decisión', (
    tester,
  ) async {
    var current = report(), posts = 0;
    await http.runWithClient(
      () async {
        await pumpDetail(tester);
        await tapVisible(tester, 'Retirar de vista pública');
        await tester.enterText(find.byType(TextFormField), 'Decisión revisada');
        await tester.tap(find.text('Confirmar retiro'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('No pudimos confirmar si la decisión se guardó'),
          findsOneWidget,
        );
        expect(find.text('Retirar de vista pública'), findsNothing);
        await tester.tap(find.text('Actualizar reporte e historial'));
        await tester.pumpAndSettle();
        expect(posts, 1);
        await tester.scrollUntilVisible(
          find.text('Reporte retirado'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Reporte retirado'), findsOneWidget);
      },
      () => MockClient((r) async {
        if (r.method == 'POST') {
          posts++;
          current = report(state: 'REMOVED', version: 1, reviewed: 3);
          throw http.ClientException('Respuesta perdida');
        }
        return json(
          detail(current, events: posts == 0 ? [] : [action(1, 'REMOVE')]),
        );
      }),
    );
  });
  testWidgets(
    'el historial privado marca el retiro y conserva acceso al detalle',
    (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: const ReportHistoryPage(),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Retirado de la vista pública'), findsOneWidget);
          await tester.tap(find.text('Parque QA'));
          await tester.pumpAndSettle();
          expect(find.textContaining('mantiene el karma'), findsOneWidget);
          expect(find.text('Ver estado de validación'), findsOneWidget);
        },
        () => MockClient(
          (_) async => json({
            'data': [
              {
                'id': '1',
                'placeId': 1,
                'placeName': 'Parque QA',
                'level': 'SATURADO',
                'createdAt': '2026-10-28T05:00:00.000Z',
                'isPublic': false,
              },
            ],
          }),
        ),
      );
    },
  );
  testWidgets(
    'autor consulta evidencia retirada sin botones de participación',
    (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ReportReviewPage(id: '1', ownOnly: true),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('no participa en los cálculos públicos'),
          findsOneWidget,
        );
        expect(find.text('Confirmar reporte'), findsNothing);
        expect(find.text('Denunciar reporte'), findsNothing);
      }, () => MockClient((_) async => json({'data': ownReport()})));
    },
  );
  for (final width in [360.0, 390.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('revisión y confirmación sin overflow $width texto $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await http.runWithClient(
          () async {
            await pumpDetail(tester, scale: scale);
            await tapVisible(tester, 'Retirar de vista pública');
            expect(tester.takeException(), isNull);
            await tester.tap(find.text('Cancelar'));
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.text('Reporte conservado'),
              200,
              scrollable: find.byType(Scrollable).first,
            );
            expect(tester.takeException(), isNull);
          },
          () => MockClient(
            (_) async => json(
              detail(
                report(version: 1, reviewed: 3),
                events: [action(1, 'KEEP')],
              ),
            ),
          ),
        );
      });
    }
  }
}
