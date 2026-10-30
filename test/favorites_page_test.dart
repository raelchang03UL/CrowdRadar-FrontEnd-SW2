import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/favoritos/favoritos_page.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FavoritesService extends PlaceService {
  final Future<GenericResponse<List<PlaceModel>>> Function() load;

  _FavoritesService(this.load);

  @override
  Future<GenericResponse<List<PlaceModel>>> getFavorites() => load();
}

void main() {
  const place = PlaceModel(
    id: 1,
    nombre: 'Parque Central',
    categoria: 'Parque',
    latitud: -12.0464,
    longitud: -77.0428,
    demostrativo: false,
    esFavorito: true,
  );

  setUp(() {
    SessionService.clear();
    SessionService.start(token: 'favorites-test', user: const UserModel(id: 1));
  });
  tearDown(SessionService.clear);

  Future<void> mount(WidgetTester tester, PlaceService service) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: FavoritosPage(service: service),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra los lugares guardados', (tester) async {
    await mount(
      tester,
      _FavoritesService(
        () async => const GenericResponse(success: true, data: [place]),
      ),
    );
    expect(find.text('Parque Central'), findsOneWidget);
    expect(find.text('Parque'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra el estado vacío cuando no hay favoritos', (
    tester,
  ) async {
    await mount(
      tester,
      _FavoritesService(
        () async => const GenericResponse(success: true, data: []),
      ),
    );
    expect(find.text('Sin favoritos todavía'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite reintentar si falla la carga de favoritos', (
    tester,
  ) async {
    var calls = 0;
    await mount(
      tester,
      _FavoritesService(
        () async => calls++ == 0
            ? const GenericResponse(
                success: false,
                message: PlaceService.loadError,
              )
            : const GenericResponse(success: true, data: [place]),
      ),
    );
    expect(find.text(PlaceService.loadError), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Parque Central'), findsOneWidget);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });
}
