import '../../entities/book/book.dart';

abstract class BookRepository {
  Future<void> addBook(Book book);
  Future<void> deleteBook(String bookId);
  Future<List<Book>> fetchBooks(
      {String? filter, String? sortBy, bool trashed = false});
  Future<void> updateBookViews(String bookId);
  Future<void> rateBook(String bookId, String userId, double rating);
  Future<List<Book>> searchBooks(String query);
  Future<List<Book>> getBooksByAuthor(String authorId);
  Future<List<Book>> getTopRatedBooks();
  Future<List<Book>> getMostViewedBooks();
  Future<void> updateBookContent(String bookId, Map<String, dynamic> content);
  Future<void> updateBookPublicationDate(
      String bookId, String? publicationDate);
  Future<void> updateBookDetails(String bookId,
      {String? title,
      String? description,
      List<String>? additionalGenres,
      String? genre,
      String? contentType});
  Future<void> trashBook(String bookId);
  Future<void> restoreBook(String bookId);
}
