import 'dart:async';

import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/cubits/places/places_cubit.dart';
import 'package:crowdradar/cubits/places/places_state.dart';
import 'package:crowdradar/models/place_model.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/services/place_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';

const firstPlace = PlaceModel(
  id: 1,
  nombre: 'Lugar inicial',
  categoria: 'Parque',
  latitud: -12,
  longitud: -77,
  demostrativo: false,
);

const refreshedPlace = PlaceModel(
  id: 1,
  nombre: 'Datos refrescados',
  categoria: 'Parque',
  latitud: -12.1,
  longitud: -77.1,
  demostrativo: false,
  direccion: 'Dirección actualizada',
  referencia: 'Referencia actualizada',
);

const otherPlace = PlaceModel(
  id: 2,
  nombre: 'Otro lugar',
  categoria: 'Parque',
  latitud: -12.2,
  longitud: -77.2,
  demostrativo: false,
);

class PendingPlaces extends PlaceService {
  PendingPlaces({this.places = const [firstPlace]});

  final List<PlaceModel> places;
  final reads = <int, List<Completer<GenericResponse<PlaceModel>>>>{};
  final favorite = Completer<GenericResponse<bool>>();

  @override
  Future<GenericResponse<List<PlaceModel>>> getPlaces() async =>
      GenericResponse(success: true, data: places);

  @override
  Future<GenericResponse<PlaceModel>> getPlace(int id) {
    final response = Completer<GenericResponse<PlaceModel>>();
    reads.putIfAbsent(id, () => []).add(response);
    return response.future;
  }

  @override
  Future<GenericResponse<bool>> addFavorite(int id) => favorite.future;
}

