import 'package:flutter_bloc/flutter_bloc.dart';

import '../../configs/generic_response.dart';
import '../../services/place_service.dart';
import '../../services/session_service.dart';
import 'places_state.dart';

class PlacesCubit extends Cubit<PlacesState> {
  final PlaceService _service;
  int _request = 0;

  PlacesCubit(this._service) : super(PlacesInitial()) {
    SessionService.changes.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    _request++;
    if (!isClosed) emit(PlacesInitial());
  }

  Future<void> loadPlaces() async {
    if (isClosed) return;
    final request = ++_request;
    final generation = SessionService.generation;
    if (!SessionService.isAuthenticated) {
      emit(PlacesInitial());
      return;
    }
    emit(PlacesLoading());
    try {
      final result = await _service.getPlaces();
      if (isClosed ||
          request != _request ||
          generation != SessionService.generation) {
        return;
      }
      if (result.success && result.data != null) {
        emit(PlacesLoaded(places: result.data!));
      } else {
        emit(PlacesError(message: result.message));
      }
    } catch (_) {
      if (isClosed ||
          request != _request ||
          generation != SessionService.generation) {
        return;
      }
      emit(PlacesError(message: PlaceService.loadError));
    }
  }

  Future<GenericResponse<bool>> addFavorite(int placeId) async {
    final current = state;
    if (current is! PlacesLoaded) {
      return const GenericResponse(
        success: false,
        message: 'Espera a que se carguen los lugares e inténtalo de nuevo.',
      );
    }
    final operation = ++_request;
    final generation = SessionService.generation;
    final result = await _service.addFavorite(placeId);
    if (!isClosed &&
        operation == _request &&
        generation == SessionService.generation &&
        (result.success ||
            result.error == PlaceService.favoriteAlreadyExists)) {
      final latest = state;
      if (latest is PlacesLoaded) {
        emit(
          PlacesLoaded(
            places: List.unmodifiable(
              latest.places
                  .map(
                    (place) => place.id == placeId
                        ? place.copyWith(esFavorito: true)
                        : place,
                  )
                  .toList(growable: false),
            ),
          ),
        );
      }
    }
    return result;
  }

  @override
  Future<void> close() {
    _request++;
    SessionService.changes.removeListener(_onSessionChanged);
    return super.close();
  }
}
