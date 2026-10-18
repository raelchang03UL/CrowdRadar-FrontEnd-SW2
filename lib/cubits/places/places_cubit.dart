import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/place_service.dart';
import '../../services/session_service.dart';
import 'places_state.dart';

class PlacesCubit extends Cubit<PlacesState> {
  final PlaceService _service;
  int _request = 0;
  String _categoria = '';
  String get categoria => _categoria;
  String _consulta = '';
  String get consulta => _consulta;

  PlacesCubit(this._service) : super(PlacesInitial()) {
    SessionService.changes.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    _request++;
    _consulta = '';
    _categoria = '';
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
      final result = _consulta.isNotEmpty && _categoria.isNotEmpty
          ? await _service.queryPlaces(nombre: _consulta, categoria: _categoria)
          : _consulta.isNotEmpty ? await _service.searchPlaces(_consulta)
          : _categoria.isNotEmpty ? await _service.filterPlacesByCategory(_categoria)
          : await _service.getPlaces();
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

  Future<void> searchPlaces(String consulta) {
    if (isClosed) return Future.value();
    _consulta = consulta.trim();
    return loadPlaces();
  }

  Future<void> filterByCategory(String categoria) {
    if (isClosed) return Future.value();
    _categoria = categoria.trim();
    return loadPlaces();
  }

  @override
  Future<void> close() {
    _request++;
    SessionService.changes.removeListener(_onSessionChanged);
    return super.close();
  }
}
