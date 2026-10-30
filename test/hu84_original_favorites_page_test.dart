import 'dart:convert';

import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/favoritos/favoritos_page.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const favoritePlace = {
  'id': 7,
  'nombre': 'Parque Central',
  'categoria': 'Parque',
  'latitud': -12.0464,
  'longitud': -77.0428,
  'demostrativo': false,
};

void main() {
  setUp(() {
    SessionService.clear();
    SessionService.start(
      token: 'favorites-removal-test',
      user: const UserModel(id: 1, nombre: 'Usuario'),
    );
  });
  tearDown(SessionService.clear);

  testWidgets('elimina el favorito y la siguiente consulta ya no lo muestra', (
    tester,
  ) async {
    var isFavorite = true;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: FavoritosPage()));
        await tester.pumpAndSettle();
        expect(find.text('Parque Central'), findsOneWidget);

        await tester.tap(find.byTooltip('Quitar de favoritos'));
        await tester.pumpAndSettle();
        expect(find.text('Parque Central'), findsNothing);
        expect(find.text('Lugar eliminado de tus favoritos.'), findsOneWidget);

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpWidget(const MaterialApp(home: FavoritosPage()));
        await tester.pumpAndSettle();
        expect(find.text('Sin favoritos todavía'), findsOneWidget);
      },
      () => MockClient((request) async {
        expect(
          request.headers['Authorization'],
          'Bearer favorites-removal-test',
        );
        if (request.method == 'GET') {
          expect(request.url.path, '/api/places/favorites');
          return http.Response(
            jsonEncode({
              'data': isFavorite ? [favoritePlace] : [],
            }),
            200,
          );
        }
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/places/7/favorite');
        isFavorite = false;
        return http.Response('', 204);
      }),
    );
  });

  testWidgets('si falla la eliminación conserva el lugar y comunica el error', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: FavoritosPage()));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Quitar de favoritos'));
        await tester.pumpAndSettle();
        expect(find.text('Parque Central'), findsOneWidget);
        expect(find.text(PlaceService.favoriteError), findsOneWidget);
      },
      () => MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'data': [favoritePlace],
            }),
            200,
          );
        }
        return http.Response('internal details', 503);
      }),
    );
  });
}
