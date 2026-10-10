import 'dart:convert';
import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/pages/login/login_page.dart';
import 'package:crowdradar/pages/register/register_page.dart';
import 'package:crowdradar/router/app_router.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(SessionService.clear);
  tearDown(SessionService.clear);

  for (final size in [
    const Size(1440, 900),
    const Size(390, 844),
    const Size(360, 360),
  ]) {
    for (final page in [const LoginPage(), const RegisterPage()]) {
      testWidgets('${page.runtimeType} legible sin overflow a $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cubit = AuthCubit();
        addTearDown(cubit.close);
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: MaterialApp(theme: AppTheme.lightTheme, home: page),
          ),
        );
        await tester.pumpAndSettle();
        final width = tester
            .getSize(find.byKey(const ValueKey('auth-form-width')))
            .width;
        expect(width, lessThanOrEqualTo(480));
        expect(width, lessThanOrEqualTo(size.width - 48));
        final button = find.widgetWithText(
          ElevatedButton,
          page is LoginPage ? 'Iniciar sesión' : 'Registrarme',
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'registro abierto directamente vuelve a login tras éxito sin pila previa',
    (tester) async {
      final router = createAppRouter(initialLocation: '/register');
      final cubit = AuthCubit();
      addTearDown(router.dispose);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(router.canPop(), false);
      await http.runWithClient(
        () => cubit.register(
          nombre: 'Prueba',
          apellido: 'Web',
          email: 'test@example.test',
          password: '<solo-prueba-unitaria>',
          telefono: '900000000',
          distrito: 'Prueba',
        ),
        () => MockClient((request) async {
          expect(request.url.path, '/api/auth/register');
          return http.Response(
            jsonEncode({
              'data': {'id': 1, 'nombre': 'Prueba', 'apellido': 'Web'},
            }),
            201,
          );
        }),
      );
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
      expect(find.byType(LoginPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
