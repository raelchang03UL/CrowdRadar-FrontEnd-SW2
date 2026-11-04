import 'dart:ui' show SemanticsAction, Tristate;

import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/favoritos/favoritos_page.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Favorites extends PlaceService {
  final List<PlaceModel> places;
  int removals = 0;
  _Favorites(this.places);

  @override
  Future<GenericResponse<List<PlaceModel>>> getFavorites() async =>
      GenericResponse(success: true, data: places);

  @override
  Future<GenericResponse<bool>> removeFavorite(int placeId) async {
    removals++;
    return const GenericResponse(success: true, data: true);
  }
}

void main() {
  const place = PlaceModel(
    id: 1,
    nombre: 'Parque de la comunidad y centro de encuentro ciudadano',
    categoria: 'Parque y espacio público',
    latitud: -12,
    longitud: -77,
    demostrativo: true,
    esFavorito: true,
  );
  setUp(
    () => SessionService.start(
      token: 'synthetic-favorites-layout',
      user: const UserModel(id: 1),
    ),
  );
  tearDown(SessionService.clear);

  testWidgets('abrir y quitar tienen botones separados y foco por teclado', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _Favorites([place]);
      final router = GoRouter(
        initialLocation: '/favoritos',
        routes: [
          GoRoute(
            path: '/favoritos',
            builder: (_, _) => FavoritosPage(service: service),
          ),
          GoRoute(
            path: '/places/:id',
            builder: (_, _) => const Scaffold(body: Text('Detalle elegido')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );
      await tester.pumpAndSettle();

      final open = find.byKey(const ValueKey('favorite-place-1'));
      final remove = find.text('Quitar');
      final openNode = tester.getSemantics(open);
      final removeNode = tester.getSemantics(remove);
      final openData = openNode.getSemanticsData();
      final removeData = removeNode.getSemanticsData();
      expect(openNode.id, isNot(removeNode.id));
      expect(openData.flagsCollection.isButton, isTrue);
      expect(removeData.flagsCollection.isButton, isTrue);
      expect(openData.hasAction(SemanticsAction.tap), isTrue);
      expect(removeData.hasAction(SemanticsAction.tap), isTrue);
      expect(openData.label, contains(place.nombre));
      expect(openData.label, isNot(contains('Quitar')));
      expect(removeData.label, contains('Quitar'));
      expect(removeData.label, isNot(contains(place.nombre)));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester.getSemantics(open).getSemanticsData().flagsCollection.isFocused,
        Tristate.isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester
            .getSemantics(remove)
            .getSemanticsData()
            .flagsCollection
            .isFocused,
        Tristate.isTrue,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(
        tester.getSemantics(open).getSemanticsData().flagsCollection.isFocused,
        Tristate.isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Detalle elegido'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/places/1',
      );
      expect(service.removals, 0);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final empty in [false, true]) {
    testWidgets('favoritos a360 y texto2x, vacío=$empty', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: FavoritosPage(service: _Favorites(empty ? [] : [place])),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Activar alertas').hitTestable(), findsOneWidget);
      if (!empty) expect(find.text('1 lugar'), findsOneWidget);
      // El estado de alertas añade contenido al encabezado; la lista construye
      // sus filas al desplazarse, también con texto ampliado.
      await tester.scrollUntilVisible(
        find.text(empty ? 'Sin favoritos todavía' : 'Quitar'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      if (empty) {
        await tester.ensureVisible(find.text('Sin favoritos todavía'));
        await tester.pumpAndSettle();
        expect(
          find.text('Sin favoritos todavía').hitTestable(),
          findsOneWidget,
        );
      } else {
        expect(find.text(place.nombre), findsOneWidget);
        await tester.ensureVisible(find.text('Quitar'));
        await tester.pumpAndSettle();
        expect(find.text('Quitar').hitTestable(), findsOneWidget);
        expect(find.byTooltip('Quitar de favoritos'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
