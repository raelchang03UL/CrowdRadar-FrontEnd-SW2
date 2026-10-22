import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/place_model.dart';
import '../../services/place_service.dart';
import '../../services/session_service.dart';

abstract class PlaceDetailState {}

class PlaceDetailInitial extends PlaceDetailState {}

class PlaceDetailLoading extends PlaceDetailState {}

class PlaceDetailLoaded extends PlaceDetailState {
  final PlaceModel place;
  PlaceDetailLoaded(this.place);
}

class PlaceDetailError extends PlaceDetailState {
  final String message;
  PlaceDetailError(this.message);
}

class PlaceDetailCubit extends Cubit<PlaceDetailState> {
  final PlaceService _service;
  final int id;
  int _request = 0;

  PlaceDetailCubit(this._service, this.id) : super(PlaceDetailInitial()) {
    SessionService.changes.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    _request++;
    if (!isClosed) emit(PlaceDetailInitial());
  }

  Future<void> loadPlace() async {
    if (isClosed) return;
    final request = ++_request;
    final generation = SessionService.generation;
    if (!SessionService.isAuthenticated) {
      emit(PlaceDetailInitial());
      return;
    }
    emit(PlaceDetailLoading());
    try {
      final result = await _service.getPlace(id);
      if (isClosed ||
          request != _request ||
          generation != SessionService.generation) {
        return;
      }
      if (result.success && result.data != null) {
        emit(PlaceDetailLoaded(result.data!));
      } else {
        emit(PlaceDetailError(result.message));
      }
    } catch (_) {
      if (isClosed ||
          request != _request ||
          generation != SessionService.generation) {
        return;
      }
      emit(PlaceDetailError(PlaceService.detailError));
    }
  }

  @override
  Future<void> close() {
    _request++;
    SessionService.changes.removeListener(_onSessionChanged);
    return super.close();
  }
}
