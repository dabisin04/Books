abstract class FavoriteRepository {
  Future<void> addToFavorites({
    required String userId,
    required String bookId,
  });
  Future<void> removeFromFavorites({
    required String userId,
    required String bookId,
  });
  Future<List<String>> getFavoriteBookIds(String userId);
  Future<bool> isFavorite({
    required String userId,
    required String bookId,
  });
}
