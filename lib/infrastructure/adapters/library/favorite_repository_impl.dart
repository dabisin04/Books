import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/ports/library/favorite_repository.dart';
import '../../database/database_helper.dart';

class FavoriteRepositoryImpl implements FavoriteRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();
  final Connectivity _connectivity = Connectivity();
  static String primaryApiUrl =
      (dotenv.env['API_BASE_URL'] ?? '').replaceAll('//api', '/api');
  static String altApiUrl =
      (dotenv.env['ALT_API_BASE_URL'] ?? '').replaceAll('//api', '/api');
  static final Duration apiTimeout = Duration(
    seconds: int.tryParse(dotenv.env['API_TIMEOUT'] ?? '5') ?? 5,
  );

  Future<Database> get _db async => await _dbHelper.database;

  Future<bool> _isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Map<String, String> _headers({bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json',
    };
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

  Future<http.Response> _delete(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final futures = [
        http
            .delete(
              Uri.parse('$primaryApiUrl/$endpoint'),
              headers: _headers(),
              body: jsonEncode(body),
            )
            .timeout(apiTimeout),
        http
            .delete(
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
              .delete(
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
      print('❌ Error in DELETE request: $e');
      rethrow;
    }
  }

  bool _isSuccessfulResponse(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  Future<void> _syncLocalData() async {
    if (!await _isOnline()) return;

    final db = await _db;
    final localFavorites = await db.query('favorites');
    for (var favoriteMap in localFavorites) {
      final userId = favoriteMap['user_id'] as String;
      final bookId = favoriteMap['book_id'] as String;

      try {
        final response =
            await _get('isFavorite?user_id=$userId&book_id=$bookId');
        if (_isSuccessfulResponse(response.statusCode)) {
          final isFavorite = jsonDecode(response.body)['is_favorite'] as bool;

          if (!isFavorite) {
            await _post('addFavorite', {
              'user_id': userId,
              'book_id': bookId,
            });
          }
        }
      } catch (e) {
        print('Sync error for favorite $userId-$bookId: $e');
      }
    }

    final userIds = localFavorites.map((f) => f['user_id'] as String).toSet();
    for (var userId in userIds) {
      try {
        final response = await _get('favoriteBookIds/$userId');
        if (_isSuccessfulResponse(response.statusCode)) {
          final serverBookIds = List<String>.from(jsonDecode(response.body));
          final localBookIds = localFavorites
              .where((f) => f['user_id'] == userId)
              .map((f) => f['book_id'] as String)
              .toList();

          for (var bookId in serverBookIds) {
            if (!localBookIds.contains(bookId)) {
              await db.insert(
                'favorites',
                {
                  'id': _uuid.v4(),
                  'user_id': userId,
                  'book_id': bookId,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }

          for (var bookId in localBookIds) {
            if (!serverBookIds.contains(bookId)) {
              await db.delete(
                'favorites',
                where: 'user_id = ? AND book_id = ?',
                whereArgs: [userId, bookId],
              );
            }
          }
        }
      } catch (e) {
        print('Sync error for user $userId: $e');
      }
    }
  }

  @override
  Future<void> addToFavorites({
    required String userId,
    required String bookId,
  }) async {
    final db = await _db;

    if (await _isOnline()) {
      try {
        print('📤 Registrando favorito primero en Flask...');
        final flaskResponse = await http
            .post(
              Uri.parse('$primaryApiUrl/addFavorite'),
              headers: _headers(),
              body: jsonEncode({
                'user_id': userId,
                'book_id': bookId,
              }),
            )
            .timeout(apiTimeout);

        if (![200, 201].contains(flaskResponse.statusCode)) {
          final error = jsonDecode(flaskResponse.body);
          throw Exception(error['error'] ?? 'Error al registrar en Flask');
        }

        final flaskDataRaw = jsonDecode(flaskResponse.body);
        print('✅ Favorito creado en Flask');

        // Serialización segura del objeto de Flask
        final flaskData = flaskDataRaw is Map<String, dynamic>
            ? flaskDataRaw
            : Map<String, dynamic>.from(flaskDataRaw);

        // Filtrar solo los campos esperados para FastAPI
        final fastapiData = {
          'id': flaskData['id'],
          'user_id': flaskData['user_id'],
          'book_id': flaskData['book_id'],
          'from_flask': true,
        };

        print('📤 Enviando a FastAPI: ${jsonEncode(fastapiData)}');

        final fastapiResponse = await http
            .post(
              Uri.parse('$altApiUrl/addFavorite'),
              headers: _headers(),
              body: jsonEncode(fastapiData),
            )
            .timeout(apiTimeout);

        if (fastapiResponse.statusCode != 200) {
          throw Exception(
              'Error al registrar en FastAPI: ${fastapiResponse.statusCode}');
        }

        print('✅ Favorito sincronizado con FastAPI');
      } catch (e) {
        print('❌ Error completo en registro dual: $e');
        throw Exception('Error al registrar el favorito: $e');
      }
    }

    // Guardar en SQLite local
    await db.insert(
      'favorites',
      {
        'id': _uuid.v4(),
        'user_id': userId,
        'book_id': bookId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> removeFromFavorites({
    required String userId,
    required String bookId,
  }) async {
    final db = await _db;

    if (await _isOnline()) {
      try {
        print('📤 Eliminando favorito primero en Flask...');
        final flaskResponse = await http
            .delete(
              Uri.parse('$primaryApiUrl/removeFavorite'),
              headers: _headers(),
              body: jsonEncode({
                'user_id': userId,
                'book_id': bookId,
              }),
            )
            .timeout(apiTimeout);

        if (flaskResponse.statusCode != 200) {
          final error = jsonDecode(flaskResponse.body);
          throw Exception(error['error'] ?? 'Error al eliminar en Flask');
        }

        final flaskData = jsonDecode(flaskResponse.body);
        print('✅ Favorito eliminado en Flask');

        // Ahora eliminar en FastAPI incluyendo `from_flask = true`
        final fastapiData = {
          ...flaskData,
          'from_flask': true,
        };
        print('📤 Enviando a FastAPI: ${jsonEncode(fastapiData)}');

        final fastapiResponse = await http
            .delete(
              Uri.parse('$altApiUrl/removeFavorite'),
              headers: _headers(),
              body: jsonEncode(fastapiData),
            )
            .timeout(apiTimeout);

        if (fastapiResponse.statusCode != 200) {
          throw Exception(
              'Error al eliminar en FastAPI: ${fastapiResponse.statusCode}');
        }

        print('✅ Favorito eliminado en FastAPI');
      } catch (e) {
        print('❌ Error completo en eliminación dual: $e');
        throw Exception('Error al eliminar el favorito: $e');
      }
    }

    await db.delete(
      'favorites',
      where: 'user_id = ? AND book_id = ?',
      whereArgs: [userId, bookId],
    );

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<List<String>> getFavoriteBookIds(String userId) async {
    if (await _isOnline()) {
      try {
        final response = await _get('favoriteBookIds/$userId');
        if (_isSuccessfulResponse(response.statusCode)) {
          final bookIds = List<String>.from(jsonDecode(response.body));
          final db = await _db;
          await db.delete(
            'favorites',
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          for (var bookId in bookIds) {
            await db.insert(
              'favorites',
              {
                'id': _uuid.v4(),
                'user_id': userId,
                'book_id': bookId,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          return bookIds;
        }
      } catch (e) {
        print('⚠️ API error, falling back to local storage: $e');
      }
    }

    final db = await _db;
    final res = await db.query(
      'favorites',
      columns: ['book_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return res.map((row) => row['book_id'] as String).toList();
  }

  @override
  Future<bool> isFavorite({
    required String userId,
    required String bookId,
  }) async {
    if (await _isOnline()) {
      try {
        final response =
            await _get('isFavorite?user_id=$userId&book_id=$bookId');
        if (_isSuccessfulResponse(response.statusCode)) {
          final isFavorite = jsonDecode(response.body)['is_favorite'] as bool;
          final db = await _db;
          if (isFavorite) {
            await db.insert(
              'favorites',
              {
                'id': _uuid.v4(),
                'user_id': userId,
                'book_id': bookId,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } else {
            await db.delete(
              'favorites',
              where: 'user_id = ? AND book_id = ?',
              whereArgs: [userId, bookId],
            );
          }
          return isFavorite;
        }
      } catch (e) {
        print('⚠️ API error, falling back to local storage: $e');
      }
    }

    final db = await _db;
    final res = await db.query(
      'favorites',
      where: 'user_id = ? AND book_id = ?',
      whereArgs: [userId, bookId],
      limit: 1,
    );
    return res.isNotEmpty;
  }
}
