import 'package:flutter_bloc/flutter_bloc.dart';
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

  @override
  Future<void> close() {
    _request++;
    SessionService.changes.removeListener(_onSessionChanged);
    return super.close();
  }
}
