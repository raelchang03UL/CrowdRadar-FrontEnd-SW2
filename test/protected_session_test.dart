import 'dart:async';
import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/login/login_page.dart';
import 'package:crowdradar/router/app_router.dart';
import 'package:crowdradar/services/auth_service.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/report_history_service.dart';
import 'package:crowdradar/services/saturation_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/services/user_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const a = UserModel(id: 1, nombre: 'Sesión A');
  const b = UserModel(id: 2, nombre: 'Sesión B');
  final calls = <String, Future<dynamic> Function()>{
    'lugares': () => PlaceService().getPlaces(),
    'detalle': () => PlaceService().getPlace(-1),
    'categorías': () => PlaceService().getCategories(),
    'perfil': () => UserService().getProfile(),
    'actualización': () => UserService().updateProfile({'nombre': 'QA'}),
    'karma': () => UserService().getKarma(),
    'saturación': () => SaturationService().getSaturation(-1),
    'historial propio': () => ReportHistoryService().getReports(),
  };
  setUp(() => SessionService.start(token: 'synthetic-A', user: a));
  tearDown(SessionService.clear);
  for (final entry in calls.entries) {
    test('401 vigente limpia token y usuario: ${entry.key}', () async {
      await http.runWithClient(() async {
        await entry.value();
        expect(SessionService.isAuthenticated, isFalse);
        expect(SessionService.token, isNull);
        expect(SessionService.currentUser, isNull);
      }, () => MockClient((_) async => http.Response('{}', 401)));
    });
    for (final status in [401, 200]) {
      test(
        'respuesta $status antigua no cambia sesión B: ${entry.key}',
        () async {
          final started = Completer<void>(),
              response = Completer<http.Response>();
          await http.runWithClient(
            () async {
              final pending = entry.value();
              await started.future;
              SessionService.clear();
              SessionService.start(token: 'synthetic-A', user: b);
              response.complete(http.Response('{}', status));
              await pending;
              expect(SessionService.currentUser, same(b));
              expect(SessionService.isAuthenticated, isTrue);
            },
            () => MockClient((_) {
              started.complete();
              return response.future;
            }),
          );
        },
      );
    }
    for (final failure in ['503', 'timeout', 'desconexión']) {
      test('${entry.key}: $failure conserva la sesión', () async {
        await http.runWithClient(
          () async {
            await entry.value();
            expect(SessionService.token, 'synthetic-A');
            expect(SessionService.currentUser, same(a));
          },
          () => MockClient((_) async {
            if (failure == 'timeout') throw TimeoutException('QA timeout');
            if (failure == 'desconexión') {
              throw http.ClientException('QA offline');
            }
            return http.Response('{}', 503);
          }),
        );
      });
    }
  }
  test('dos 401 simultáneos invalidan una sola generación', () async {
    final responses = [Completer<http.Response>(), Completer<http.Response>()];
    var count = 0;
    final before = SessionService.generation;
    await http.runWithClient(() async {
      final pending = [PlaceService().getPlaces(), UserService().getProfile()];
      for (final response in responses) {
        response.complete(http.Response('{}', 401));
      }
      await Future.wait(pending);
      expect(SessionService.generation, before + 1);
      expect(SessionService.isAuthenticated, isFalse);
    }, () => MockClient((_) => responses[count++].future));
  });
  test('401 de credenciales de login no invalida otra sesión', () async {
    await http.runWithClient(() async {
      final result = await AuthService().login(
        'qa@example.invalid',
        'synthetic',
      );
      expect(result.success, isFalse);
      expect(SessionService.currentUser, same(a));
    }, () => MockClient((_) async => http.Response('{}', 401)));
  });
  for (final route in ['/places/-1', '/profile', '/profile/edit']) {
    testWidgets('401 en $route sale por router sin visitar Validar', (
      tester,
    ) async {
      final auth = AuthCubit(),
          router = createAppRouter(initialLocation: route);
      addTearDown(auth.close);
      addTearDown(router.dispose);
      await http.runWithClient(() async {
        await tester.pumpWidget(
          BlocProvider.value(
            value: auth,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);
        router.go('/profile/edit');
        await tester.pumpAndSettle();
        expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
        expect(router.canPop(), isFalse);
        expect(tester.takeException(), isNull);
      }, () => MockClient((_) async => http.Response('{}', 401)));
    });
  }
}
