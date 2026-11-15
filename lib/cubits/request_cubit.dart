import 'package:flutter_bloc/flutter_bloc.dart';
import '../configs/generic_response.dart';
import '../services/session_service.dart';

class RequestState<T> {
  final T? data;
  final bool loading, working;
  final String? message;
  const RequestState({
    this.data,
    this.loading = false,
    this.working = false,
    this.message,
  });
}

// Mismos requisitos de lectura/escritura en revisión e historial: petición más
// reciente, envío único y sesión vigente. No es un repositorio genérico.
class RequestCubit<T> extends Cubit<RequestState<T>> {
  final Future<GenericResponse<T>> Function() loader;
  int _request = 0;
  RequestCubit(this.loader) : super(RequestState<T>()) {
    SessionService.changes.addListener(_sessionChanged);
  }
  void _sessionChanged() {
    _request++;
    if (!isClosed) emit(RequestState<T>());
  }

  bool _current(int request, int generation) =>
      !isClosed &&
      request == _request &&
      generation == SessionService.generation;
  bool _expired(GenericResponse<dynamic> result) {
    if (result.error != 'SESSION_INVALID') return false;
    SessionService.clear();
    return true;
  }

  Future<void> load() async {
    if (isClosed || state.working) return;
    final request = ++_request, generation = SessionService.generation;
    if (!SessionService.isAuthenticated) {
      emit(RequestState<T>());
      return;
    }
    emit(RequestState<T>(data: state.data, loading: true));
    try {
      final result = await loader();
      if (!_current(request, generation) || _expired(result)) return;
      emit(
        RequestState<T>(
          data: result.success ? result.data : null,
          message: result.success ? null : result.message,
        ),
      );
    } catch (_) {
      if (_current(request, generation)) {
        emit(RequestState<T>(message: 'No se pudo cargar la información.'));
      }
    }
  }

  Future<bool> perform(
    Future<GenericResponse<dynamic>> Function() action,
  ) async {
    if (isClosed || state.working || !SessionService.isAuthenticated) {
      return false;
    }
    final request = ++_request, generation = SessionService.generation;
    emit(RequestState<T>(data: state.data, working: true));
    try {
      final result = await action();
      if (!_current(request, generation) || _expired(result)) return false;
      emit(
        RequestState<T>(
          data: state.data,
          message: result.success ? null : result.message,
        ),
      );
      if (result.success ||
          ['ALREADY_VALIDATED', 'ALREADY_DENOUNCED'].contains(result.error)) {
        await load();
      }
      return result.success;
    } catch (_) {
      if (_current(request, generation)) {
        emit(
          RequestState<T>(
            data: state.data,
            message: 'No se pudo completar la operación.',
          ),
        );
      }
      return false;
    }
  }

  @override
  Future<void> close() {
    _request++;
    SessionService.changes.removeListener(_sessionChanged);
    return super.close();
  }
}
