import 'package:flutter_bloc/flutter_bloc.dart';
import '../../configs/generic_response.dart';
import '../../services/place_service.dart';
import '../../models/saturation_model.dart';
import '../../services/session_service.dart';
import 'places_state.dart';

class PlacesCubit extends Cubit<PlacesState> {
  final PlaceService _service;
  int _request = 0;
  SaturationLevel? _nivelSaturacion;
  SaturationLevel? get nivelSaturacion => _nivelSaturacion;
  Future<void> filtrarPorSaturacion(SaturationLevel? nivel) async {
    if (isClosed || !SessionService.isAuthenticated) return;
    _nivelSaturacion = nivel;
    await loadPlaces();
  }

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
    _nivelSaturacion = null;
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
      final active = [
        _consulta.isNotEmpty,
        _categoria.isNotEmpty,
        _nivelSaturacion != null,
      ].where((value) => value).length;
      final result = active > 1
          ? await _service.queryPlaces(
              nombre: _consulta,
              categoria: _categoria,
              nivel: _nivelSaturacion,
            )
          : _consulta.isNotEmpty
          ? await _service.searchPlaces(_consulta)
          : _categoria.isNotEmpty
          ? await _service.filterPlacesByCategory(_categoria)
          : _nivelSaturacion != null
          ? await _service.getPlacesBySaturation(_nivelSaturacion!)
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

  Future<GenericResponse<bool>> addFavorite(int placeId) async {
    final current = state;
    if (current is! PlacesLoaded) {
      return const GenericResponse(
        success: false,
        message: 'Espera a que se carguen los lugares e inténtalo de nuevo.',
      );
    }
    final operation = _request;
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
            selectionKey: latest.selectionKey,
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

  Future<void> refreshPlace(int id) async {
    final request = _request;
    final generation = SessionService.generation;
    final result = await _service.getPlace(id);
    if (isClosed ||
        request != _request ||
        generation != SessionService.generation) {
      return;
    }
    final current = state;
    if (current is! PlacesLoaded || !result.success || result.data == null) {
      return;
    }
    emit(
      PlacesLoaded(
        selectionKey: current.selectionKey,
        places: List.unmodifiable(
          current.places.map((p) => p.id == id ? result.data! : p),
        ),
      ),
    );
  }

  @override
  Future<void> close() {
    _request++;
    SessionService.changes.removeListener(_onSessionChanged);
    return super.close();
  }
}
