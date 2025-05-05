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
  static final Duration apiTimeout = Duration(
    seconds: int.tryParse(dotenv.env['API_TIMEOUT'] ?? '5') ?? 5,
  );

  BookRepositoryImpl(this.sharedPrefs);

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
        final response = await http.get(Uri.parse('$baseUrl/book/${book.id}'));
        if (response.statusCode == 404) {
          // Add new book to server
          await http.post(
            Uri.parse('$baseUrl/addBook'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(book.toMap()),
          );
        } else if (response.statusCode == 200) {
          // Update existing book
          await http.put(
            Uri.parse('$baseUrl/updateBookDetails/${book.id}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(book.toMap()),
          );
        }
      } catch (e) {
        // Log error, continue with next book
        print('Sync error for book ${book.id}: $e');
      }
    }
  }

  @override
  Future<void> addBook(Book book) async {
    final db = await _database;
    final String bookId = book.id.isEmpty ? const Uuid().v4() : book.id;
    if (book.authorId.isEmpty) {
      throw Exception("Error: El libro debe tener un authorId válido.");
    }

    final newBook = book.copyWith(
      id: bookId,
      views: book.views,
      content: book.content ?? {},
    );

    if (await _isOnline()) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/addBook'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(newBook.toMap()),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to add book to API');
        }
      } catch (e) {
        // Fallback to SQLite
        await db.insert(
          'books',
          newBook.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } else {
      await db.insert(
        'books',
        newBook.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await _cacheBooks();
    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> deleteBook(String bookId) async {
    final db = await _database;
    if (await _isOnline()) {
      try {
        final response =
            await http.delete(Uri.parse('$baseUrl/deleteBook/$bookId'));
        if (response.statusCode != 200) {
          throw Exception('Failed to delete book from API');
        }
      } catch (e) {
        // Fallback to SQLite
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
        final response =
            await http.put(Uri.parse('$baseUrl/trashBook/$bookId'));
        if (response.statusCode != 200) {
          throw Exception('Failed to trash book via API');
        }
      } catch (e) {
        // Fallback to SQLite
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
        final response =
            await http.put(Uri.parse('$baseUrl/restoreBook/$bookId'));
        if (response.statusCode != 200) {
          throw Exception('Failed to restore book via API');
        }
      } catch (e) {
        // Fallback to SQLite
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
      print('📦 Found cached data: $cachedData');
      try {
        final List<dynamic> cachedList = jsonDecode(cachedData);
        print(
            '🔍 Decoded cached data type: ${cachedList.runtimeType}, length: ${cachedList.length}');
        books = cachedList.map((data) {
          print('🔍 Parsing cached book: $data');
          return Book.fromMap(data);
        }).toList();
        books = books.where((book) => book.isTrashed == trashed).toList();
        if (books.isNotEmpty) {
          print('📚 Libros obtenidos desde caché: ${books.length}');
          return books;
        } else {
          print('📚 No books found in cache matching trashed=$trashed');
        }
      } catch (e, stackTrace) {
        print('⚠️ Error parsing cached data: $e');
        print('📜 Stack trace: $stackTrace');
      }
    } else {
      print('📦 No cached data found for key: $cacheKey');
    }

    if (await _isOnline()) {
      try {
        print('🌐 Making API request to $baseUrl/books?trashed=$trashed');
        final response =
            await http.get(Uri.parse('$baseUrl/books?trashed=$trashed'));
        print('📡 API response status: ${response.statusCode}');
        print('📡 Raw API response: ${response.body}');

        if (response.statusCode == 200) {
          dynamic decodedData = jsonDecode(response.body);
          print('🔍 Decoded API data type: ${decodedData.runtimeType}');

          // Handle stringified JSON
          if (decodedData is String) {
            print('🔍 API response is String, decoding again...');
            decodedData = jsonDecode(decodedData);
            print('🔍 Re-decoded API data type: ${decodedData.runtimeType}');
          }

          // Ensure decodedData is a List
          if (decodedData is! List) {
            print('⚠️ Expected a List, but got: ${decodedData.runtimeType}');
            throw Exception('Invalid API response format: Expected a List');
          }

          print('🔍 API response contains ${decodedData.length} items');
          books = decodedData.map((map) {
            print('🔍 Parsing API book: $map');
            return Book.fromMap(map);
          }).toList();

          final db = await _database;
          print('🗄️ Clearing SQLite books with is_trashed=${trashed ? 1 : 0}');
          await db.delete(
            'books',
            where: 'is_trashed = ?',
            whereArgs: [trashed ? 1 : 0],
          );
          for (var book in books) {
            print('🗄️ Inserting book ${book.id} into SQLite');
            await db.insert(
              'books',
              book.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          print('📦 Caching books...');
          await _cacheBooks();
          print('📡 Libros obtenidos desde la API: ${books.length}');
          return books;
        } else {
          print('⚠️ API returned status code: ${response.statusCode}');
          throw Exception('Failed to fetch books: ${response.statusCode}');
        }
      } catch (e, stackTrace) {
        print('⚠️ Error al obtener libros desde la API: $e');
        print('📜 Stack trace: $stackTrace');
      }
    } else {
      print('🌐 Device is offline, skipping API call');
    }

    print('📂 Falling back to SQLite');
    final db = await _database;
    print('🗄️ Querying SQLite books with is_trashed=${trashed ? 1 : 0}');
    final List<Map<String, dynamic>> result = await db.query(
      'books',
      where: 'is_trashed = ?',
      whereArgs: [trashed ? 1 : 0],
    );
    print('🗄️ SQLite query returned ${result.length} rows');
    books = result.map((map) {
      print('🔍 Parsing SQLite book: $map');
      return Book.fromMap(map);
    }).toList();
    print('📦 Caching books from SQLite...');
    await _cacheBooks();

    print('💾 Libros obtenidos desde SQLite: ${books.length}');
    return books;
  }

  @override
  Future<Book?> getBookById(String bookId) async {
    if (await _isOnline()) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/book/$bookId'));
        if (response.statusCode == 200) {
          final book = Book.fromMap(jsonDecode(response.body));
          // Update local SQLite
          final db = await _database;
          await db.insert('books', book.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
          await _cacheBooks();
          return book;
        }
      } catch (e) {
        // Fallback to SQLite
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
        final response =
            await http.put(Uri.parse('$baseUrl/updateViews/$bookId'));
        if (response.statusCode != 200) {
          throw Exception('Failed to update views via API');
        }
      } catch (e) {
        // Fallback to SQLite
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
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'book_id': bookId,
            'user_id': userId,
            'rating': rating,
          }),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to rate book via API');
        }
      } catch (e) {
        // Fallback to SQLite
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
        final response =
            await http.get(Uri.parse('$baseUrl/searchBooks?query=$query'));
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final books = data.map((map) => Book.fromMap(map)).toList();
          // Update local SQLite
          final db = await _database;
          for (var book in books) {
            await db.insert('books', book.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await _cacheBooks();
          return books;
        }
      } catch (e) {
        // Fallback to SQLite
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
        final response =
            await http.get(Uri.parse('$baseUrl/booksByAuthor/$authorId'));
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final books = data.map((map) => Book.fromMap(map)).toList();
          // Update local SQLite
          final db = await _database;
          for (var book in books) {
            await db.insert('books', book.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await _cacheBooks();
          return books;
        }
      } catch (e) {
        // Fallback to SQLite
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
        final response = await http.get(Uri.parse('$baseUrl/topRatedBooks'));
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final books = data.map((map) => Book.fromMap(map)).toList();
          // Update local SQLite
          final db = await _database;
          for (var book in books) {
            await db.insert('books', book.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await _cacheBooks();
          return books;
        }
      } catch (e) {
        // Fallback to SQLite
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
        final response = await http.get(Uri.parse('$baseUrl/mostViewedBooks'));
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final books = data.map((map) => Book.fromMap(map)).toList();
          // Update local SQLite
          final db = await _database;
          for (var book in books) {
            await db.insert('books', book.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await _cacheBooks();
          return books;
        }
      } catch (e) {
        // Fallback to SQLite
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
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'content': content}),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to update content via API');
        }
      } catch (e) {
        // Fallback to SQLite
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
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'publication_date': publicationDate}),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to update publication date via API');
        }
      } catch (e) {
        // Fallback to SQLite
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
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(values),
          );
          if (response.statusCode != 200) {
            throw Exception('Failed to update book details via API');
          }
        } catch (e) {
          // Fallback to SQLite
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
  }
}
