import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/place_service.dart';
import '../../services/session_service.dart';

abstract class EstadoCategorias {}

class CategoriasInicial extends EstadoCategorias {}

class CategoriasCargando extends EstadoCategorias {}

class CategoriasCargadas extends EstadoCategorias {
  final List<String> categorias;
  CategoriasCargadas(this.categorias);
}

class CategoriasError extends EstadoCategorias {
  final String mensaje;
  CategoriasError(this.mensaje);
}

class CategoriasCubit extends Cubit<EstadoCategorias> {
  final PlaceService _servicio;
  int _solicitud = 0;
  CategoriasCubit(this._servicio) : super(CategoriasInicial()) {
    SessionService.changes.addListener(_cambioSesion);
  }

  void _cambioSesion() {
    _solicitud++;
    if (!isClosed) emit(CategoriasInicial());
  }

  Future<void> loadCategories() async {
    if (isClosed) return;
    final solicitud = ++_solicitud;
    final generacion = SessionService.generation;
    if (!SessionService.isAuthenticated) {
      emit(CategoriasInicial());
      return;
    }
    emit(CategoriasCargando());
    try {
      final resultado = await _servicio.getCategories();
      if (isClosed ||
          solicitud != _solicitud ||
          generacion != SessionService.generation) {
        return;
      }
      if (resultado.success && resultado.data != null) {
        emit(CategoriasCargadas(resultado.data!));
      } else {
        emit(CategoriasError(resultado.message));
      }
    } catch (_) {
      if (isClosed ||
          solicitud != _solicitud ||
          generacion != SessionService.generation) {
        return;
      }
      emit(CategoriasError(PlaceService.categoriesError));
    }
  }

  @override
  Future<void> close() {
    _solicitud++;
    SessionService.changes.removeListener(_cambioSesion);
    return super.close();
  }
}
