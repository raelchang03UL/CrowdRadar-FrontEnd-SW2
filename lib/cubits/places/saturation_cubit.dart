import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/saturation_model.dart';
import '../../services/saturation_service.dart';
import '../../services/session_service.dart';

enum SaturationStatus { initial, loading, loaded, error }

class SaturationState {
  final SaturationStatus status;
  final int? placeId;
  final SaturationModel? data;
  final String message;
  const SaturationState({
    this.status = SaturationStatus.initial,
    this.placeId,
    this.data,
    this.message = '',
  });
}

class SaturationCubit extends Cubit<SaturationState> {
  final SaturationService _service;
  int _request = 0;

  SaturationCubit(this._service) : super(const SaturationState()) {
    SessionService.changes.addListener(clearSelection);
  }

  void clearSelection() {
    _request++;
    if (!isClosed) emit(const SaturationState());
  }

  Future<void> loadPlace(int placeId) async {
    if (isClosed) return;
    final request = ++_request;
    final generation = SessionService.generation;
    if (!SessionService.isAuthenticated) {
      emit(const SaturationState());
      return;
    }
    emit(SaturationState(status: SaturationStatus.loading, placeId: placeId));
    try {
      final result = await _service.getSaturation(placeId);
      if (_obsolete(request, generation)) return;
      if (result.success && result.data?.placeId == placeId) {
        emit(
          SaturationState(
            status: SaturationStatus.loaded,
            placeId: placeId,
            data: result.data,
          ),
        );
      } else {
        emit(
          SaturationState(
            status: SaturationStatus.error,
            placeId: placeId,
            message: result.message.isEmpty
                ? SaturationService.loadError
                : result.message,
          ),
        );
      }
    } catch (_) {
      if (_obsolete(request, generation)) return;
      emit(
        SaturationState(
          status: SaturationStatus.error,
          placeId: placeId,
          message: SaturationService.loadError,
        ),
      );
    }
  }

  bool _obsolete(int request, int generation) =>
      isClosed ||
      request != _request ||
      generation != SessionService.generation;

  @override
  Future<void> close() {
    _request++;
    SessionService.changes.removeListener(clearSelection);
    return super.close();
  }
}
