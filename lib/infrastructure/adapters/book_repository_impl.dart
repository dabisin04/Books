import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/book/book.dart';
import '../../domain/ports/book/book_repository.dart';
import '../database/database_helper.dart';
import '../utils/shared_prefs_helper.dart';

class BookRepositoryImpl implements BookRepository {
  final SharedPrefsService sharedPrefs;
  Future<Database> get _database async =>
      await DatabaseHelper.instance.database;

  static const String cacheKey = 'cached_books';

  BookRepositoryImpl(this.sharedPrefs);

  @override
  Future<void> addBook(Book book) async {
    final db = await _database;
    final String bookId = book.id.isEmpty ? const Uuid().v4() : book.id;
    if (book.authorId.isEmpty) {
      throw Exception("Error: El libro debe tener un authorId válido.");
    }

    final newBook = book.copyWith(
      id: bookId,
      views: book.views ?? 0,
      content: book.content ?? '',
    );

    await db.insert(
      'books',
      newBook.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _cacheBooks();
  }

  @override
  Future<void> deleteBook(String bookId) async {
    final db = await _database;
    await db.delete('books', where: 'id = ?', whereArgs: [bookId]);
    await _cacheBooks();
  }

  @override
  Future<void> trashBook(String bookId) async {
    final db = await _database;
    await db.update(
      'books',
      {'is_trashed': 1},
      where: 'id = ?',
      whereArgs: [bookId],
    );
    await _cacheBooks();
  }

  @override
  Future<void> restoreBook(String bookId) async {
    final db = await _database;
    await db.update(
      'books',
      {'is_trashed': 0},
      where: 'id = ?',
      whereArgs: [bookId],
    );
    await _cacheBooks();
  }

  @override
  Future<List<Book>> fetchBooks(
      {String? filter, String? sortBy, bool trashed = false}) async {
    final cachedData = await sharedPrefs.getValue(cacheKey);
    List<Book>? books;
    if (cachedData != null) {
      final List<dynamic> cachedList = jsonDecode(cachedData);
      books = cachedList.map((data) => Book.fromMap(data)).toList();
      books = books
          .where((book) => book.toMap()['is_trashed'] == (trashed ? 1 : 0))
          .toList();
      if (books.isNotEmpty) return books;
    }

    final db = await _database;
    List<Map<String, dynamic>> result = await db.query(
      'books',
      where: 'is_trashed = ?',
      whereArgs: [trashed ? 1 : 0],
    );
    books = result.map((map) => Book.fromMap(map)).toList();
    await _cacheBooks();
    return books;
  }

  @override
  Future<void> updateBookViews(String bookId) async {
    final db = await _database;
    await db
        .rawUpdate('UPDATE books SET views = views + 1 WHERE id = ?', [bookId]);
    await _cacheBooks();
  }

  @override
  Future<void> rateBook(String bookId, String userId, double rating) async {
    final db = await _database;
    await db.insert(
      'book_ratings',
      {
        'id': '$userId-$bookId',
        'user_id': userId,
        'book_id': bookId,
        'rating': rating
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final List<Map<String, dynamic>> ratings = await db.query(
      'book_ratings',
      columns: ['rating'],
      where: 'book_id = ?',
      whereArgs: [bookId],
    );

    if (ratings.isNotEmpty) {
      double avgRating = ratings.fold<double>(
              0, (sum, item) => sum + (item['rating'] as num).toDouble()) /
          ratings.length;
      await db.update(
        'books',
        {'rating': avgRating},
        where: 'id = ?',
        whereArgs: [bookId],
      );
    }

    await _cacheBooks();
  }

  @override
  Future<List<Book>> searchBooks(String query) async {
    final db = await _database;
    final List<Map<String, dynamic>> result = await db.query(
      'books',
      where: 'title LIKE ? AND is_trashed = 0',
      whereArgs: ['%$query%'],
    );

    return result.map((map) => Book.fromMap(map)).toList();
  }

  @override
  Future<List<Book>> getBooksByAuthor(String authorId) async {
    final db = await _database;
    final List<Map<String, dynamic>> result = await db.query(
      'books',
      where: 'author_id = ? AND is_trashed = 0',
      whereArgs: [authorId],
    );

    return result.map((map) => Book.fromMap(map)).toList();
  }

  @override
  Future<List<Book>> getTopRatedBooks() async {
    final db = await _database;
    final List<Map<String, dynamic>> result = await db.query(
      'books',
      where: 'is_trashed = 0',
      orderBy: 'rating DESC',
      limit: 10,
    );

    return result.map((map) => Book.fromMap(map)).toList();
  }

  @override
  Future<List<Book>> getMostViewedBooks() async {
    final db = await _database;
    final List<Map<String, dynamic>> result = await db.query(
      'books',
      where: 'is_trashed = 0',
      orderBy: 'views DESC',
      limit: 10,
    );

    return result.map((map) => Book.fromMap(map)).toList();
  }

  @override
  Future<void> updateBookContent(String bookId, String content) async {
    final db = await _database;
    await db.update(
      'books',
      {'content': content},
      where: 'id = ?',
      whereArgs: [bookId],
    );
    await _cacheBooks();
  }

  @override
  Future<void> updateBookPublicationDate(
      String bookId, String? publicationDate) async {
    final db = await _database;
    await db.update(
      'books',
      {'publication_date': publicationDate},
      where: 'id = ?',
      whereArgs: [bookId],
    );
    await _cacheBooks();
  }

  @override
  Future<void> updateBookDetails(String bookId,
      {String? title,
      String? description,
      List<String>? additionalGenres,
      String? genre}) async {
    final db = await _database;
    final values = <String, dynamic>{};

    if (title != null) values['title'] = title;
    if (description != null) values['description'] = description;
    if (additionalGenres != null) {
      values['additional_genres'] = jsonEncode(additionalGenres);
    }
    if (genre != null) values['genre'] = genre;

    if (values.isNotEmpty) {
      await db.update('books', values, where: 'id = ?', whereArgs: [bookId]);
      await _cacheBooks();
    }
  }

  Future<void> _cacheBooks() async {
    final db = await _database;
    final List<Map<String, dynamic>> result = await db.query('books');
    await sharedPrefs.setValue(cacheKey, jsonEncode(result));
  }
}
