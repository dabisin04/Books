import 'package:equatable/equatable.dart';

abstract class FavoriteState extends Equatable {
  const FavoriteState();
}

class FavoriteInitial extends FavoriteState {
  @override
  List<Object?> get props => [];
}

class FavoriteLoading extends FavoriteState {
  @override
  List<Object?> get props => [];
}

class FavoriteLoaded extends FavoriteState {
  final List<String> favoriteBookIds;

  const FavoriteLoaded(this.favoriteBookIds);

  @override
  List<Object?> get props => [favoriteBookIds];
}

class FavoriteStatus extends FavoriteState {
  final bool isFavorite;

  const FavoriteStatus(this.isFavorite);

  @override
  List<Object?> get props => [isFavorite];
}

class FavoriteError extends FavoriteState {
  final String message;

  const FavoriteError(this.message);

  @override
  List<Object?> get props => [message];
}
