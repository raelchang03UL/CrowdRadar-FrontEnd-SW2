import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/place_service.dart';
import '../../configs/generic_response.dart';
import '../../services/session_service.dart';
import 'favorites_state.dart';

class FavoritesCubit extends Cubit<FavoritesState> {
  final PlaceService _service;
  int _request = 0;

  FavoritesCubit(this._service) : super(FavoritesInitial()) {
    SessionService.changes.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    _request++;
    if (!isClosed) emit(FavoritesInitial());
  }

  Future<void> loadFavorites() async {
    if (isClosed) return;
    final current = state;
    if (current is FavoritesLoaded && current.removing.isNotEmpty) return;
    final request = ++_request;
    final generation = SessionService.generation;
    if (!SessionService.isAuthenticated) {
      emit(FavoritesInitial());
      return;
    }
    emit(FavoritesLoading());
    try {
      final result = await _service.getFavorites();
      if (isClosed ||
          request != _request ||
          generation != SessionService.generation) {
        return;
      }
      if (result.success && result.data != null) {
        emit(FavoritesLoaded(places: result.data!));
      } else {
        emit(FavoritesError(message: result.message));
      }
    } catch (_) {
      if (isClosed ||
          request != _request ||
          generation != SessionService.generation) {
        return;
      }
      emit(FavoritesError(message: PlaceService.loadError));
    }
  }

  Future<GenericResponse<bool>?> removeFavorite(int id) async {
    final current = state;
    if (isClosed ||
        current is! FavoritesLoaded ||
        current.removing.contains(id)) {
      return null;
    }
    final generation = SessionService.generation;
    final request = _request;
    emit(
      FavoritesLoaded(
        places: current.places,
        removing: {...current.removing, id},
      ),
    );
    final result = await _service.removeFavorite(id);
    if (isClosed ||
        request != _request ||
        generation != SessionService.generation) {
      return null;
    }
    final latest = state;
    if (latest is! FavoritesLoaded) return null;
    emit(
      FavoritesLoaded(
        places: result.success
            ? latest.places.where((p) => p.id != id).toList(growable: false)
            : latest.places,
        removing: {...latest.removing}..remove(id),
      ),
    );
    return result.success
        ? const GenericResponse(
            success: true,
            data: true,
            message: 'Lugar eliminado de tus favoritos.',
          )
        : result;
  }

  @override
  Future<void> close() {
    _request++;
    SessionService.changes.removeListener(_onSessionChanged);
    return super.close();
  }
}
