import '../../entities/interaction/book_rating.dart';

abstract class RatingRepository {
  Future<void> addRating(BookRating rating);
  Future<void> updateRating(String bookId, String userId, int newRating);
  Future<double> getAverageRating(String bookId);
  Future<List<BookRating>> getRatingsByBook(String bookId);
}
