import 'dart:ui' show SemanticsAction, Tristate;

import 'package:crowdradar/components/cr_bottom_nav.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _destinations = [
  (path: '/map', label: 'Mapa'),
  (path: '/validar', label: 'Validar'),
  (path: '/favoritos', label: 'Favoritos'),
  (path: '/profile', label: 'Perfil'),
];

Future<GoRouter> _mountNavigation(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/map',
    routes: [
      for (final destination in _destinations)
        GoRoute(
          path: destination.path,
          builder: (_, _) => Scaffold(
            body: Center(child: Text('Contenido de ${destination.label}')),
            bottomNavigationBar: CrBottomNav(
              currentIndex: _destinations.indexOf(destination),
            ),
          ),
        ),
    ],
  );
  addTearDown(router.dispose);
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

void _expectSelectedDestination(WidgetTester tester, String selectedLabel) {
  for (final destination in _destinations) {
    final label = find.text(destination.label);
    expect(label, findsOneWidget);
    final data = tester.getSemantics(label).getSemanticsData();
    expect(data.label, destination.label);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(
      data.flagsCollection.isSelected,
      destination.label == selectedLabel ? Tristate.isTrue : Tristate.isFalse,
    );
  }
}

void main() {
  testWidgets('360x640 con texto 2x conserva las cuatro secciones accesibles', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      const size = Size(360, 640);
      final router = await _mountNavigation(tester, size: size, textScale: 2);

      for (final destination in _destinations) {
        final target = find.text(destination.label);
        final bounds = tester.getRect(target);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(size.width));
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.bottom, lessThanOrEqualTo(size.height));
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          destination.path,
        );
        expect(find.text('Contenido de ${destination.label}'), findsOneWidget);
        _expectSelectedDestination(tester, destination.label);
        expect(tester.takeException(), isNull);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('1440x900 permite Tab y Enter y anuncia la sección seleccionada', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final router = await _mountNavigation(
        tester,
        size: const Size(1440, 900),
      );
      _expectSelectedDestination(tester, 'Mapa');

      // El único grupo de controles de esta página es la navegación del producto.
      // Se recorre con teclas reales; no se invoca onTap ni se fuerza el foco.
      for (final destination in _destinations) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = tester
            .getSemantics(find.text(destination.label))
            .getSemanticsData()
            .flagsCollection
            .isFocused;
        expect(focused, Tristate.isTrue);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/profile');
      expect(find.text('Contenido de Perfil'), findsOneWidget);
      _expectSelectedDestination(tester, 'Perfil');
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
