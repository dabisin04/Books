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
  static String primaryApiUrl =
      (dotenv.env['API_BASE_URL'] ?? '').replaceAll('//api', '/api');
  static String altApiUrl =
      (dotenv.env['ALT_API_BASE_URL'] ?? '').replaceAll('//api', '/api');
  static String apiKey = dotenv.env['API_KEY'] ?? '';
  static final Duration apiTimeout = Duration(
    seconds: int.tryParse(dotenv.env['API_TIMEOUT'] ?? '5') ?? 5,
  );
  static const int cacheValidityMinutes = 30;

  BookRepositoryImpl(this.sharedPrefs);

  Map<String, String> _headers({bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json',
      'X-API-KEY': apiKey,
    };
  }

  bool _isSuccessfulResponse(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  Future<http.Response> _get(String endpoint) async {
    try {
      final futures = [
        http
            .get(
              Uri.parse('$primaryApiUrl/$endpoint'),
              headers: _headers(json: false),
            )
            .timeout(apiTimeout),
        http
            .get(
              Uri.parse('$altApiUrl/$endpoint'),
              headers: _headers(json: false),
            )
            .timeout(apiTimeout),
      ];

      final responses = await Future.wait(futures);
      final primaryResponse = responses[0];
      final altResponse = responses[1];

      if (_isSuccessfulResponse(primaryResponse.statusCode)) {
        return primaryResponse;
      }

      if (_isSuccessfulResponse(altResponse.statusCode)) {
        print('⚠️ Primary API failed, using alternative API response');
        return altResponse;
      }

      throw Exception('Both APIs failed: ${primaryResponse.statusCode}');
    } catch (e) {
      print('❌ Error in GET request: $e');
      rethrow;
    }
  }

  Future<http.Response> _post(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final futures = [
        http
            .post(
              Uri.parse('$primaryApiUrl/$endpoint'),
              headers: _headers(),
              body: jsonEncode(body),
            )
            .timeout(apiTimeout),
        http
            .post(
              Uri.parse('$altApiUrl/$endpoint'),
              headers: _headers(),
              body: jsonEncode(body),
            )
            .timeout(apiTimeout),
      ];

      final responses = await Future.wait(futures);
      final primaryResponse = responses[0];
      final altResponse = responses[1];

      if (_isSuccessfulResponse(primaryResponse.statusCode) &&
          _isSuccessfulResponse(altResponse.statusCode)) {
        return primaryResponse;
      }

      if (_isSuccessfulResponse(altResponse.statusCode)) {
        print('⚠️ Primary API failed, syncing with alternative API');
        try {
          await http
              .post(
                Uri.parse('$primaryApiUrl/$endpoint'),
                headers: _headers(),
                body: jsonEncode(body),
              )
              .timeout(apiTimeout);
        } catch (syncError) {
          print('⚠️ Failed to sync with primary API: $syncError');
        }
        return altResponse;
      }

      throw Exception('Both APIs failed: ${primaryResponse.statusCode}');
    } catch (e) {
      print('❌ Error in POST request: $e');
      rethrow;
    }
  }

  Future<http.Response> _put(String endpoint, Map<String, dynamic> body) async {
    try {
      final futures = [
        http
            .put(
              Uri.parse('$primaryApiUrl/$endpoint'),
              headers: _headers(),
              body: jsonEncode(body),
            )
            .timeout(apiTimeout),
        http
            .put(
              Uri.parse('$altApiUrl/$endpoint'),
              headers: _headers(),
              body: jsonEncode(body),
            )
            .timeout(apiTimeout),
      ];

      final responses = await Future.wait(futures);
      final primaryResponse = responses[0];
      final altResponse = responses[1];

      if (_isSuccessfulResponse(primaryResponse.statusCode) &&
          _isSuccessfulResponse(altResponse.statusCode)) {
        return primaryResponse;
      }

      if (_isSuccessfulResponse(altResponse.statusCode)) {
        print('⚠️ Primary API failed, syncing with alternative API');
        try {
          await http
              .put(
                Uri.parse('$primaryApiUrl/$endpoint'),
                headers: _headers(),
                body: jsonEncode(body),
              )
              .timeout(apiTimeout);
        } catch (syncError) {
          print('⚠️ Failed to sync with primary API: $syncError');
        }
        return altResponse;
      }

      throw Exception('Both APIs failed: ${primaryResponse.statusCode}');
    } catch (e) {
      print('❌ Error in PUT request: $e');
      rethrow;
    }
  }

  Future<http.Response> _delete(String endpoint) async {
    try {
      final futures = [
        http
            .delete(
              Uri.parse('$primaryApiUrl/$endpoint'),
              headers: _headers(),
            )
            .timeout(apiTimeout),
        http
            .delete(
              Uri.parse('$altApiUrl/$endpoint'),
              headers: _headers(),
            )
            .timeout(apiTimeout),
      ];

      final responses = await Future.wait(futures);
      final primaryResponse = responses[0];
      final altResponse = responses[1];

      if (_isSuccessfulResponse(primaryResponse.statusCode) &&
          _isSuccessfulResponse(altResponse.statusCode)) {
        return primaryResponse;
      }

      if (_isSuccessfulResponse(altResponse.statusCode)) {
        print('⚠️ Primary API failed, syncing with alternative API');
        try {
          await http
              .delete(
                Uri.parse('$primaryApiUrl/$endpoint'),
                headers: _headers(),
              )
              .timeout(apiTimeout);
        } catch (syncError) {
          print('⚠️ Failed to sync with primary API: $syncError');
        }
        return altResponse;
      }

      throw Exception('Both APIs failed: ${primaryResponse.statusCode}');
    } catch (e) {
      print('❌ Error in DELETE request: $e');
      rethrow;
    }
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
        final response = await _get('book/${book.id}');
        if (response.statusCode == 404) {
          await _post('addBook', book.toMap());
        } else if (_isSuccessfulResponse(response.statusCode)) {
          await _put('updateBookDetails/${book.id}', {
            'title': book.title,
            'description': book.description,
            'additional_genres':
                book.additionalGenres.isNotEmpty ? book.additionalGenres : null,
            'genre': book.genre,
            'content_type': book.contentType,
          });
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
        print('📤 Registrando libro primero en Flask...');
        final flaskResponse = await http
            .post(
              Uri.parse('$primaryApiUrl/addBook'),
              headers: _headers(),
              body: jsonEncode(newBook.toMap()),
            )
            .timeout(apiTimeout);

        if (flaskResponse.statusCode != 201) {
          final error = jsonDecode(flaskResponse.body);
          throw Exception(error['error'] ?? 'Error al registrar en Flask');
        }

        final flaskData = jsonDecode(flaskResponse.body);
        print('✅ Libro creado en Flask con ID: ${flaskData["id"]}');

        // Ahora registrar en FastAPI incluyendo `from_flask = true`
        final fastapiData = {
          ...flaskData,
          'from_flask': true,
        };

        // 🔧 Correcciones necesarias para FastAPI
        final additionalGenres = fastapiData['additional_genres'];
        if (additionalGenres is String) {
          try {
            fastapiData['additional_genres'] = jsonDecode(additionalGenres);
          } catch (_) {
            fastapiData['additional_genres'] = [];
          }
        }

        final content = fastapiData['content'];
        if (content is String) {
          try {
            fastapiData['content'] = jsonDecode(content);
          } catch (_) {
            fastapiData['content'] = {};
          }
        }

        if (fastapiData['publication_date'] == "" ||
            fastapiData['publication_date'] == "null") {
          fastapiData['publication_date'] = null;
        }

        print('📤 Enviando a FastAPI desde Flask: ${jsonEncode(fastapiData)}');

        final fastapiResponse = await http
            .post(
              Uri.parse('$altApiUrl/addBook'),
              headers: _headers(),
              body: jsonEncode(fastapiData),
            )
            .timeout(apiTimeout);

        if (fastapiResponse.statusCode != 200) {
          throw Exception(
              'Error al registrar en FastAPI: ${fastapiResponse.statusCode}');
        }

        final bookToInsert = Book.fromMap(flaskData);
        await db.insert('books', bookToInsert.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        print('💾 Libro guardado en DB local con ID: ${bookToInsert.id}');
      } catch (e) {
        print('❌ Error completo en registro dual: $e');
        throw Exception('Error al registrar el libro: $e');
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
        await _delete('deleteBook/$bookId');
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
        await _put('trashBook/$bookId', {});
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
        await _put('restoreBook/$bookId', {});
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

          if (filter != null && filter.isNotEmpty) {
            filteredBooks = filteredBooks
                .where((book) =>
                    book.title.toLowerCase().contains(filter.toLowerCase()))
                .toList();
            print('🔍 Libros después de filtro: ${filteredBooks.length}');
          }

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
        final response = await _get('books?trashed=$trashed');
        print('📡 API response status: ${response.statusCode}');

        if (_isSuccessfulResponse(response.statusCode)) {
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
        final response = await _get('book/$bookId');
        if (_isSuccessfulResponse(response.statusCode)) {
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
        await _put('updateViews/$bookId', {});
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
        await _post('rateBook', {
          'book_id': bookId,
          'user_id': userId,
          'rating': rating,
        });
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
        final response = await _get('searchBooks?query=$query');
        if (_isSuccessfulResponse(response.statusCode)) {
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
        final response = await _get('booksByAuthor/$authorId');
        if (_isSuccessfulResponse(response.statusCode)) {
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
        final response = await _get('topRatedBooks');
        if (_isSuccessfulResponse(response.statusCode)) {
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
        final response = await _get('mostViewedBooks');
        if (_isSuccessfulResponse(response.statusCode)) {
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
        await _put('updateBookContent/$bookId', {'content': content});
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
        await _put('updatePublicationDate/$bookId', {
          'publication_date': publicationDate,
        });
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
    // 🔹 Payload que se envía a SQLite y también se usa en API
    final Map<String, dynamic> values = {};

    // 🔹 Payload que se enviará a FastAPI
    final Map<String, dynamic> apiPayload = {};

    if (title != null) {
      values['title'] = title;
      apiPayload['title'] = title;
    }

    if (description != null) {
      values['description'] = description;
      apiPayload['description'] = description;
    }

    if (additionalGenres != null) {
      values['additional_genres'] =
          jsonEncode(additionalGenres); // SQLite solo acepta String
      apiPayload['additional_genres'] =
          additionalGenres; // FastAPI espera List<String>
    }

    if (genre != null) {
      values['genre'] = genre;
      apiPayload['genre'] = genre;
    }

    if (contentType != null) {
      values['content_type'] = contentType;
      apiPayload['content_type'] = contentType;
    }

    // 🔎 Logs útiles
    print('📦 Payload para SQLite:');
    values.forEach((k, v) => print('  ├── $k: $v (${v.runtimeType})'));

    print('📤 Payload a enviar a FastAPI:');
    apiPayload.forEach((k, v) => print('  ├── $k: $v (${v.runtimeType})'));

    if (values.isNotEmpty) {
      final db = await _database;

      await db.transaction((txn) async {
        await txn.update('books', values, where: 'id = ?', whereArgs: [bookId]);
      });

      if (await _isOnline()) {
        try {
          final encoded = jsonEncode(apiPayload);
          print('📡 Enviando PUT a /updateBookDetails/$bookId: $encoded');

          await _put('updateBookDetails/$bookId', apiPayload);
        } catch (e) {
          print('❌ API error during updateBookDetails: $e');
        }
      }

      await _cacheBooks();
      _scheduleSync();
      print('✅ [Repository] updateBookDetails($bookId) -> $apiPayload');
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
      final response = await _get('books');
      if (_isSuccessfulResponse(response.statusCode)) {
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
