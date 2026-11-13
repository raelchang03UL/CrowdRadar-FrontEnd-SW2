import 'dart:async';
import 'dart:convert';

import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/login/login_page.dart';
import 'package:crowdradar/pages/login/session_restore_page.dart';
import 'package:crowdradar/router/app_router.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/services/session_storage.dart';
import 'package:crowdradar/services/session_token.dart';
import 'package:crowdradar/services/session_validation.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _TabStorage implements SessionStorage {
  String? record;
  @override
  bool get enabled => true;
  @override
  String? read() => record;
  @override
  void write(String value) => record = value;
  @override
  void clear() => record = null;
}

class _Places extends PlaceService {
  int requests = 0;
  @override
  Future<GenericResponse<PlaceModel>> getPlace(int id) async {
    requests++;
    return GenericResponse(
      success: true,
      data: PlaceModel(
        id: id,
        nombre: 'Lugar privado de prueba',
        categoria: 'Parque',
        latitud: -12.12,
        longitud: -77.03,
        demostrativo: true,
      ),
    );
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 13);
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final token =
      '${part({'alg': 'HS256'})}.${part({'id': 1, 'exp': now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})}.c2ln';
  const freshUser = UserModel(
    id: 1,
    nombre: 'Perfil de la API',
    rol: 'USUARIO',
    status: 'ACTIVO',
  );
  late _TabStorage storage;
  late _Places places;

  setUp(() {
    storage = _TabStorage()..record = encodeStoredSession(token, false);
    places = _Places();
  });
  tearDown(() => SessionService.configureRestoreForTesting());

  void prepare(SessionValidator validator) {
    SessionService.configureRestoreForTesting(
      storage: storage,
      validator: validator,
      clock: () => now,
    );
    SessionService.prepareRestore();
  }

  Future<GoRouter> mount(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = createAppRouter(
      initialLocation: '/places/-2005?source=reload',
      placeService: places,
    );
    final auth = AuthCubit();
    addTearDown(router.dispose);
    addTearDown(auth.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: auth,
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
    return router;
  }

  testWidgets(
    'una recarga no construye ni consulta la ficha hasta validar perfil',
    (tester) async {
      final validation = Completer<SessionValidationResult>();
      prepare((_) => validation.future);
      final pending = SessionService.restore();
      final router = await mount(tester);
      expect(find.byType(SessionRestorePage), findsOneWidget);
      expect(find.text('Lugar privado de prueba'), findsNothing);
      expect(places.requests, 0);
      expect(SessionService.token, isNull);
      expect(SessionService.currentUser, isNull);
      validation.complete(const SessionValidationResult.valid(freshUser));
      await pending;
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/places/-2005?source=reload',
      );
      expect(places.requests, 1);
      expect(find.text('Lugar privado de prueba'), findsWidgets);
      expect(SessionService.currentUser, same(freshUser));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fallo temporal muestra reintento y mantiene bloqueada la ruta, a 360 y texto 2x',
    (tester) async {
      var calls = 0;
      prepare(
        (_) async => ++calls == 1
            ? const SessionValidationResult.retryRequired()
            : const SessionValidationResult.valid(freshUser),
      );
      final router = await mount(tester, scale: 2);
      await SessionService.restore();
      await tester.pumpAndSettle();
      expect(SessionService.isAuthenticated, isFalse);
      expect(storage.record, isNotNull);
      expect(places.requests, 0);
      expect(find.text('No pudimos comprobar tu sesión'), findsOneWidget);
      await tester.ensureVisible(find.text('Reintentar'));
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/places/-2005',
      );
      expect(places.requests, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '401 de restauración limpia almacenamiento y muestra login con aviso',
    (tester) async {
      prepare((_) async => const SessionValidationResult.invalid());
      final router = await mount(tester);
      await SessionService.restore();
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/login?notice=sessionExpired',
      );
      expect(find.byType(LoginPage), findsOneWidget);
      expect(storage.record, isNull);
      expect(places.requests, 0);
    },
  );

  testWidgets(
    'elegir otra cuenta cancela la recuperación y una respuesta tardía no entra',
    (tester) async {
      final validation = Completer<SessionValidationResult>();
      prepare((_) => validation.future);
      final pending = SessionService.restore();
      final router = await mount(tester);
      await tester.tap(find.text('Iniciar sesión con otra cuenta'));
      await tester.pumpAndSettle();
      expect(storage.record, isNull);
      validation.complete(const SessionValidationResult.valid(freshUser));
      await pending;
      await tester.pumpAndSettle();
      expect(SessionService.isAuthenticated, isFalse);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
      expect(places.requests, 0);
      router.go('/places/-2005');
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
