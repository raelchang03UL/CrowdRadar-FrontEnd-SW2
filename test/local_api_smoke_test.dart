import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crowdradar/configs/api_config.dart';
import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/pages/login/login_page.dart';
import 'package:crowdradar/router/app_router.dart';
import 'package:crowdradar/services/auth_service.dart';
import 'package:crowdradar/services/password_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/services/user_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

// Opt-in: rendered Flutter widgets in the VM, real HTTP and PostgreSQL behind
// the local API. This is not a browser/Android run or an email-delivery test.
// Verify that the server uses crowdradar_dev before enabling the test. It
// leaves one identifiable qa.hu23.* account, never alters existing users,
// and keeps its random passwords and JWT only in memory (no captures/logs).
// PowerShell:
// $env:CROWDRADAR_API_INTEGRATION='1'
// flutter test --no-pub test/local_api_smoke_test.dart --dart-define=API_BASE_URL=http://localhost:3000
// Remove-Item Env:CROWDRADAR_API_INTEGRATION
class _LocalApiBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

class _LocalOnlyClient extends http.BaseClient {
  final http.Client _inner = IOClient(HttpClient());

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (!_isLocalApi(request.url)) {
      throw http.ClientException('La prueba solo admite la API local.');
    }
    request.followRedirects = false;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

bool _isLocalApi(Uri uri) =>
    uri.scheme == 'http' &&
    const {'localhost', '127.0.0.1', '::1'}.contains(uri.host) &&
    uri.port == 3000 &&
    uri.userInfo.isEmpty;

String _randomValue() {
  final random = Random.secure();
  return base64UrlEncode(
    List<int>.generate(24, (_) => random.nextInt(256)),
  ).replaceAll('=', '');
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() ready,
  String failure,
) async {
  // Do not pumpAndSettle around real I/O: loading indicators never settle.
  // runAsync gives the operating-system socket time while pump renders state.
  for (var attempt = 0; attempt < 160; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (ready()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  fail(failure);
}

Finder _field(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextFormField),
);

void main() {
  final enabled = Platform.environment['CROWDRADAR_API_INTEGRATION'] == '1';
  if (enabled) {
    _LocalApiBinding();
  } else {
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  setUp(SessionService.clear);
  tearDown(SessionService.clear);

  testWidgets(
    'HU 2.3 widgets + API local: perfil, cambio, invalidación y nuevo login',
    (tester) async {
      final base = Uri.parse(ApiConfig.baseUrl);
      expect(
        _isLocalApi(base) &&
            const {'', '/'}.contains(base.path) &&
            !base.hasQuery &&
            !base.hasFragment,
        isTrue,
        reason:
            'Configura API_BASE_URL=http://localhost:3000; no destinos remotos.',
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = _LocalOnlyClient();
      addTearDown(client.close);

      await http.runWithClient(() async {
        final auth = AuthService();
        final email =
            'qa.hu23.${DateTime.now().microsecondsSinceEpoch}.${_randomValue()}@example.test';
        final initialPassword = _randomValue();
        final nextPassword = _randomValue();
        final wrongPassword = _randomValue();
        int? userId;
        String? previousToken;

        await tester.runAsync(() async {
          final health = await client
              .get(ApiConfig.uri('/'))
              .timeout(const Duration(seconds: 15));
          expect(health.statusCode, 200);
          final registered = await auth.register(
            nombre: 'QA',
            apellido: 'IntegracionHU23',
            email: email,
            password: initialPassword,
            telefono: '900000000',
            distrito: 'Prueba local',
          );
          expect(registered.success, isTrue, reason: 'Registro QA local.');
          userId = registered.data?.id;
          final loggedIn = await auth.login(email, initialPassword);
          expect(loggedIn.success, isTrue, reason: 'Login inicial QA local.');
          previousToken = SessionService.token;
          expect(
            previousToken != null && previousToken!.isNotEmpty,
            isTrue,
            reason: 'El login debe crear una sesión en memoria.',
          );
          final profile = await UserService().getProfile();
          expect(profile.success, isTrue);
          expect(profile.data?.id == userId, isTrue);
        });

        final authCubit = AuthCubit(authService: auth);
        final router = createAppRouter(initialLocation: '/profile');
        addTearDown(authCubit.close);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          BlocProvider.value(
            value: authCubit,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await _waitUntil(
          tester,
          () => find.text('Datos de tu cuenta').evaluate().isNotEmpty,
          'El perfil real no cargó los datos de la cuenta QA.',
        );
        final changeAction = find.text('Cambiar contraseña');
        await tester.scrollUntilVisible(changeAction, 220);
        await tester.pumpAndSettle();
        await tester.tap(changeAction);
        await _waitUntil(
          tester,
          () => _field('current-password').evaluate().isNotEmpty,
          'No abrió el formulario protegido de contraseña.',
        );

        final submit = find.byKey(const ValueKey('change-password-submit'));
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pump();
        expect(find.text('Escribe tu contraseña actual'), findsOneWidget);
        expect(SessionService.isAuthenticated, isTrue);

        Future<void> fill(String currentPassword) async {
          await tester.enterText(_field('current-password'), currentPassword);
          await tester.enterText(_field('new-password'), nextPassword);
          await tester.enterText(_field('confirm-password'), nextPassword);
          await tester.ensureVisible(submit);
        }

        await fill(wrongPassword);
        await tester.tap(submit);
        await _waitUntil(
          tester,
          () => find
              .text('La contraseña actual no es correcta.')
              .evaluate()
              .isNotEmpty,
          'No se mostró el rechazo de contraseña actual incorrecta.',
        );
        expect(SessionService.isAuthenticated, isTrue);
        expect(find.byType(TextFormField), findsNWidgets(3));

        await fill(initialPassword);
        await tester.tap(submit);
        await _waitUntil(
          tester,
          () => find.byType(LoginPage).evaluate().isNotEmpty,
          'El cambio correcto no volvió a login.',
        );
        expect(SessionService.isAuthenticated, isFalse);
        expect(SessionService.token == null, isTrue);
        expect(SessionService.currentUser == null, isTrue);
        expect(find.text(PasswordService.changedMessage), findsOneWidget);

        router.go('/profile/password');
        await _waitUntil(
          tester,
          () => router.routeInformationProvider.value.uri.path == '/login',
          'La ruta de contraseña no se protegió después del cierre.',
        );
        expect(find.byType(LoginPage), findsOneWidget);

        await tester.runAsync(() async {
          final rejectedProfile = await client
              .get(
                ApiConfig.uri(ApiConfig.profile),
                headers: ApiConfig.authHeaders(previousToken!),
              )
              .timeout(const Duration(seconds: 15));
          expect(
            rejectedProfile.statusCode,
            401,
            reason: 'El backend debe invalidar el JWT anterior, no solo la UI.',
          );
          final unauthenticated = await client
              .post(
                ApiConfig.uri(ApiConfig.changePassword),
                headers: ApiConfig.jsonHeaders,
                body: jsonEncode({
                  'currentPassword': initialPassword,
                  'newPassword': nextPassword,
                  'confirmPassword': nextPassword,
                }),
              )
              .timeout(const Duration(seconds: 15));
          expect(unauthenticated.statusCode, 401);
          final oldLogin = await auth.login(email, initialPassword);
          expect(oldLogin.success, isFalse);
          final newLogin = await auth.login(email, nextPassword);
          expect(
            newLogin.success,
            isTrue,
            reason: 'Login con contraseña nueva.',
          );
          final profile = await UserService().getProfile();
          expect(profile.success, isTrue);
          expect(profile.data?.id == userId, isTrue);
        });

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      }, _LocalOnlyClient.new);
    },
    skip: !enabled,
  );
}
