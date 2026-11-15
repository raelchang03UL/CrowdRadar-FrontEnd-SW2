import 'dart:async';
import 'dart:convert';

import 'package:crowdradar/components/cr_bottom_nav.dart';
import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/login/login_page.dart';
import 'package:crowdradar/pages/profile/profile_page.dart';
import 'package:crowdradar/pages/reports/report_history_page.dart';
import 'package:crowdradar/router/app_router.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const citizen = UserModel(id: 1, nombre: 'Cuenta sintética', karmaPoints: 10);

http.Response reply(http.Request request) => http.Response(
  jsonEncode({
    'data': request.url.path.endsWith('/users/profile')
        ? citizen.toJson()
        : [],
  }),
  200,
  headers: {'content-type': 'application/json'},
);

Future<(GoRouter, AuthCubit)> mount(
  WidgetTester tester,
  String initial, {
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = createAppRouter(initialLocation: initial), auth = AuthCubit();
  addTearDown(router.dispose);
  addTearDown(auth.close);
  await tester.pumpWidget(
    BlocProvider.value(
      value: auth,
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return (router, auth);
}

Future<void> tapNav(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(CrBottomNav).last,
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SessionService.start(token: 'synthetic-session', user: citizen));
  tearDown(SessionService.clear);

  testWidgets('Historial → Perfil navega aunque el índice sea el mismo', (tester) async {
    await http.runWithClient(() async {
      final (router, _) = await mount(tester, '/profile/reports');
      expect(find.byType(ReportHistoryPage), findsOneWidget);
      await tapNav(tester, 'Perfil');
      expect(router.routerDelegate.currentConfiguration.uri.path, '/profile');
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.byType(ReportHistoryPage), findsNothing);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async => reply(request)));
  });

  testWidgets('Perfil → Historial → Perfil y pulsar Perfil no apila rutas', (tester) async {
    await http.runWithClient(() async {
      final (router, _) = await mount(tester, '/profile');
      await tester.scrollUntilVisible(
        find.text('Historial de reportes'), 200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Historial de reportes'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportHistoryPage), findsOneWidget);
      await tapNav(tester, 'Perfil');
      expect(router.routerDelegate.currentConfiguration.uri.path, '/profile');
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(router.canPop(), isFalse);
      await tapNav(tester, 'Perfil');
      expect(router.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async => reply(request)));
  });

  testWidgets('Historial → Mapa y logout protegen rutas y Atrás', (tester) async {
    await http.runWithClient(() async {
      final (router, auth) = await mount(tester, '/profile/reports');
      await tapNav(tester, 'Mapa');
      expect(router.routerDelegate.currentConfiguration.uri.path, '/map');
      auth.logout();
      await tester.pumpAndSettle();
      for (final route in ['/profile', '/profile/reports', '/map']) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
        expect(find.byType(LoginPage), findsOneWidget);
        expect(SessionService.currentUser, isNull);
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async => reply(request)));
  });

  for (final status in [200, 401]) {
    for (final newSession in [false, true]) {
      testWidgets('historial tardío $status no navega/restaura datos; nueva sesión=$newSession', (tester) async {
        final pending = Completer<http.Response>();
        await http.runWithClient(() async {
          final (router, auth) = await mount(tester, '/profile/reports', settle: false);
          await tapNav(tester, 'Perfil');
          expect(router.routerDelegate.currentConfiguration.uri.path, '/profile');
          auth.logout();
          await tester.pumpAndSettle();
          if (newSession) {
            SessionService.start(token: 'synthetic-session-B', user: const UserModel(id: 2, nombre: 'Otra cuenta'));
            router.go('/profile');
            await tester.pumpAndSettle();
          }
          final generation = SessionService.generation;
          pending.complete(http.Response(jsonEncode({'data': [{
            'id': '91', 'createdAt': '2026-10-19T20:00:00Z', 'level': 'TRANQUILO',
            'placeId': -2005, 'placeName': 'Dato antiguo que no debe reaparecer',
          }]}), status));
          await tester.pumpAndSettle();
          expect(router.routerDelegate.currentConfiguration.uri.path, newSession ? '/profile' : '/login');
          expect(SessionService.generation, generation);
          expect(SessionService.currentUser?.id, newSession ? 2 : null);
          expect(find.textContaining('Dato antiguo'), findsNothing);
          expect(find.byType(ReportHistoryPage), findsNothing);
          expect(tester.takeException(), isNull);
        }, () => MockClient((request) => request.url.path.endsWith('/users/reports') ? pending.future : Future.value(reply(request))));
      });
    }
  }
}
