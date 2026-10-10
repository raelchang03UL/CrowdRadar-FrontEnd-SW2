import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crowdradar/configs/api_config.dart';
import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/pages/login/login_page.dart';
import 'package:crowdradar/router/app_router.dart';
import 'package:crowdradar/services/auth_service.dart';
import 'package:crowdradar/services/recovery_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/services/user_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

// Opt-in widgets + real local HTTP/PostgreSQL, with test-only mail in RAM.
// Requires the sibling backend and an existing crowdradar_auth_test database.
// The private Node child guards the DB before importing models, explicitly
// migrates it and leaves one random qa.hu212.* account. No dev DB is touched.
// Abuse counters use a per-child namespace with unchanged limits/SQL; the
// dedicated backend DB runner verifies production rate-limit behaviour.
// Neither this test nor its child proves real email/browser/Android delivery.
// PowerShell (run after the backend isolated-DB tests, never concurrently):
// $env:CROWDRADAR_RECOVERY_INTEGRATION='1'
// flutter test --no-pub test/local_recovery_api_test.dart --dart-define=API_BASE_URL=http://127.0.0.1:3031
// Remove-Item Env:CROWDRADAR_RECOVERY_INTEGRATION
class _RecoveryBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

class _HttpTrace {
  int validations = 0;
  int? lastValidationStatus;
  Completer<void>? validationGate;
}

class _LocalOnlyClient extends http.BaseClient {
  final _inner = IOClient(HttpClient());
  final _HttpTrace trace;
  _LocalOnlyClient(this.trace);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!_isLocalApi(request.url)) {
      throw http.ClientException('La prueba solo admite la API local aislada.');
    }
    request.followRedirects = false;
    final response = await _inner.send(request);
    if (request.url.path == '/api/auth/password/reset/validate') {
      trace.validations++;
      trace.lastValidationStatus = response.statusCode;
      // The API response is real; delaying its delivery verifies that the UI
      // keeps the password form hidden until the server validates the link.
      await trace.validationGate?.future;
    }
    return response;
  }

  @override
  void close() => _inner.close();
}

bool _isLocalApi(Uri uri) =>
    uri.scheme == 'http' &&
    uri.host == '127.0.0.1' &&
    uri.port == 3031 &&
    uri.userInfo.isEmpty;

String _randomValue() {
  final random = Random.secure();
  return base64UrlEncode(
    List<int>.generate(24, (_) => random.nextInt(256)),
  ).replaceAll('=', '');
}

class _RecoveryHarness {
  final Process process;
  final StreamIterator<String> _output;
  _RecoveryHarness(this.process)
    : _output = StreamIterator(
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      );

  static Future<_RecoveryHarness> start() async {
    final backend = Directory.fromUri(
      Directory.current.uri.resolve('../CrowdRadar-Backend/'),
    );
    final script = File.fromUri(
      backend.uri.resolve('scripts/verify-recovery-ui.js'),
    );
    if (!await script.exists()) {
      throw StateError('Falta el proceso de pruebas del backend hermano.');
    }
    final process = await Process.start(
      'node',
      [script.path],
      workingDirectory: backend.path,
      environment: {'NODE_ENV': 'test', 'CROWDRADAR_RECOVERY_INTEGRATION': '1'},
    );
    // Do not relay diagnostics: the child's only public output is fixed JSON.
    unawaited(process.stderr.drain<void>());
    final harness = _RecoveryHarness(process);
    try {
      final ready = await harness._read('ready');
      if (ready['port'] != 3031 ||
          ready['isolatedDatabase'] != true ||
          ready['memoryDelivery'] != true) {
        throw StateError('El proceso de pruebas no confirmó el aislamiento.');
      }
      return harness;
    } catch (_) {
      await harness.close();
      throw StateError('No se pudo iniciar la API aislada de recuperación.');
    }
  }

  Future<Map<String, dynamic>> _read(String event) async {
    try {
      if (!await _output.moveNext().timeout(const Duration(seconds: 30))) {
        throw StateError('child-closed');
      }
      final value = jsonDecode(_output.current);
      if (value is! Map<String, dynamic> || value['event'] != event) {
        throw StateError('unexpected-response');
      }
      return value;
    } catch (_) {
      // Never include the line, child exception or token in test diagnostics.
      throw StateError('El proceso local no completó la operación de prueba.');
    }
  }

  Future<Map<String, dynamic>> mailbox(String email) async {
    process.stdin.writeln(jsonEncode({'command': 'mailbox', 'email': email}));
    await process.stdin.flush();
    return _read('mailbox');
  }

