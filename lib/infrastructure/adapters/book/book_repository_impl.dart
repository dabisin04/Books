import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/book/book.dart';
import '../../../domain/ports/book/book_repository.dart';
import '../../database/database_helper.dart';
import '../../utils/shared_prefs_helper.dart';

class BookRepositoryImpl implements BookRepository {
  final SharedPrefsService sharedPrefs;
  final Connectivity _connectivity = Connectivity();
  Future<Database> get _database async =>
      await DatabaseHelper.instance.database;
  static const String cacheKey = 'cached_books';
  static String baseUrl = dotenv.env['API_BASE_URL'] ?? '';
  static String apiKey = dotenv.env['API_KEY'] ?? '';
  static final Duration apiTimeout = Duration(
    seconds: int.tryParse(dotenv.env['API_TIMEOUT'] ?? '5') ?? 5,
  );

  BookRepositoryImpl(this.sharedPrefs);

  Map<String, String> _headers({bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json',
      'X-API-KEY': apiKey,
    };
  }

  Future<bool> _isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _syncLocalData() async {
    if (!await _isOnline()) return;

    final db = await _database;
    final localBooks = await db.query('books');
    for (var bookMap in localBooks) {
      final book = Book.fromMap(bookMap);
      try {
        // Check if book exists on server
        final response = await http
            .get(Uri.parse('$baseUrl/book/${book.id}'),
                headers: _headers(json: false))
            .timeout(apiTimeout);
        if (response.statusCode == 404) {
          // Add new book to server
          await http.post(
            Uri.parse('$baseUrl/addBook'),
            headers: _headers(),
            body: jsonEncode(book.toMap()),
          );
        } else if (response.statusCode == 200) {
          // Update existing book with specific fields
          await http.put(
            Uri.parse('$baseUrl/updateBookDetails/${book.id}'),
            headers: _headers(),
            body: jsonEncode({
              'title': book.title,
              'description': book.description,
              'additional_genres': book.additionalGenres.isNotEmpty
                  ? book.additionalGenres
                  : null,
              'genre': book.genre,
              'content_type': book.contentType,
            }),
          );
        } else {
          print(
              '⚠️ Unexpected status code for book ${book.id}: ${response.statusCode}');
        }
      } catch (e) {
        print('Sync error for book ${book.id}: $e');
      }
    }
  }

