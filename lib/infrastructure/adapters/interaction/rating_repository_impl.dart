import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/ports/interaction/rating_repository.dart';
import '../../../domain/entities/interaction/book_rating.dart';
import '../../database/database_helper.dart';
import '../../utils/shared_prefs_helper.dart';

class BookRatingRepositoryImpl implements BookRatingRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final SharedPrefsService sharedPrefs;
  final Connectivity _connectivity = Connectivity();
  final _uuid = const Uuid();
  static const String cacheKey = 'cached_ratings';
  static const String lastSyncKey = 'last_sync_ratings_timestamp';
  static const int cacheValidityMinutes = 5;
  static String primaryApiUrl =
      (dotenv.env['API_BASE_URL'] ?? '').replaceAll('//api', '/api');
  static String altApiUrl =
      (dotenv.env['ALT_API_BASE_URL'] ?? '').replaceAll('//api', '/api');
  static String apiKey = dotenv.env['API_KEY'] ?? '';
  static final Duration apiTimeout = Duration(
    seconds: int.tryParse(dotenv.env['API_TIMEOUT'] ?? '5') ?? 5,
  );

  BookRatingRepositoryImpl(this.sharedPrefs);

  Future<Database> get _db async => await _dbHelper.database;

  Map<String, String> _headers({bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-API-KEY': apiKey,
    };
  }

  bool _isSuccessfulResponse(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  Future<http.Response> _get(String endpoint) async {
    try {
      print('📤 [GET] Enviando a Flask: $endpoint');
      print('📦 Headers: ${_headers(json: false)}');

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

      print('📥 Respuesta Flask: ${primaryResponse.statusCode}');
      print('📦 Cuerpo Flask: ${primaryResponse.body}');
      print('📥 Respuesta FastAPI: ${altResponse.statusCode}');
      print('📦 Cuerpo FastAPI: ${altResponse.body}');

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
      print('📤 [POST] Enviando a Flask: $endpoint');
      print('📦 Datos a Flask: ${jsonEncode(body)}');
      print('📦 Headers: ${_headers()}');

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

      print('📥 Respuesta Flask: ${primaryResponse.statusCode}');
      print('📦 Cuerpo Flask: ${primaryResponse.body}');
      print('📥 Respuesta FastAPI: ${altResponse.statusCode}');
      print('📦 Cuerpo FastAPI: ${altResponse.body}');

      if (_isSuccessfulResponse(primaryResponse.statusCode) &&
          _isSuccessfulResponse(altResponse.statusCode)) {
        return primaryResponse;
      }

      if (_isSuccessfulResponse(altResponse.statusCode)) {
        print('⚠️ Primary API failed, syncing with alternative API');
        try {
          print('🔄 Intentando sincronizar con Flask...');
          final syncResponse = await http
              .post(
                Uri.parse('$primaryApiUrl/$endpoint'),
                headers: _headers(),
                body: jsonEncode(body),
              )
              .timeout(apiTimeout);
          print(
              '📥 Respuesta sincronización Flask: ${syncResponse.statusCode}');
          print('📦 Cuerpo sincronización Flask: ${syncResponse.body}');
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

  Future<http.Response> _delete(String endpointWithParams) async {
    try {
      final uriPrimary = Uri.parse('$primaryApiUrl/$endpointWithParams');
      final uriAlt = Uri.parse('$altApiUrl/$endpointWithParams');

      final futures = [
        http.delete(uriPrimary, headers: _headers()),
        http.delete(uriAlt, headers: _headers()),
      ];

      final responses = await Future.wait(futures);
      final primaryResponse = responses[0];
      final altResponse = responses[1];

      if (_isSuccessfulResponse(primaryResponse.statusCode) &&
          _isSuccessfulResponse(altResponse.statusCode)) {
        return primaryResponse;
      }

      if (_isSuccessfulResponse(altResponse.statusCode)) {
        print('⚠️ Primary API failed, using alternative API');
        // Intentar sincronizar con la primaria después
        try {
          await http.delete(uriPrimary, headers: _headers());
        } catch (syncError) {
          print('⚠️ Falló sincronización con primaria: $syncError');
        }
        return altResponse;
      }

      throw Exception('Both APIs failed: ${primaryResponse.statusCode}');
    } catch (e) {
      print('❌ Error in DELETE request: $e');
      rethrow;
    }
  }

  Future<http.Response> _deleteWithBody(
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
              Uri.parse(
                  '$altApiUrl/$endpoint?user_id=${body['user_id']}&book_id=${body['book_id']}'),
              headers: _headers(json: false),
            )
            .timeout(apiTimeout),
      ];

      final responses = await Future.wait(futures);
      final primary = responses[0];
      final alt = responses[1];

      if (_isSuccessfulResponse(primary.statusCode)) return primary;
      if (_isSuccessfulResponse(alt.statusCode)) return alt;

      throw Exception('Both APIs failed: ${primary.statusCode}');
    } catch (e) {
      print('❌ Error in DELETE request: $e');
      rethrow;
    }
  }

  Future<bool> _isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    final isConnected = connectivityResult != ConnectivityResult.none;
    print('[📡] Conectividad: $connectivityResult (en línea: $isConnected)');
    return isConnected;
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

    final db = await _db;
    final localRatings = await db.query(
      'book_ratings',
      where: 'needs_sync = 1',
    );

    print('[🔁] Calificaciones a sincronizar: ${localRatings.length}');

    for (var ratingMap in localRatings) {
      final userId = ratingMap['user_id'] as String;
      final bookId = ratingMap['book_id'] as String;
      final rating = (ratingMap['rating'] as num).toDouble();
      final timestamp = ratingMap['timestamp'] as String;

      print('[🟡] Sincronizando $userId → $bookId @ $rating');
      await _syncWithApi(userId, bookId, rating, timestamp);
    }

    await sharedPrefs.setValue(lastSyncKey, DateTime.now().toIso8601String());
  }

  Future<void> _syncWithApi(
    String userId,
    String bookId,
    double rating,
    String timestamp,
  ) async {
    try {
      final response = await _post('rateBook', {
        'user_id': userId,
        'book_id': bookId,
        'rating': rating,
        'timestamp': timestamp,
      });

      if (_isSuccessfulResponse(response.statusCode)) {
        final db = await _db;
        await db.update(
          'book_ratings',
          {'needs_sync': 0},
          where: 'user_id = ? AND book_id = ?',
          whereArgs: [userId, bookId],
        );
        print('[✅] Calificación sincronizada con éxito');
      } else {
        print('[❌] Error API: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[❌] Excepción al sincronizar: $e');
    }
  }

  Future<void> _cacheRatings() async {
    final db = await _db;
    final result = await db.query('book_ratings');
    await sharedPrefs.setValue(cacheKey, jsonEncode(result));
    print('[📦] Cached ${result.length} ratings');
  }

  Future<void> _scheduleSync() async {
    if (await _isOnline()) {
      await Future.delayed(const Duration(seconds: 5), () => _syncLocalData());
    }
  }

  @override
  Future<void> upsertRating({
    required String userId,
    required String bookId,
    required double rating,
    DateTime? timestamp,
  }) async {
    print('[📝] Insertando/actualizando rating...');
    final db = await _db;
    final timestampStr = (timestamp ?? DateTime.now()).toIso8601String();

    await db.transaction((txn) async {
      await txn.delete(
        'book_ratings',
        where: 'user_id = ? AND book_id = ?',
        whereArgs: [userId, bookId],
      );

      await txn.insert(
        'book_ratings',
        {
          'id': _uuid.v4(),
          'user_id': userId,
          'book_id': bookId,
          'rating': rating,
          'timestamp': timestampStr,
          'needs_sync': await _isOnline() ? 0 : 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final res = await txn.rawQuery(
        'SELECT AVG(rating) AS avg, COUNT(*) AS cnt FROM book_ratings WHERE book_id = ?',
        [bookId],
      );
      final avg = (res.first['avg'] as num?)?.toDouble() ?? 0.0;
      final cnt = (res.first['cnt'] as num?)?.toInt() ?? 0;

      await txn.update(
        'books',
        {'rating': avg, 'ratings_count': cnt},
        where: 'id = ?',
        whereArgs: [bookId],
      );

      print('[📊] Promedio actualizado: $avg ($cnt votos)');
    });

    await _cacheRatings();
    if (await _isOnline()) {
      try {
        print('📤 Registrando rating primero en Flask...');
        final flaskResponse = await http
            .post(
              Uri.parse('$primaryApiUrl/rateBook'),
              headers: _headers(),
              body: jsonEncode({
                'user_id': userId,
                'book_id': bookId,
                'rating': rating,
                'timestamp': timestampStr,
              }),
            )
            .timeout(apiTimeout);

        if (flaskResponse.statusCode != 201) {
          final error = jsonDecode(flaskResponse.body);
          throw Exception(error['error'] ?? 'Error al registrar en Flask');
        }

        final flaskData = jsonDecode(flaskResponse.body);
        print('✅ Rating creado en Flask');

        // Ahora registrar en FastAPI incluyendo `from_flask = true`
        final fastapiResponse = await http
            .post(
              Uri.parse('$altApiUrl/rateBook'),
              headers: _headers(),
              body: jsonEncode({
                ...flaskData,
                'from_flask': true,
              }),
            )
            .timeout(apiTimeout);

        if (fastapiResponse.statusCode != 200) {
          throw Exception(
              'Error al registrar en FastAPI: ${fastapiResponse.statusCode}');
        }

        print('✅ Rating sincronizado con FastAPI');
      } catch (e) {
        print('❌ Error completo en registro dual: $e');
        throw Exception('Error al registrar el rating: $e');
      }
    } else {
      _scheduleSync();
    }
  }

  @override
  Future<double?> fetchUserRating({
    required String userId,
    required String bookId,
  }) async {
    if (await _isCacheValid()) {
      final cachedData = await sharedPrefs.getValue(cacheKey);
      if (cachedData != null) {
        try {
          final List<dynamic> cachedList = jsonDecode(cachedData);
          final rating = cachedList.firstWhere(
            (item) => item['user_id'] == userId && item['book_id'] == bookId,
            orElse: () => null,
          )?['rating'] as num?;
          if (rating != null) {
            print('[📦] Rating obtenido desde caché: $rating');
            _scheduleSync();
            return rating.toDouble();
          }
        } catch (e) {
          print('[⚠️] Error parsing cache: $e');
        }
      }
    }

    if (await _isOnline()) {
      try {
        final response =
            await _get('getUserRating?user_id=$userId&book_id=$bookId');

        if (_isSuccessfulResponse(response.statusCode)) {
          final data = jsonDecode(response.body);
          final rating = data['rating'] as num?;
          if (rating != null) {
            final db = await _db;
            await db.transaction((txn) async {
              await txn.insert(
                'book_ratings',
                {
                  'id': _uuid.v4(),
                  'user_id': userId,
                  'book_id': bookId,
                  'rating': rating,
                  'timestamp': DateTime.now().toIso8601String(),
                  'needs_sync': 0,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            });
            await _cacheRatings();
            await sharedPrefs.setValue(
                lastSyncKey, DateTime.now().toIso8601String());
            return rating.toDouble();
          }
        }
      } catch (e) {
        print('[⚠️] Error al obtener rating usuario: $e');
      }
    }

    final db = await _db;
    final res = await db.query(
      'book_ratings',
      columns: ['rating'],
      where: 'user_id = ? AND book_id = ?',
      whereArgs: [userId, bookId],
      limit: 1,
    );
    final rating =
        res.isEmpty ? null : (res.first['rating'] as num?)?.toDouble();
    print('[💾] Rating obtenido desde SQLite: $rating');
    return rating;
  }

  @override
  Future<({double average, int count})> fetchGlobalAverage(
      String bookId) async {
    if (await _isCacheValid()) {
      final cachedData = await sharedPrefs.getValue(cacheKey);
      if (cachedData != null) {
        try {
          final List<dynamic> cachedList = jsonDecode(cachedData);
          final ratings = cachedList
              .where((item) => item['book_id'] == bookId)
              .map((item) => (item['rating'] as num).toDouble())
              .toList();
          if (ratings.isNotEmpty) {
            final average = ratings.reduce((a, b) => a + b) / ratings.length;
            print(
                '[📦] Promedio global desde caché: $average (${ratings.length} votos)');
            _scheduleSync();
            return (average: average, count: ratings.length);
          }
        } catch (e) {
          print('[⚠️] Error parsing cache: $e');
        }
      }
    }

    if (await _isOnline()) {
      try {
        final response = await _get('getGlobalAverage/$bookId');

        if (_isSuccessfulResponse(response.statusCode)) {
          final data = jsonDecode(response.body);
          final average = (data['average'] as num).toDouble();
          final count = (data['count'] as num).toInt();
          final db = await _db;
          await db.transaction((txn) async {
            await txn.update(
              'books',
              {'rating': average, 'ratings_count': count},
              where: 'id = ?',
              whereArgs: [bookId],
            );
          });
          await _cacheRatings();
          await sharedPrefs.setValue(
              lastSyncKey, DateTime.now().toIso8601String());
          return (average: average, count: count);
        }
      } catch (e) {
        print('[⚠️] Error al obtener promedio global: $e');
      }
    }

    final db = await _db;
    final res = await db.rawQuery(
      'SELECT AVG(rating) AS avg, COUNT(*) AS cnt FROM book_ratings WHERE book_id = ?',
      [bookId],
    );
    final average = (res.first['avg'] as num?)?.toDouble() ?? 0.0;
    final count = (res.first['cnt'] as num?)?.toInt() ?? 0;
    print('[💾] Promedio global desde SQLite: $average ($count votos)');
    return (average: average, count: count);
  }

  @override
  Future<Map<int, int>> fetchDistribution(String bookId) async {
    if (await _isCacheValid()) {
      final cachedData = await sharedPrefs.getValue(cacheKey);
      if (cachedData != null) {
        try {
          final List<dynamic> cachedList = jsonDecode(cachedData);
          final ratings = cachedList.where((item) => item['book_id'] == bookId);
          final Map<int, int> dist = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
          for (var item in ratings) {
            final bucket = (item['rating'] as num).round();
            if (dist.containsKey(bucket)) {
              dist[bucket] = dist[bucket]! + 1;
            }
          }
          print('[📦] Distribución desde caché: $dist');
          _scheduleSync();
          return dist;
        } catch (e) {
          print('[⚠️] Error parsing cache: $e');
        }
      }
    }

    if (await _isOnline()) {
      try {
        final response = await _get('getRatingDistribution/$bookId');

        if (_isSuccessfulResponse(response.statusCode)) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final dist = {
            for (var i = 1; i <= 5; i++) i: (data[i.toString()] as num).toInt(),
          };
          await _cacheRatings();
          await sharedPrefs.setValue(
              lastSyncKey, DateTime.now().toIso8601String());
          return dist;
        }
      } catch (e) {
        print('[⚠️] Error distribución ratings: $e');
      }
    }

    final db = await _db;
    final res = await db.rawQuery(
      '''
      SELECT ROUND(rating) AS bucket, COUNT(*) AS cnt
      FROM book_ratings
      WHERE book_id = ?
      GROUP BY bucket
      ''',
      [bookId],
    );
    final Map<int, int> dist = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final row in res) {
      final bucket = (row['bucket'] as num?)?.round() ?? 0;
      final cnt = (row['cnt'] as num?)?.toInt() ?? 0;
      if (dist.containsKey(bucket)) {
        dist[bucket] = cnt;
      }
    }
    print('[💾] Distribución desde SQLite: $dist');
    await _cacheRatings();
    return dist;
  }

  @override
  Future<void> deleteRating({
    required String userId,
    required String bookId,
  }) async {
    final db = await _db;

    // 🔸 Eliminar rating localmente
    await db.transaction((txn) async {
      await txn.delete(
        'book_ratings',
        where: 'user_id = ? AND book_id = ?',
        whereArgs: [userId, bookId],
      );

      final res = await txn.rawQuery(
        'SELECT AVG(rating) AS avg, COUNT(*) AS cnt FROM book_ratings WHERE book_id = ?',
        [bookId],
      );
      final avg = (res.first['avg'] as num?)?.toDouble() ?? 0.0;
      final cnt = (res.first['cnt'] as num?)?.toInt() ?? 0;

      await txn.update(
        'books',
        {'rating': avg, 'ratings_count': cnt},
        where: 'id = ?',
        whereArgs: [bookId],
      );
    });

    print('[🗑️] Rating eliminado localmente. Sincronizando con APIs...');

    // 🔸 Eliminar en APIs si hay conexión
    if (await _isOnline()) {
      try {
        final body = {
          'user_id': userId,
          'book_id': bookId,
        };

        final response = await _deleteWithBody('deleteRating', body);

        if (!_isSuccessfulResponse(response.statusCode)) {
          print('[❌] Error API: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('[❌] Error al eliminar rating: $e');
      }
    }

    await _cacheRatings();
    _scheduleSync();
  }

  @override
  Future<List<BookRating>> fetchUserRatings({
    required String bookId,
    int page = 1,
    int limit = 10,
  }) async {
    final offset = (page - 1) * limit;

    if (await _isCacheValid()) {
      final cachedData = await sharedPrefs.getValue(cacheKey);
      if (cachedData != null) {
        try {
          final List<dynamic> cachedList = jsonDecode(cachedData);
          final ratings = cachedList
              .where((item) => item['book_id'] == bookId)
              .map((item) => BookRating.fromMap(item))
              .skip(offset)
              .take(limit)
              .toList();
          print(
              '[📦] Loaded ${ratings.length} ratings from cache for book $bookId');
          _scheduleSync();
          return ratings;
        } catch (e) {
          print('[⚠️] Error parsing cache: $e');
        }
      }
    }

    if (await _isOnline()) {
      try {
        final response = await _get(
            'getUserRatings?book_id=$bookId&page=$page&limit=$limit');

        if (_isSuccessfulResponse(response.statusCode)) {
          final data = jsonDecode(response.body);
          if (data is List) {
            final ratings =
                data.map((item) => BookRating.fromMap(item)).toList();
            final db = await _db;
            await db.transaction((txn) async {
              for (var rating in ratings) {
                await txn.insert(
                  'book_ratings',
                  rating.toMap()..['needs_sync'] = 0,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            });
            await _cacheRatings();
            await sharedPrefs.setValue(
                lastSyncKey, DateTime.now().toIso8601String());
            return ratings;
          }
        }
      } catch (e) {
        print('[⚠️] Error cargando ratings de usuarios: $e');
      }
    }

    final db = await _db;
    final result = await db.query(
      'book_ratings',
      where: 'book_id = ?',
      whereArgs: [bookId],
      limit: limit,
      offset: offset,
    );
    final ratings = result.map((map) => BookRating.fromMap(map)).toList();
    print('[💾] Loaded ${ratings.length} ratings from SQLite for book $bookId');
    await _cacheRatings();
    return ratings;
  }
}
