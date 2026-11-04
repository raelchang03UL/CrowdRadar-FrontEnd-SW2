import 'package:crowdradar/components/push_transition_banner.dart';
import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/router/app_router.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/push_message_guard.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _title = 'Cambio que originó esta alerta';
const _payload = <String, dynamic>{
  'userId': '1',
  'placeId': '-2005',
  'registrationId': 'current-binding',
  'previousLevel': 'SATURADO',
  'newLevel': 'MODERADO',
  'title': 'Título arbitrario que no se muestra',
  'body': 'Cuerpo arbitrario que no se muestra',
  'date': 'Fecha arbitraria que no se muestra',
};

class _Places extends PlaceService {
  final int? responseId;
  _Places({this.responseId});

  @override
  Future<GenericResponse<PlaceModel>> getPlace(int id) async => GenericResponse(
    success: true,
    data: PlaceModel(
      id: responseId ?? id,
      nombre: 'Lugar ${responseId ?? id}',
      categoria: 'Parque',
      latitud: -12.12,
      longitud: -77.03,
      demostrativo: true,
    ),
  );
}

void main() {
  late ValueNotifier<int> changes;
  String? binding;

  AuthorizedPushTransition? alert([Map<String, dynamic> data = _payload]) =>
      authorizedPushTransition(
        data,
        binding,
        currentRegistrationId: () => binding,
        authorizationChanges: changes,
      );

  Future<GoRouter> mount(
    WidgetTester tester, {
    Object? extra,
    String path = '/places/-2005',
    int? responseId,
    double width = 390,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = createAppRouter(
      initialLocation: path,
      placeService: _Places(responseId: responseId),
    );
    addTearDown(router.dispose);
    router.go(path, extra: extra);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  setUp(() {
    SessionService.clear();
    SessionService.start(token: 'test-session', user: const UserModel(id: 1));
    changes = ValueNotifier(0);
    binding = 'current-binding';
  });
  tearDown(() {
    changes.dispose();
    SessionService.clear();
  });

  testWidgets('la ruta muestra solo la transición histórica autorizada', (
    tester,
  ) async {
    await mount(tester, extra: alert());
    expect(find.text('Lugar -2005'), findsOneWidget);
    expect(find.text(_title), findsOneWidget);
    expect(find.text('Saturado → Moderado'), findsOneWidget);
    expect(
      find.text('El nivel actual puede ser distinto al de esta alerta.'),
      findsOneWidget,
    );
    for (final key in ['title', 'body', 'date']) {
      expect(find.text(_payload[key] as String), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  for (final invalid in [
    <String, dynamic>{..._payload}..remove('previousLevel'),
    {..._payload, 'newLevel': 'DESCONOCIDO'},
    {..._payload, 'newLevel': 'SATURADO'},
  ]) {
    testWidgets(
      'payload incompleto/desconocido/sin cambio abre detalle normal $invalid',
      (tester) async {
        await mount(tester, extra: alert(invalid));
        expect(find.text('Lugar -2005'), findsOneWidget);
        expect(find.text(_title), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('ruta normal o extra sin tipo no fabrica contexto desde la URL', (
    tester,
  ) async {
    final router = await mount(
      tester,
      path: '/places/-2005?previousLevel=SATURADO&newLevel=MODERADO',
      extra: _payload,
    );
    expect(find.text(_title), findsNothing);
    router.go('/places/-2005');
    await tester.pumpAndSettle();
    expect(find.text('Lugar -2005'), findsOneWidget);
    expect(find.text(_title), findsNothing);
  });

  testWidgets('otra ruta y otro lugar cargado no muestran el contexto', (
    tester,
  ) async {
    final router = await mount(tester, extra: alert(), path: '/places/2');
    expect(find.text('Lugar 2'), findsOneWidget);
    expect(find.text(_title), findsNothing);
    router.go('/places/-2005', extra: alert());
    await tester.pumpAndSettle();
    expect(find.text(_title), findsOneWidget);
    router.go('/places/3');
    await tester.pumpAndSettle();
    expect(find.text('Lugar 3'), findsOneWidget);
    expect(find.text(_title), findsNothing);
  });

  testWidgets('una respuesta de otro lugar no recibe el aviso de la ruta', (
    tester,
  ) async {
    await mount(tester, extra: alert(), responseId: 2);
    expect(find.text(_title), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la ruta rechaza contexto capturado antes de una nueva sesión', (
    tester,
  ) async {
    final previous = alert();
    SessionService.start(token: 'test-session', user: const UserModel(id: 1));
    await mount(tester, extra: previous);
    expect(find.text('Lugar -2005'), findsOneWidget);
    expect(find.text(_title), findsNothing);
  });

  testWidgets(
    'la baja oculta el aviso visible al emitir el estado de autorización',
    (tester) async {
      await mount(tester, extra: alert());
      expect(find.text(_title), findsOneWidget);
      binding = null;
      changes.value++;
      await tester.pump();
      expect(find.text(_title), findsNothing);
      expect(find.text('Lugar -2005'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('el banner escucha logout y no reaparece con otra sesión', (
    tester,
  ) async {
    final previous = alert()!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PushTransitionBanner(alert: previous, placeId: -2005),
        ),
      ),
    );
    expect(find.text(_title), findsOneWidget);
    SessionService.clear();
    await tester.pump();
    expect(find.text(_title), findsNothing);
    SessionService.start(token: 'test-session', user: const UserModel(id: 1));
    await tester.pump();
    expect(find.text(_title), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin datos y texto 2x caben en móvil sin perder el significado', (
    tester,
  ) async {
    await mount(
      tester,
      extra: alert({
        ..._payload,
        'previousLevel': 'SIN_DATOS',
        'newLevel': 'TRANQUILO',
      }),
      width: 360,
      textScale: 2,
    );
    expect(find.text(_title), findsOneWidget);
    expect(find.text('Sin datos → Tranquilo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
