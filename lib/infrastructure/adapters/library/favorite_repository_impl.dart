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
    final localFavorites = await db.query('favorites');
    for (var favoriteMap in localFavorites) {
      final userId = favoriteMap['user_id'] as String;
      final bookId = favoriteMap['book_id'] as String;

      try {
        // Check if favorite exists on server
        final response = await http.get(
          Uri.parse('$baseUrl/isFavorite?user_id=$userId&book_id=$bookId'),
        );
        final isFavorite = jsonDecode(response.body)['is_favorite'] as bool;

        if (!isFavorite) {
          // Add new favorite to server
          await http.post(
            Uri.parse('$baseUrl/addFavorite'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'book_id': bookId,
            }),
          );
        }
      } catch (e) {
        // Log error, continue with next favorite
        print('Sync error for favorite $userId-$bookId: $e');
      }
    }

    // Sync server favorites to local
    final userIds = localFavorites.map((f) => f['user_id'] as String).toSet();
    for (var userId in userIds) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/favoriteBookIds/$userId'),
        );
        if (response.statusCode == 200) {
          final serverBookIds = List<String>.from(jsonDecode(response.body));
          final localBookIds = localFavorites
              .where((f) => f['user_id'] == userId)
              .map((f) => f['book_id'] as String)
              .toList();

          // Add missing server favorites to local
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

          // Remove local favorites not on server
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
        final response = await http.post(
          Uri.parse('$baseUrl/addFavorite'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'book_id': bookId,
          }),
        );
        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception('Failed to add favorite to API');
        }
      } catch (e) {
        // Fallback to SQLite
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
    } else {
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
        final response = await http.delete(
          Uri.parse('$baseUrl/removeFavorite'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'book_id': bookId,
          }),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to remove favorite from API');
        }
      } catch (e) {
        // Fallback to SQLite
        await db.delete(
          'favorites',
          where: 'user_id = ? AND book_id = ?',
          whereArgs: [userId, bookId],
        );
      }
    } else {
      await db.delete(
        'favorites',
        where: 'user_id = ? AND book_id = ?',
        whereArgs: [userId, bookId],
      );
    }

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<List<String>> getFavoriteBookIds(String userId) async {
    if (await _isOnline()) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/favoriteBookIds/$userId'),
        );
        if (response.statusCode == 200) {
          final bookIds = List<String>.from(jsonDecode(response.body));
          // Update local SQLite
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
        // Fallback to SQLite
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
        final response = await http.get(
          Uri.parse('$baseUrl/isFavorite?user_id=$userId&book_id=$bookId'),
        );
        if (response.statusCode == 200) {
          final isFavorite = jsonDecode(response.body)['is_favorite'] as bool;
          // Update local SQLite
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
        // Fallback to SQLite
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
