import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/ports/interaction/rating_repository.dart';
import '../../database/database_helper.dart';

class BookRatingRepositoryImpl implements BookRatingRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();
  final Connectivity _connectivity = Connectivity();
  static String baseUrl = dotenv.env['API_BASE_URL'] ?? '';
  static final Duration apiTimeout = Duration(
    seconds: int.tryParse(dotenv.env['API_TIMEOUT'] ?? '5') ?? 5,
  );

  Future<Database> get _db async => await _dbHelper.database;

  Future<bool> _isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _syncLocalData() async {
    if (!await _isOnline()) return;

    final db = await _db;
    final localRatings = await db.query('book_ratings');
    for (var ratingMap in localRatings) {
      final userId = ratingMap['user_id'] as String;
      final bookId = ratingMap['book_id'] as String;
      final rating = (ratingMap['rating'] as num).toDouble();
      final timestamp = ratingMap['timestamp'] as String;

      try {
        // Check if rating exists on server
        final response = await http.get(
          Uri.parse('$baseUrl/getUserRating?user_id=$userId&book_id=$bookId'),
        );
        final serverRating = jsonDecode(response.body)['rating'];

        if (serverRating == null) {
          // Add new rating to server
          await http.post(
            Uri.parse('$baseUrl/rateBook'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'book_id': bookId,
              'rating': rating,
              'timestamp': timestamp,
            }),
          );
        } else if (serverRating != rating) {
          // Update existing rating
          await http.post(
            Uri.parse('$baseUrl/rateBook'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'book_id': bookId,
              'rating': rating,
              'timestamp': timestamp,
            }),
          );
        }
      } catch (e) {
        // Log error, continue with next rating
        print('Sync error for rating $userId-$bookId: $e');
      }
    }
  }

  @override
  Future<void> upsertRating({
    required String userId,
    required String bookId,
    required double rating,
    DateTime? timestamp,
  }) async {
    final db = await _db;
    final ratingId = _uuid.v4();
    final timestampStr = (timestamp ?? DateTime.now()).toIso8601String();

    if (await _isOnline()) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/rateBook'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'book_id': bookId,
            'rating': rating,
            'timestamp': timestampStr,
          }),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to upsert rating to API');
        }
      } catch (e) {
        // Fallback to SQLite
        await db.insert(
          'book_ratings',
          {
            'id': ratingId,
            'user_id': userId,
            'book_id': bookId,
            'rating': rating,
            'timestamp': timestampStr,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Recalculate average and count
        final res = await db.rawQuery(
          'SELECT AVG(rating) AS avg, COUNT(*) AS cnt FROM book_ratings WHERE book_id = ?',
          [bookId],
        );
        final avg = (res.first['avg'] as num?)?.toDouble() ?? 0.0;
        final cnt = (res.first['cnt'] as num?)?.toInt() ?? 0;

        await db.update(
          'books',
          {'rating': avg, 'ratings_count': cnt},
          where: 'id = ?',
          whereArgs: [bookId],
        );
      }
    } else {
      await db.insert(
        'book_ratings',
        {
          'id': ratingId,
          'user_id': userId,
          'book_id': bookId,
          'rating': rating,
          'timestamp': timestampStr,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Recalculate average and count
      final res = await db.rawQuery(
        'SELECT AVG(rating) AS avg, COUNT(*) AS cnt FROM book_ratings WHERE book_id = ?',
        [bookId],
      );
      final avg = (res.first['avg'] as num?)?.toDouble() ?? 0.0;
      final cnt = (res.first['cnt'] as num?)?.toInt() ?? 0;

      await db.update(
        'books',
        {'rating': avg, 'ratings_count': cnt},
        where: 'id = ?',
        whereArgs: [bookId],
      );
    }

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<double?> fetchUserRating({
    required String userId,
    required String bookId,
  }) async {
    if (await _isOnline()) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/getUserRating?user_id=$userId&book_id=$bookId'),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final rating = data['rating'] as num?;
          if (rating != null) {
            // Update local SQLite
            final db = await _db;
            await db.insert(
              'book_ratings',
              {
                'id': _uuid.v4(),
                'user_id': userId,
                'book_id': bookId,
                'rating': rating,
                'timestamp': DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          return rating?.toDouble();
        }
      } catch (e) {
        // Fallback to SQLite
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
    if (res.isEmpty) return null;
    return res.first['rating'] as double;
  }

  @override
  Future<({double average, int count})> fetchGlobalAverage(
      String bookId) async {
    if (await _isOnline()) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/getGlobalAverage/$bookId'),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final average = (data['average'] as num).toDouble();
          final count = (data['count'] as num).toInt();
          // Update local SQLite book rating
          final db = await _db;
          await db.update(
            'books',
            {'rating': average, 'ratings_count': count},
            where: 'id = ?',
            whereArgs: [bookId],
          );
          return (average: average, count: count);
        }
      } catch (e) {
        // Fallback to SQLite
      }
    }

    final db = await _db;
    final res = await db.rawQuery(
      'SELECT AVG(rating) AS avg, COUNT(*) AS cnt FROM book_ratings WHERE book_id = ?',
      [bookId],
    );
    return (
      average: (res.first['avg'] as num?)?.toDouble() ?? 0.0,
      count: (res.first['cnt'] as num?)?.toInt() ?? 0
    );
  }

  @override
  Future<Map<int, int>> fetchDistribution(String bookId) async {
    if (await _isOnline()) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/getRatingDistribution/$bookId'),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final dist = {
            for (var i = 1; i <= 5; i++) i: (data[i.toString()] as num).toInt()
          };
          // No direct SQLite update since distribution is not stored
          return dist;
        }
      } catch (e) {
        // Fallback to SQLite
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
      dist[bucket] = cnt;
    }
    return dist;
  }

  @override
  Future<void> deleteRating({
    required String userId,
    required String bookId,
  }) async {
    final db = await _db;

    if (await _isOnline()) {
      try {
        final response = await http.delete(
          Uri.parse('$baseUrl/deleteRating'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'book_id': bookId,
          }),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to delete rating from API');
        }
      } catch (e) {
        // Fallback to SQLite
        await db.delete(
          'book_ratings',
          where: 'user_id = ? AND book_id = ?',
          whereArgs: [userId, bookId],
        );

        // Recalculate average and count
        final res = await db.rawQuery(
          'SELECT AVG(rating) AS avg, COUNT(*) AS cnt FROM book_ratings WHERE book_id = ?',
          [bookId],
        );
        final avg = (res.first['avg'] as num?)?.toDouble() ?? 0.0;
        final cnt = (res.first['cnt'] as num?)?.toInt() ?? 0;

        await db.update(
          'books',
          {'rating': avg, 'ratings_count': cnt},
          where: 'id = ?',
          whereArgs: [bookId],
        );
      }
    } else {
      await db.delete(
        'book_ratings',
        where: 'user_id = ? AND book_id = ?',
        whereArgs: [userId, bookId],
      );

      // Recalculate average and count
      final res = await db.rawQuery(
        'SELECT AVG(rating) AS avg, COUNT(*) AS cnt FROM book_ratings WHERE book_id = ?',
        [bookId],
      );
      final avg = (res.first['avg'] as num?)?.toDouble() ?? 0.0;
      final cnt = (res.first['cnt'] as num?)?.toInt() ?? 0;

      await db.update(
        'books',
        {'rating': avg, 'ratings_count': cnt},
        where: 'id = ?',
        whereArgs: [bookId],
      );
    }

    if (await _isOnline()) await _syncLocalData();
  }
}
