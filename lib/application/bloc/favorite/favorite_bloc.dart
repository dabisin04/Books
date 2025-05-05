import 'package:books/domain/ports/library/favorite_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'favorite_event.dart';
import 'favorite_state.dart';

class FavoriteBloc extends Bloc<FavoriteEvent, FavoriteState> {
  final FavoriteRepository repository;

  FavoriteBloc(this.repository) : super(FavoriteInitial()) {
    on<LoadFavoritesEvent>(_onLoadFavorites);
    on<AddFavoriteEvent>(_onAddFavorite);
    on<RemoveFavoriteEvent>(_onRemoveFavorite);
    on<CheckIfFavoriteEvent>(_onCheckFavorite);
  }

  Future<void> _onLoadFavorites(
    LoadFavoritesEvent event,
    Emitter<FavoriteState> emit,
  ) async {
    emit(FavoriteLoading());
    try {
      final favorites = await repository.getFavoriteBookIds(event.userId);
      emit(FavoriteLoaded(favorites));
    } catch (e) {
      emit(FavoriteError("Error al cargar favoritos: $e"));
    }
  }

  Future<void> _onAddFavorite(
    AddFavoriteEvent event,
    Emitter<FavoriteState> emit,
  ) async {
    try {
      await repository.addToFavorites(
          userId: event.userId, bookId: event.bookId);
      add(CheckIfFavoriteEvent(event.userId, event.bookId));
      add(LoadFavoritesEvent(event.userId));
    } catch (e) {
      emit(FavoriteError("Error al agregar a favoritos: $e"));
    }
  }

  Future<void> _onRemoveFavorite(
    RemoveFavoriteEvent event,
    Emitter<FavoriteState> emit,
  ) async {
    try {
      await repository.removeFromFavorites(
        userId: event.userId,
        bookId: event.bookId,
      );

      // Esperamos microtask para no interrumpir el flujo
      Future.microtask(() {
        add(CheckIfFavoriteEvent(event.userId, event.bookId));
        add(LoadFavoritesEvent(event.userId));
      });
    } catch (e) {
      emit(FavoriteError("Error al quitar de favoritos: $e"));
    }
  }

  Future<void> _onCheckFavorite(
    CheckIfFavoriteEvent event,
    Emitter<FavoriteState> emit,
  ) async {
    try {
      final isFav = await repository.isFavorite(
        userId: event.userId,
        bookId: event.bookId,
      );
      emit(FavoriteStatus(isFav));
    } catch (e) {
      emit(FavoriteError("Error al verificar favorito: $e"));
    }
  }
}
