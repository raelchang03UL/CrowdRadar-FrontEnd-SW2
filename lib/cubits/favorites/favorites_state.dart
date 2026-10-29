import '../../models/place_model.dart';

abstract class FavoritesState {}

class FavoritesInitial extends FavoritesState {}

class FavoritesLoading extends FavoritesState {}

class FavoritesLoaded extends FavoritesState {
  final List<PlaceModel> places;
  FavoritesLoaded({required this.places});
}

class FavoritesError extends FavoritesState {
  final String message;
  FavoritesError({required this.message});
}
