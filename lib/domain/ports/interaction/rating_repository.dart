import '../../../domain/entities/interaction/book_rating.dart';

abstract class BookRatingRepository {
  Future<void> upsertRating({
    required String userId,
    required String bookId,
    required double rating,
    DateTime? timestamp,
  });
  Future<double?> fetchUserRating({
    required String userId,
    required String bookId,
  });
  Future<({double average, int count})> fetchGlobalAverage(String bookId);
  Future<Map<int, int>> fetchDistribution(String bookId);
  Future<void> deleteRating({
    required String userId,
    required String bookId,
  });
  Future<List<BookRating>> fetchUserRatings({
    required String bookId,
    int page = 1,
    int limit = 10,
  });
}
