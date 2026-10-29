import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/place_service.dart';
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

  @override
  Future<void> close() {
    _request++;
    SessionService.changes.removeListener(_onSessionChanged);
    return super.close();
  }
}