  Future<void> close() async {
    try {
      process.stdin.writeln(jsonEncode({'command': 'shutdown'}));
      await process.stdin.flush();
      await process.stdin.close();
      await process.exitCode.timeout(const Duration(seconds: 10));
    } catch (_) {
      process.kill();
      await process.exitCode;
    } finally {
      await _output.cancel();
    }
  }
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() ready,
  String failure,
) async {
  for (var attempt = 0; attempt < 200; attempt++) {
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
  final enabled =
      Platform.environment['CROWDRADAR_RECOVERY_INTEGRATION'] == '1';
  if (enabled) {
    _RecoveryBinding();
  } else {
    TestWidgetsFlutterBinding.ensureInitialized();
  }
  setUp(SessionService.clear);
  tearDown(SessionService.clear);

  testWidgets(
    'HU 2.1–2.2 widgets + API aislada: solicitud, enlace, reset y nuevo login',
    (tester) async {
      final base = Uri.parse(ApiConfig.baseUrl);
      expect(
        _isLocalApi(base) &&
            const {'', '/'}.contains(base.path) &&
            !base.hasQuery &&
            !base.hasFragment,
        isTrue,
        reason: 'Usa API_BASE_URL=http://127.0.0.1:3031.',
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await tester.runAsync(_RecoveryHarness.start);
      expect(harness != null, isTrue);
      addTearDown(() => tester.runAsync(harness!.close));
      final trace = _HttpTrace();
      final client = _LocalOnlyClient(trace);
      addTearDown(client.close);

      await http.runWithClient(() async {
        final auth = AuthService();
        final email =
            'qa.hu212.${DateTime.now().microsecondsSinceEpoch}.${_randomValue()}@example.test';
        final initialPassword = _randomValue();
        final nextPassword = _randomValue();
        String? previousToken;
        int? userId;
        await tester.runAsync(() async {
          final registered = await auth.register(
            nombre: 'QA',
            apellido: 'Recuperacion',
            email: email,
            password: initialPassword,
            telefono: '900000000',
            distrito: 'Prueba local',
          );
          expect(registered.success, isTrue, reason: 'Registro QA aislado.');
          userId = registered.data?.id;
          final login = await auth.login(email, initialPassword);
          expect(login.success, isTrue, reason: 'Login inicial QA aislado.');
          previousToken = SessionService.token;
          expect(previousToken != null && previousToken!.isNotEmpty, isTrue);
          SessionService.clear();
        });

        final authCubit = AuthCubit(authService: auth);
        final router = createAppRouter(initialLocation: '/forgot-password');
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
        await tester.pumpAndSettle();
        final requestSubmit = find.byKey(
          const ValueKey('forgot-password-submit'),
        );
        expect(requestSubmit, findsOneWidget);
        await tester.enterText(find.byType(TextFormField), email);
        await tester.ensureVisible(requestSubmit);
        await tester.tap(requestSubmit);
        await _waitUntil(
          tester,
          () =>
              find.text(RecoveryService.requestedMessage).evaluate().isNotEmpty,
          'La solicitud no mostró la respuesta uniforme.',
        );
        expect(SessionService.isAuthenticated, isFalse);

        String? resetRoute;
        await tester.runAsync(() async {
          final mail = await harness!.mailbox(email);
          expect(mail['resetCount'], 1);
          expect(mail['resetUrl'] is String, isTrue);
          final link = Uri.parse(mail['resetUrl'] as String);
          final route = Uri.parse(link.fragment);
          expect(
            link.scheme == 'http' &&
                link.host == '127.0.0.1' &&
                link.port == 5500 &&
                route.path == '/reset-password' &&
                RegExp(
                  r'^[a-f0-9]{64}$',
                ).hasMatch(route.queryParameters['token'] ?? ''),
            isTrue,
            reason: 'El correo debe usar la URL local configurada.',
          );
          resetRoute = link.fragment;
        });

        trace.validationGate = Completer<void>();
        addTearDown(() {
          if (!trace.validationGate!.isCompleted) {
            trace.validationGate!.complete();
          }
        });
        router.go(resetRoute!);
        await _waitUntil(
          tester,
          () => trace.validations == 1,
          'La pantalla no validó el enlace contra la API real.',
        );
        expect(trace.lastValidationStatus, 200);
        expect(_field('reset-new-password'), findsNothing);
        expect(_field('reset-confirm-password'), findsNothing);
        trace.validationGate!.complete();
        await _waitUntil(
          tester,
          () => _field('reset-new-password').evaluate().isNotEmpty,
          'El enlace válido no habilitó el formulario.',
        );
        await tester.enterText(_field('reset-new-password'), nextPassword);
        await tester.enterText(_field('reset-confirm-password'), nextPassword);
        final resetSubmit = find.byKey(const ValueKey('reset-password-submit'));
        await tester.ensureVisible(resetSubmit);
        await tester.tap(resetSubmit);
        await _waitUntil(
          tester,
          () => find.byType(LoginPage).evaluate().isNotEmpty,
          'El restablecimiento no dirigió a login.',
        );
        expect(
          find.text('Contraseña restablecida. Inicia sesión nuevamente.'),
          findsOneWidget,
        );
        expect(SessionService.isAuthenticated, isFalse);
        expect(SessionService.token == null, isTrue);

        await tester.runAsync(() async {
          final previousProfile = await client
              .get(
                ApiConfig.uri(ApiConfig.profile),
                headers: ApiConfig.authHeaders(previousToken!),
              )
              .timeout(const Duration(seconds: 15));
          expect(previousProfile.statusCode, 401);
          expect((await auth.login(email, initialPassword)).success, isFalse);
          expect((await auth.login(email, nextPassword)).success, isTrue);
          final profile = await UserService().getProfile();
          expect(profile.success, isTrue);
          expect(profile.data?.id == userId, isTrue);
          final mail = await harness!.mailbox(email);
          expect(mail['changedCount'], 1);
        });

        SessionService.clear();
        router.go(resetRoute!);
        await _waitUntil(
          tester,
          () => find
              .text('El enlace no es válido o ha expirado. Solicita uno nuevo.')
              .evaluate()
              .isNotEmpty,
          'El enlace consumido no mostró el estado inválido.',
        );
        expect(trace.validations, 2);
        expect(trace.lastValidationStatus, 400);
        expect(_field('reset-new-password'), findsNothing);
        expect(_field('reset-confirm-password'), findsNothing);
        expect(
          find.byKey(const ValueKey('reset-password-submit')),
          findsNothing,
        );
        expect(SessionService.isAuthenticated, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      }, () => _LocalOnlyClient(trace));
    },
    skip: !enabled,
  );
}
