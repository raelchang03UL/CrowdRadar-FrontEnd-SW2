import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/place_service.dart';
import '../../models/saturation_model.dart';
import '../../services/session_service.dart';
import 'places_state.dart';

class PlacesCubit extends Cubit<PlacesState> {
  final PlaceService _service;
  int _request = 0;
  SaturationLevel? _nivelSaturacion;
  int _generacionFiltro = SessionService.generation;

  SaturationLevel? get nivelSaturacion => _nivelSaturacion;

  PlacesCubit(this._service) : super(PlacesInitial()) {
    SessionService.changes.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    _request++;
    _nivelSaturacion = null;
    _generacionFiltro = SessionService.generation;
    if (!isClosed) emit(PlacesInitial());
  }

  Future<void> filtrarPorSaturacion(SaturationLevel? nivel) async {
    if (isClosed || !SessionService.isAuthenticated) return;
    _nivelSaturacion = nivel;
    _generacionFiltro = SessionService.generation;
    await loadPlaces();
  }

  Future<void> loadPlaces() async {
    if (isClosed) return;
    final request = ++_request;
    final generation = SessionService.generation;
    if (_generacionFiltro != generation) {
      _nivelSaturacion = null;
      _generacionFiltro = generation;
    }
    if (!SessionService.isAuthenticated) {
      emit(PlacesInitial());
      return;
    }
    emit(PlacesLoading());
    try {
      final nivel = _nivelSaturacion;
      final result = nivel == null
          ? await _service.getPlaces()
          : await _service.getPlacesBySaturation(nivel);
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
