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
  static const String lastSyncKey = 'last_sync_timestamp';
  static String baseUrl = dotenv.env['API_BASE_URL'] ?? '';
  static String apiKey = dotenv.env['API_KEY'] ?? '';
  static final Duration apiTimeout = Duration(
    seconds: int.tryParse(dotenv.env['API_TIMEOUT'] ?? '5') ?? 5,
  );
  static const int cacheValidityMinutes = 30; // Aumentado a 30 minutos

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

  Future<bool> _isCacheValid() async {
    final lastSync = await sharedPrefs.getValue<String>(lastSyncKey);
    if (lastSync == null) return false;
    final lastSyncTime = DateTime.parse(lastSync);
    return DateTime.now().difference(lastSyncTime).inMinutes <
        cacheValidityMinutes;
  }

  Future<void> _syncLocalData() async {
    if (!await _isOnline()) return;

    final db = await _database;
    final localBooks = await db.query('books');
    for (var bookMap in localBooks) {
      final book = Book.fromMap(bookMap);
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/book/${book.id}'),
                headers: _headers(json: false))
            .timeout(apiTimeout);
        if (response.statusCode == 404) {
          await http.post(
            Uri.parse('$baseUrl/addBook'),
            headers: _headers(),
            body: jsonEncode(book.toMap()),
          );
        } else if (response.statusCode == 200) {
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
        }
      } catch (e) {
        print('Sync error for book ${book.id}: $e');
      }
    }
    await sharedPrefs.setValue(lastSyncKey, DateTime.now().toIso8601String());
  }

  @override
  Future<void> addBook(Book book) async {
    final db = await _database;
    final String bookId = book.id.isEmpty ? const Uuid().v4() : book.id;
    final newBook = book.copyWith(id: bookId, content: book.content ?? {});

    if (book.authorId.isEmpty) {
      throw Exception("Error: El libro debe tener un authorId válido.");
    }

    await db.transaction((txn) async {
      final localExists = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM books WHERE id = ?',
            [bookId],
          ))! >
          0;

      if (!localExists) {
        await txn.insert('books', newBook.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      } else {
        print(
            "⚠️ El libro con ID $bookId ya existe localmente. Se omite la inserción.");
        return;
      }
    });

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
          } else if (response.statusCode != 201) {
            throw Exception(
                'Error al agregar el libro: ${response.statusCode} - ${response.body}');
          }
        } else {
          print("⚠️ El libro con ID $bookId ya existe en la API.");
        }
      } catch (e) {
        print("🌐 Error al enviar libro a API. Guardado localmente. Error: $e");
      }
    } else {
      print("📴 Sin conexión. Guardando localmente.");
    }

    await _cacheBooks();
    _scheduleSync();
    print('➕ [Repository] addBook -> ${newBook.toMap()}');
  }

  @override
  Future<void> deleteBook(String bookId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('books', where: 'id = ?', whereArgs: [bookId]);
    });

    if (await _isOnline()) {
      try {
        final response = await http.delete(
          Uri.parse('$baseUrl/deleteBook/$bookId'),
          headers: _headers(json: false),
        );
        if (response.statusCode != 200)
          throw Exception(
              'Failed to delete book from API: ${response.statusCode}');
      } catch (e) {
        print('API error during deleteBook: $e');
      }
    }

    await _cacheBooks();
    _scheduleSync();
    print('🗑️ [Repository] deleteBook($bookId)');
  }

  @override
  Future<void> trashBook(String bookId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update(
        'books',
        {'is_trashed': 1},
        where: 'id = ?',
        whereArgs: [bookId],
      );
    });

    if (await _isOnline()) {
      try {
        final response = await http.put(
          Uri.parse('$baseUrl/trashBook/$bookId'),
          headers: _headers(json: false),
        );
        if (response.statusCode != 200)
          throw Exception(
              'Failed to trash book via API: ${response.statusCode}');
      } catch (e) {
        print('API error during trashBook: $e');
      }
    }

    await _cacheBooks();
    _scheduleSync();
    print('🗑️ [Repository] trashBook($bookId)');
  }

  @override
  Future<void> restoreBook(String bookId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update(
        'books',
        {'is_trashed': 0},
        where: 'id = ?',
        whereArgs: [bookId],
      );
    });

    if (await _isOnline()) {
      try {
        final response = await http.put(
          Uri.parse('$baseUrl/restoreBook/$bookId'),
          headers: _headers(json: false),
        );
        if (response.statusCode != 200)
          throw Exception(
              'Failed to restore book via API: ${response.statusCode}');
      } catch (e) {
        print('API error during restoreBook: $e');
      }
    }

    await _cacheBooks();
    _scheduleSync();
    print('🔄 [Repository] restoreBook($bookId)');
  }

  @override
  Future<List<Book>> fetchBooks({
    String? filter,
    String? sortBy,
    bool trashed = false,
  }) async {
    print(
        '🚀 Fetching books with filter=$filter, sortBy=$sortBy, trashed=$trashed');

    if (await _isCacheValid()) {
      print('📦 Cache válida, intentando cargar desde caché');
      final cachedData = await sharedPrefs.getValue(cacheKey);
      if (cachedData != null) {
        try {
          final List<dynamic> cachedList = jsonDecode(cachedData);
          final books = cachedList.map((data) => Book.fromMap(data)).toList();
          var filteredBooks =
              books.where((book) => book.isTrashed == trashed).toList();

          print('📚 Libros en caché: ${books.length}');
          print('📚 Libros filtrados: ${filteredBooks.length}');

          // Aplicar filtro si se proporciona
          if (filter != null && filter.isNotEmpty) {
            filteredBooks = filteredBooks
                .where((book) =>
                    book.title.toLowerCase().contains(filter.toLowerCase()))
                .toList();
            print('🔍 Libros después de filtro: ${filteredBooks.length}');
          }

          // Aplicar ordenamiento si se proporciona
          if (sortBy != null) {
            switch (sortBy.toLowerCase()) {
              case 'title':
                filteredBooks.sort((a, b) => a.title.compareTo(b.title));
                break;
              case 'rating':
                filteredBooks
                    .sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
                break;
              case 'views':
                filteredBooks
                    .sort((a, b) => (b.views ?? 0).compareTo(a.views ?? 0));
                break;
            }
            print('📊 Libros ordenados por: $sortBy');
          }

          print('✅ Retornando ${filteredBooks.length} libros desde caché');
          _scheduleSync();
          return filteredBooks;
        } catch (e) {
          print('❌ Error parsing cache: $e');
        }
      }
    }

    print('🔄 Cache inválida o no disponible, cargando desde fuente');
    return await _fetchBooksFromSource(trashed, filter: filter, sortBy: sortBy);
  }

  Future<List<Book>> _fetchBooksFromSource(bool trashed,
      {String? filter, String? sortBy}) async {
    print('🌐 Iniciando _fetchBooksFromSource');
    final db = await _database;
    List<Book> books = [];

    if (await _isOnline()) {
      try {
        print('📡 Intentando obtener libros desde API');
        final response = await http
            .get(Uri.parse('$baseUrl/books?trashed=$trashed'),
                headers: _headers(json: false))
            .timeout(apiTimeout);
        print('📡 API response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final List<dynamic> decodedData = jsonDecode(response.body);
          books = decodedData.map((map) => Book.fromMap(map)).toList();
          print('📚 Libros obtenidos de API: ${books.length}');

          await db.transaction((txn) async {
            print('💾 Actualizando base de datos local');
            await txn.delete('books',
                where: 'is_trashed = ?', whereArgs: [trashed ? 1 : 0]);
            for (var book in books) {
              await txn.insert('books', book.toMap(),
                  conflictAlgorithm: ConflictAlgorithm.replace);
            }
          });

          await _cacheBooks();
          await sharedPrefs.setValue(
              lastSyncKey, DateTime.now().toIso8601String());
          print('✅ Sincronización completada');
        }
      } catch (e) {
        print('❌ Error en API: $e');
      }
    } else {
      print('📴 Sin conexión, usando base de datos local');
    }

    // Fallback a SQLite
    String whereClause = 'is_trashed = ?';
    List<dynamic> whereArgs = [trashed ? 1 : 0];

    if (filter != null && filter.isNotEmpty) {
      whereClause += ' AND title LIKE ?';
      whereArgs.add('%$filter%');
    }

    String? orderBy;
    if (sortBy != null) {
      switch (sortBy.toLowerCase()) {
        case 'title':
          orderBy = 'title';
          break;
        case 'rating':
          orderBy = 'rating DESC';
          break;
        case 'views':
          orderBy = 'views DESC';
          break;
      }
    }

    print('💾 Consultando base de datos local');
    final result = await db.query(
      'books',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
    books = result.map((map) => Book.fromMap(map)).toList();
    print('📚 Libros obtenidos de SQLite: ${books.length}');

    await _cacheBooks();
    return books;
  }

  Future<void> _scheduleSync() async {
    if (await _isOnline()) {
      await Future.delayed(const Duration(minutes: 5), () => _syncLocalData());
    }
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
    final result =
        await db.query('books', where: 'id = ?', whereArgs: [bookId], limit: 1);
    if (result.isNotEmpty) {
      return Book.fromMap(result.first);
    }
    return null;
  }

  @override
  Future<void> updateBookViews(String bookId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
          'UPDATE books SET views = views + 1 WHERE id = ?', [bookId]);
    });

    if (await _isOnline()) {
      try {
        final response = await http.put(
          Uri.parse('$baseUrl/updateViews/$bookId'),
          headers: _headers(json: false),
        );
        if (response.statusCode != 200)
          throw Exception(
              'Failed to update views via API: ${response.statusCode}');
      } catch (e) {
        print('API error during updateBookViews: $e');
      }
    }

    await _cacheBooks();
    _scheduleSync();
  }

  @override
  Future<void> rateBook(String bookId, String userId, double rating) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert(
        'book_ratings',
        {
          'id': '$userId-$bookId',
          'user_id': userId,
          'book_id': bookId,
          'rating': rating,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final ratings = await txn.query('book_ratings',
          columns: ['rating'], where: 'book_id = ?', whereArgs: [bookId]);
      if (ratings.isNotEmpty) {
        final avgRating = ratings.fold<double>(
                0, (sum, item) => sum + (item['rating'] as num).toDouble()) /
            ratings.length;
        await txn.update('books', {'rating': avgRating},
            where: 'id = ?', whereArgs: [bookId]);
      }
    });

    if (await _isOnline()) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/rateBook'),
          headers: _headers(),
          body: jsonEncode(
              {'book_id': bookId, 'user_id': userId, 'rating': rating}),
        );
        if (response.statusCode != 200)
          throw Exception(
              'Failed to rate book via API: ${response.statusCode}');
      } catch (e) {
        print('API error during rateBook: $e');
      }
    }

    await _cacheBooks();
    _scheduleSync();
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
          await db.transaction((txn) async {
            for (var book in books) {
              await txn.insert('books', book.toMap(),
                  conflictAlgorithm: ConflictAlgorithm.replace);
            }
          });
          await _cacheBooks();
          return books;
        }
      } catch (e) {
        print('API error during searchBooks: $e');
      }
    }

    final db = await _database;
    final result = await db.query('books',
        where: 'title LIKE ? AND is_trashed = 0', whereArgs: ['%$query%']);
    final books = result.map((map) => Book.fromMap(map)).toList();
    await _cacheBooks();
    return books;
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
          await db.transaction((txn) async {
            for (var book in books) {
              await txn.insert('books', book.toMap(),
                  conflictAlgorithm: ConflictAlgorithm.replace);
            }
          });
          await _cacheBooks();
          return books;
        }
      } catch (e) {
        print('API error during getBooksByAuthor: $e');
      }
    }

    final db = await _database;
    final result = await db.query('books',
        where: 'author_id = ? AND is_trashed = 0', whereArgs: [authorId]);
    final books = result.map((map) => Book.fromMap(map)).toList();
    await _cacheBooks();
    return books;
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
          await db.transaction((txn) async {
            for (var book in books) {
              await txn.insert('books', book.toMap(),
                  conflictAlgorithm: ConflictAlgorithm.replace);
            }
          });
          await _cacheBooks();
          return books;
        }
      } catch (e) {
        print('API error during getTopRatedBooks: $e');
      }
    }

    final db = await _database;
    final result = await db.query('books',
        where: 'is_trashed = 0', orderBy: 'rating DESC', limit: 10);
    final books = result.map((map) => Book.fromMap(map)).toList();
    await _cacheBooks();
    return books;
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
          await db.transaction((txn) async {
            for (var book in books) {
              await txn.insert('books', book.toMap(),
                  conflictAlgorithm: ConflictAlgorithm.replace);
            }
          });
          await _cacheBooks();
          return books;
        }
      } catch (e) {
        print('API error during getMostViewedBooks: $e');
      }
    }

    final db = await _database;
    final result = await db.query('books',
        where: 'is_trashed = 0', orderBy: 'views DESC', limit: 10);
    final books = result.map((map) => Book.fromMap(map)).toList();
    await _cacheBooks();
    return books;
  }

  @override
  Future<void> updateBookContent(
      String bookId, Map<String, dynamic> content) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update('books', {'content': jsonEncode(content)},
          where: 'id = ?', whereArgs: [bookId]);
    });

    if (await _isOnline()) {
      try {
        final response = await http.put(
          Uri.parse('$baseUrl/updateBookContent/$bookId'),
          headers: _headers(),
          body: jsonEncode({'content': content}),
        );
        if (response.statusCode != 200)
          throw Exception(
              'Failed to update content via API: ${response.statusCode}');
      } catch (e) {
        print('API error during updateBookContent: $e');
      }
    }

    await _cacheBooks();
    _scheduleSync();
  }

  @override
  Future<void> updateBookPublicationDate(
      String bookId, String? publicationDate) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update('books', {'publication_date': publicationDate},
          where: 'id = ?', whereArgs: [bookId]);
    });

    if (await _isOnline()) {
      try {
        final response = await http.put(
          Uri.parse('$baseUrl/updatePublicationDate/$bookId'),
          headers: _headers(),
          body: jsonEncode({'publication_date': publicationDate}),
        );
        if (response.statusCode != 200)
          throw Exception(
              'Failed to update publication date via API: ${response.statusCode}');
      } catch (e) {
        print('API error during updateBookPublicationDate: $e');
      }
    }

    await _cacheBooks();
    _scheduleSync();
  }

  @override
  Future<void> updateBookDetails(
    String bookId, {
    String? title,
    String? description,
    List<String>? additionalGenres,
    String? genre,
    String? contentType,
  }) async {
    final values = <String, dynamic>{};
    if (title != null) values['title'] = title;
    if (description != null) values['description'] = description;
    if (additionalGenres != null)
      values['additional_genres'] = jsonEncode(additionalGenres);
    if (genre != null) values['genre'] = genre;
    if (contentType != null) values['content_type'] = contentType;

    if (values.isNotEmpty) {
      final db = await _database;
      await db.transaction((txn) async {
        await txn.update('books', values, where: 'id = ?', whereArgs: [bookId]);
      });

      if (await _isOnline()) {
        try {
          final response = await http.put(
            Uri.parse('$baseUrl/updateBookDetails/$bookId'),
            headers: _headers(),
            body: jsonEncode(values),
          );
          if (response.statusCode != 200)
            throw Exception(
                'Failed to update book details via API: ${response.statusCode}');
        } catch (e) {
          print('API error during updateBookDetails: $e');
        }
      }

      await _cacheBooks();
      _scheduleSync();
      print('✏️ [Repository] updateBookDetails($bookId) -> $values');
    }
  }

  Future<void> _cacheBooks() async {
    print('📦 Iniciando _cacheBooks');
    final db = await _database;
    final result = await db.query('books');
    print('📚 Libros a cachear: ${result.length}');
    await sharedPrefs.setValue(cacheKey, jsonEncode(result));
    print('✅ Cache actualizada');
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
