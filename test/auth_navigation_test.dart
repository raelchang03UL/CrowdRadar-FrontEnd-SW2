import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/login/login_page.dart';
import 'package:crowdradar/pages/register/register_page.dart';
import 'package:crowdradar/pages/profile/edit_profile_page.dart';
import 'package:crowdradar/router/app_router.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const protectedRoutes = [
    '/map',
    '/validar',
    '/favoritos',
    '/profile',
    '/profile/edit',
  ];
  const user = UserModel(id: 1, nombre: 'Usuario de prueba');

  setUp(SessionService.clear);
  tearDown(SessionService.clear);

  Future<void> mount(
    WidgetTester tester,
    GoRouter router,
    AuthCubit cubit,
  ) async {
    // Tamaño móvil normal; no se amplía para evitar excepciones de diseño.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
  }

  for (final route in protectedRoutes) {
    testWidgets('sin sesión, la entrada directa a $route redirige a login', (
      tester,
    ) async {
      final router = createAppRouter(initialLocation: route);
      await mount(tester, router, AuthCubit());
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
      expect(find.byType(LoginPage), findsOneWidget);
      expect(router.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  for (final route in ['/login', '/register']) {
    testWidgets('$route permanece pública sin sesión', (tester) async {
      final router = createAppRouter(initialLocation: route);
      await mount(tester, router, AuthCubit());
      expect(router.routerDelegate.currentConfiguration.uri.path, route);
      expect(
        find.byType(route == '/login' ? LoginPage : RegisterPage),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'logout redirige sin navegación explícita y elimina la pila protegida',
    (tester) async {
      SessionService.start(token: 'test-session', user: user);
      final cubit = AuthCubit();
      final router = createAppRouter(initialLocation: '/profile/edit');
      await mount(tester, router, cubit);
      expect(find.byType(EditProfilePage), findsOneWidget);
      router.push('/profile/edit', extra: user.toJson());
      await tester.pumpAndSettle();
      expect(router.canPop(), isTrue);

      cubit.logout();
      await tester.pumpAndSettle();

      expect(SessionService.token, isNull);
      expect(SessionService.currentUser, isNull);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
      expect(router.canPop(), isFalse);
      // El botón Atrás del sistema no puede recuperar la pantalla protegida.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
    },
  );

  for (final route in protectedRoutes) {
    testWidgets('después de logout, go y push a $route siguen bloqueados', (
      tester,
    ) async {
      SessionService.start(token: 'test-session', user: user);
      final cubit = AuthCubit();
      final router = createAppRouter(initialLocation: '/profile/edit');
      await mount(tester, router, cubit);
      cubit.logout();
      await tester.pumpAndSettle();

      router.go('$route?source=logout-test');
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
      expect(find.byType(LoginPage), findsOneWidget);
      router.push(route, extra: user.toJson());
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
      expect(SessionService.isAuthenticated, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('un nuevo login permite acceder de nuevo a una ruta protegida', (
    tester,
  ) async {
    final router = createAppRouter();
    await mount(tester, router, AuthCubit());
    SessionService.start(token: 'new-session', user: user);
    router.go('/profile/edit');
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/profile/edit',
    );
    expect(find.byType(EditProfilePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