void main() {
  setUp(() {
    SessionService.clear();
    SessionService.start(token: 'test-token', user: UserModel(id: 1));
  });
  tearDown(SessionService.clear);

  test('refresh antiguo no revierte un favorito confirmado después', () async {
    final service = PendingPlaces();
    final cubit = PlacesCubit(service);
    addTearDown(cubit.close);
    await cubit.loadPlaces();
    final selection = (cubit.state as PlacesLoaded).selectionKey;

    final read = cubit.refreshPlace(1);
    final mutation = cubit.addFavorite(1);
    service.favorite.complete(const GenericResponse(success: true, data: true));
    expect((await mutation).success, isTrue);
    expect((cubit.state as PlacesLoaded).places.single.esFavorito, isTrue);

    service.reads[1]!.single.complete(
      const GenericResponse(success: true, data: refreshedPlace),
    );
    await read;
    final state = cubit.state as PlacesLoaded;
    expect(state.places.single.esFavorito, isTrue);
    expect(state.selectionKey, same(selection));
    expect(state.places.single.nombre, refreshedPlace.nombre);
    expect(state.places.single.direccion, refreshedPlace.direccion);
    expect(state.places.single.referencia, refreshedPlace.referencia);
    expect(state.places.single.latitud, refreshedPlace.latitud);
    expect(state.places.single.longitud, refreshedPlace.longitud);
  });

  for (final duplicate in [false, true]) {
    test(
      'refresh durante alta ${duplicate ? 'duplicada' : 'exitosa'} conserva confirmación',
      () async {
        final service = PendingPlaces();
        final cubit = PlacesCubit(service);
        addTearDown(cubit.close);
        await cubit.loadPlaces();
        final mutation = cubit.addFavorite(1);
        final read = cubit.refreshPlace(1);
        service.favorite.complete(
          GenericResponse(
            success: !duplicate,
            data: duplicate ? null : true,
            error: duplicate ? PlaceService.favoriteAlreadyExists : null,
          ),
        );
        await mutation;
        service.reads[1]!.single.complete(
          const GenericResponse(success: true, data: firstPlace),
        );
        await read;
        expect((cubit.state as PlacesLoaded).places.single.esFavorito, isTrue);
      },
    );
  }

  test('alta rechazada no inventa favorito ni bloquea el refresh', () async {
    final service = PendingPlaces();
    final cubit = PlacesCubit(service);
    addTearDown(cubit.close);
    await cubit.loadPlaces();
    final read = cubit.refreshPlace(1);
    final mutation = cubit.addFavorite(1);
    service.favorite.complete(
      const GenericResponse(success: false, message: 'No se pudo agregar.'),
    );
    expect((await mutation).success, isFalse);
    expect((cubit.state as PlacesLoaded).places.single.esFavorito, isFalse);
    service.reads[1]!.single.complete(
      const GenericResponse(success: true, data: refreshedPlace),
    );
    await read;
    final place = (cubit.state as PlacesLoaded).places.single;
    expect(place.esFavorito, isFalse);
    expect(place.nombre, refreshedPlace.nombre);
  });

  test(
    'consulta posterior al alta puede actualizar el favorito a false',
    () async {
      final service = PendingPlaces();
      final cubit = PlacesCubit(service);
      addTearDown(cubit.close);
      await cubit.loadPlaces();
      final oldRead = cubit.refreshPlace(1);
      final mutation = cubit.addFavorite(1);
      service.favorite.complete(
        const GenericResponse(success: true, data: true),
      );
      await mutation;
      expect((cubit.state as PlacesLoaded).places.single.esFavorito, isTrue);
      final currentRead = cubit.refreshPlace(1);
      service.reads[1]![1].complete(
        const GenericResponse(success: true, data: refreshedPlace),
      );
      await currentRead;
      expect((cubit.state as PlacesLoaded).places.single.esFavorito, isFalse);
      service.reads[1]![0].complete(
        GenericResponse(
          success: true,
          data: firstPlace.copyWith(esFavorito: true),
        ),
      );
      await oldRead;
      expect((cubit.state as PlacesLoaded).places.single.esFavorito, isFalse);
    },
  );

  test('alta en un lugar no bloquea el refresh de otro lugar', () async {
    final service = PendingPlaces(places: const [firstPlace, otherPlace]);
    final cubit = PlacesCubit(service);
    addTearDown(cubit.close);
    await cubit.loadPlaces();
    final selection = (cubit.state as PlacesLoaded).selectionKey;
    final read = cubit.refreshPlace(2);
    final mutation = cubit.addFavorite(1);
    service.favorite.complete(const GenericResponse(success: true, data: true));
    await mutation;
    service.reads[2]!.single.complete(
      GenericResponse(
        success: true,
        data: otherPlace.copyWith(esFavorito: true),
      ),
    );
    await read;
    final state = cubit.state as PlacesLoaded;
    expect(state.places.every((place) => place.esFavorito), isTrue);
    expect(state.selectionKey, same(selection));
  });

  for (final change in ['logout', 'otra cuenta', 'misma cuenta']) {
    test('refresh y alta tardíos no repueblan datos tras $change', () async {
      final service = PendingPlaces();
      final cubit = PlacesCubit(service);
      addTearDown(cubit.close);
      await cubit.loadPlaces();
      final read = cubit.refreshPlace(1);
      final mutation = cubit.addFavorite(1);
      if (change == 'logout') {
        SessionService.clear();
      } else {
        SessionService.start(
          token: 'test-token',
          user: UserModel(id: change == 'otra cuenta' ? 2 : 1),
        );
        await cubit.loadPlaces();
      }
      final current = cubit.state;
      service.favorite.complete(
        const GenericResponse(success: true, data: true),
      );
      await mutation;
      service.reads[1]!.single.complete(
        GenericResponse(
          success: true,
          data: refreshedPlace.copyWith(esFavorito: true),
        ),
      );
      await read;
      expect(cubit.state, same(current));
      if (change == 'logout') {
        expect(cubit.state, isA<PlacesInitial>());
      } else {
        expect((cubit.state as PlacesLoaded).places.single.esFavorito, isFalse);
        expect(SessionService.currentUser?.id, change == 'otra cuenta' ? 2 : 1);
      }
    });
  }
}
