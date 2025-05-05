import 'package:equatable/equatable.dart';

abstract class FavoriteEvent extends Equatable {
  const FavoriteEvent();
}

class LoadFavoritesEvent extends FavoriteEvent {
  final String userId;

  const LoadFavoritesEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

class AddFavoriteEvent extends FavoriteEvent {
  final String userId;
  final String bookId;

  const AddFavoriteEvent(this.userId, this.bookId);

  @override
  List<Object?> get props => [userId, bookId];
}

class RemoveFavoriteEvent extends FavoriteEvent {
  final String userId;
  final String bookId;

  const RemoveFavoriteEvent(this.userId, this.bookId);

  @override
  List<Object?> get props => [userId, bookId];
}

class CheckIfFavoriteEvent extends FavoriteEvent {
  final String userId;
  final String bookId;

  const CheckIfFavoriteEvent(this.userId, this.bookId);

  @override
  List<Object?> get props => [userId, bookId];
}
