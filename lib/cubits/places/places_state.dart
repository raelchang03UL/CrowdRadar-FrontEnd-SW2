import '../../models/place_model.dart';

abstract class PlacesState {}

class PlacesInitial extends PlacesState {}

class PlacesLoading extends PlacesState {}

class PlacesLoaded extends PlacesState {
  final List<PlaceModel> places;
  final Object selectionKey;
  PlacesLoaded({required this.places, Object? selectionKey})
    : selectionKey = selectionKey ?? Object();
}

class PlacesError extends PlacesState {
  final String message;
  PlacesError({required this.message});
}