  @override
  Future<void> addBook(Book book) async {
    final db = await _database;
    final String bookId = book.id.isEmpty ? const Uuid().v4() : book.id;

    // Verify if book exists locally
    final localExists = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM books WHERE id = ?',
          [bookId],
        ))! >
        0;

    if (localExists) {
      print(
          "⚠️ El libro con ID $bookId ya existe localmente. Se omite la inserción.");
      return;
    }

    if (book.authorId.isEmpty) {
      throw Exception("Error: El libro debe tener un authorId válido.");
    }

    final newBook = book.copyWith(
      id: bookId,
      content: book.content ?? {},
    );

    if (await _isOnline()) {
      try {
        final checkResponse = await http
            .get(Uri.parse('$baseUrl/book/$bookId'),
                headers: _headers(json: false))
            .timeout(apiTimeout);

        if (checkResponse.statusCode == 404) {
          final response = await http.post(
            Uri.parse('$baseUrl/addBook'),
            headers: _headers(),
            body: jsonEncode(newBook.toMap()),
          );

          if (response.statusCode == 409) {
            print("⚠️ El libro con ID $bookId ya existe en la API.");
            // Mark as synced locally to avoid repeated attempts
            await db.insert('books', newBook.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          } else if (response.statusCode == 201) {
            await db.insert('books', newBook.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          } else {
            throw Exception(
                'Error al agregar el libro: ${response.statusCode} - ${response.body}');
          }
        } else {
          print("⚠️ El libro con ID $bookId ya existe en la API.");
        }
      } catch (e) {
        print(
            "🌐 Error al enviar libro a API. Guardando localmente. Error: $e");
        await db.insert('books', newBook.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } else {
      print("📴 Sin conexión. Guardando localmente.");
      await db.insert('books', newBook.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await _cacheBooks();
    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> deleteBook(String bookId) async {
    final db = await _database;
    if (await _isOnline()) {
      try {
        final response = await http.delete(
            Uri.parse('$baseUrl/deleteBook/$bookId'),
            headers: _headers(json: false));
        if (response.statusCode != 200) {
          throw Exception(
              'Failed to delete book from API: ${response.statusCode}');
        }
      } catch (e) {
        print('API error during deleteBook: $e');
        await db.delete('books', where: 'id = ?', whereArgs: [bookId]);
      }
    } else {
      await db.delete('books', where: 'id = ?', whereArgs: [bookId]);
    }

    await _cacheBooks();
    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> trashBook(String bookId) async {
    final db = await _database;
    if (await _isOnline()) {
      try {
        final response = await http.put(Uri.parse('$baseUrl/trashBook/$bookId'),
            headers: _headers(json: false));
        if (response.statusCode != 200) {
          throw Exception(
              'Failed to trash book via API: ${response.statusCode}');
        }
      } catch (e) {
        print('API error during trashBook: $e');
        await db.update(
          'books',
          {'is_trashed': 1},
          where: 'id = ?',
          whereArgs: [bookId],
        );
      }
    } else {
      await db.update(
        'books',
        {'is_trashed': 1},
        where: 'id = ?',
        whereArgs: [bookId],
      );
    }

    await _cacheBooks();
    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> restoreBook(String bookId) async {
    final db = await _database;
    if (await _isOnline()) {
      try {
        final response = await http.put(
            Uri.parse('$baseUrl/restoreBook/$bookId'),
            headers: _headers(json: false));
        if (response.statusCode != 200) {
          throw Exception(
              'Failed to restore book via API: ${response.statusCode}');
        }
      } catch (e) {
        print('API error during restoreBook: $e');
        await db.update(
          'books',
          {'is_trashed': 0},
          where: 'id = ?',
          whereArgs: [bookId],
        );
      }
    } else {
      await db.update(
        'books',
        {'is_trashed': 0},
        where: 'id = ?',
        whereArgs: [bookId],
      );
    }

    await _cacheBooks();
    if (await _isOnline()) await _syncLocalData();
  }

  Future<List<Book>> fetchBooks({
    String? filter,
    String? sortBy,
    bool trashed = false,
  }) async {
    print(
        '🚀 Starting fetchBooks with filter=$filter, sortBy=$sortBy, trashed=$trashed');

    final cachedData = await sharedPrefs.getValue(cacheKey);
    List<Book>? books;

    if (cachedData != null) {
      print('📦 Found cached data');
      try {
        final List<dynamic> cachedList = jsonDecode(cachedData);
        books = cachedList.map((data) => Book.fromMap(data)).toList();
        books = books.where((book) => book.isTrashed == trashed).toList();
        if (books.isNotEmpty) {
          print('📚 Libros obtenidos desde caché: ${books.length}');
          return books;
        }
      } catch (e) {
        print('⚠️ Error parsing cached data: $e');
      }
    }

    if (await _isOnline()) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/books?trashed=$trashed'),
                headers: _headers(json: false))
            .timeout(apiTimeout);
        print('📡 API response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final List<dynamic> decodedData = jsonDecode(response.body);
          books = decodedData.map((map) => Book.fromMap(map)).toList();

          final db = await _database;
          await db.delete(
            'books',
            where: 'is_trashed = ?',
            whereArgs: [trashed ? 1 : 0],
          );
          for (var book in books) {
            await db.insert(
              'books',
              book.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await _cacheBooks();
          print('📡 Libros obtenidos desde la API: ${books.length}');
          return books;
        } else {
          throw Exception(
              'Failed to fetch books: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('⚠️ Error al obtener libros desde la API: $e');
      }
    }

    print('📂 Falling back to SQLite');
    final db = await _database;
    final List<Map<String, dynamic>> result = await db.query(
      'books',
      where: 'is_trashed = ?',
      whereArgs: [trashed ? 1 : 0],
    );
    books = result.map((map) => Book.fromMap(map)).toList();
    await _cacheBooks();

    print('💾 Libros obtenidos desde SQLite: ${books.length}');
    return books;
  }

  @override
  Future<Book?> getBookById(String bookId) async {
    if (await _isOnline()) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/book/$bookId'),
                headers: _headers(json: false))
            .timeout(apiTimeout);
        if (response.statusCode == 200) {
          final book = Book.fromMap(jsonDecode(response.body));
          final db = await _database;
          await db.insert('books', book.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
          await _cacheBooks();
          return book;
        } else if (response.statusCode == 404) {
          print('⚠️ Book $bookId not found on server');
        }
      } catch (e) {
        print('API error during getBookById: $e');
      }
    }

    final db = await _database;
    final result = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [bookId],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return Book.fromMap(result.first);
    }
    return null;
  }

  @override
  Future<void> updateBookViews(String bookId) async {
    if (await _isOnline()) {
      try {
        final response = await http.put(
            Uri.parse('$baseUrl/updateViews/$bookId'),
            headers: _headers(json: false));
        if (response.statusCode != 200) {
          throw Exception(
              'Failed to update views via API: ${response.statusCode}');
        }
      } catch (e) {
        print('API error during updateBookViews: $e');
        final db = await _database;
        await db.rawUpdate(
            'UPDATE books SET views = views + 1 WHERE id = ?', [bookId]);
      }
    } else {
      final db = await _database;
      await db.rawUpdate(
          'UPDATE books SET views = views + 1 WHERE id = ?', [bookId]);
    }

    await _cacheBooks();
    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> rateBook(String bookId, String userId, double rating) async {
    if (await _isOnline()) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/rateBook'),
          headers: _headers(),
          body: jsonEncode({
            'book_id': bookId,
            'user_id': userId,
            'rating': rating,
          }),
        );
        if (response.statusCode != 200) {
          throw Exception(
              'Failed to rate book via API: ${response.statusCode}');
        }
      } catch (e) {
        print('API error during rateBook: $e');
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

        final ratings = await db.query(
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
      }
    } else {
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

      final ratings = await db.query(
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
    }

    await _cacheBooks();
    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<List<Book>> searchBooks(String query) async {
    if (await _isOnline()) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/searchBooks?query=$query'),
                headers: _headers(json: false))
            .timeout(apiTimeout);
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final books = data.map((map) => Book.fromMap(map)).toList();
          final db = await _database;
          for (var book in books) {
            await db.insert('books', book.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await _cacheBooks();
          return books;
        }
      } catch (e) {
        print('API error during searchBooks: $e');
      }
    }

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
    if (await _isOnline()) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/booksByAuthor/$authorId'),
                headers: _headers(json: false))
            .timeout(apiTimeout);
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final books = data.map((map) => Book.fromMap(map)).toList();
          final db = await _database;
          for (var book in books) {
            await db.insert('books', book.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await _cacheBooks();
          return books;
        }
      } catch (e) {
        print('API error during getBooksByAuthor: $e');
      }
    }

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
    if (await _isOnline()) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/topRatedBooks'),
                headers: _headers(json: false))
            .timeout(apiTimeout);
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final books = data.map((map) => Book.fromMap(map)).toList();
          final db = await _database;
          for (var book in books) {
            await db.insert('books', book.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await _cacheBooks();
          return books;
        }
      } catch (e) {
        print('API error during getTopRatedBooks: $e');
      }
    }

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
    if (await _isOnline()) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/mostViewedBooks'),
                headers: _headers(json: false))
            .timeout(apiTimeout);
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final books = data.map((map) => Book.fromMap(map)).toList();
          final db = await _database;
          for (var book in books) {
            await db.insert('books', book.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await _cacheBooks();
          return books;
        }
      } catch (e) {
        print('API error during getMostViewedBooks: $e');
      }
    }

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
  Future<void> updateBookContent(
      String bookId, Map<String, dynamic> content) async {
    if (await _isOnline()) {
      try {
        final response = await http.put(
          Uri.parse('$baseUrl/updateBookContent/$bookId'),
          headers: _headers(),
          body: jsonEncode({'content': content}),
        );
        if (response.statusCode != 200) {
          throw Exception(
              'Failed to update content via API: ${response.statusCode}');
        }
      } catch (e) {
        print('API error during updateBookContent: $e');
        final db = await _database;
        await db.update(
          'books',
          {'content': jsonEncode(content)},
          where: 'id = ?',
          whereArgs: [bookId],
        );
      }
    } else {
      final db = await _database;
      await db.update(
        'books',
        {'content': jsonEncode(content)},
        where: 'id = ?',
        whereArgs: [bookId],
      );
    }

    await _cacheBooks();
    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> updateBookPublicationDate(
      String bookId, String? publicationDate) async {
    if (await _isOnline()) {
      try {
        final response = await http.put(
          Uri.parse('$baseUrl/updatePublicationDate/$bookId'),
          headers: _headers(),
          body: jsonEncode({'publication_date': publicationDate}),
        );
        if (response.statusCode != 200) {
          throw Exception(
              'Failed to update publication date via API: ${response.statusCode}');
        }
      } catch (e) {
        print('API error during updateBookPublicationDate: $e');
        final db = await _database;
        await db.update(
          'books',
          {'publication_date': publicationDate},
          where: 'id = ?',
          whereArgs: [bookId],
        );
      }
    } else {
      final db = await _database;
      await db.update(
        'books',
        {'publication_date': publicationDate},
        where: 'id = ?',
        whereArgs: [bookId],
      );
    }

    await _cacheBooks();
    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> updateBookDetails(String bookId,
      {String? title,
      String? description,
      List<String>? additionalGenres,
      String? genre,
      String? contentType}) async {
    final values = <String, dynamic>{};
    if (title != null) values['title'] = title;
    if (description != null) values['description'] = description;
    if (additionalGenres != null) {
      values['additional_genres'] = jsonEncode(additionalGenres);
    }
    if (genre != null) values['genre'] = genre;
    if (contentType != null) values['content_type'] = contentType;

    if (values.isNotEmpty) {
      if (await _isOnline()) {
        try {
          final response = await http.put(
            Uri.parse('$baseUrl/updateBookDetails/$bookId'),
            headers: _headers(),
            body: jsonEncode(values),
          );
          if (response.statusCode != 200) {
            throw Exception(
                'Failed to update book details via API: ${response.statusCode}');
          }
        } catch (e) {
          print('API error during updateBookDetails: $e');
          final db = await _database;
          await db
              .update('books', values, where: 'id = ?', whereArgs: [bookId]);
        }
      } else {
        final db = await _database;
        await db.update('books', values, where: 'id = ?', whereArgs: [bookId]);
      }
    }

    await _cacheBooks();
    if (await _isOnline()) await _syncLocalData();
  }

  Future<void> _cacheBooks() async {
    final db = await _database;
    final List<Map<String, dynamic>> result = await db.query('books');
    await sharedPrefs.setValue(cacheKey, jsonEncode(result));
    print('📦 Cached ${result.length} books');
  }

  Future<void> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/books'), headers: _headers(json: false))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        print('✅ Conexión con backend exitosa: ${response.body}');
      } else {
        print(
            '⚠️ Conexión fallida - Código: ${response.statusCode}, Motivo: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('❌ Error al conectar con el backend: $e');
    }
  }
}
