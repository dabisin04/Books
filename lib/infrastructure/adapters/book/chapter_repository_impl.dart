import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../../../domain/entities/book/chapter.dart';
import '../../../domain/ports/book/chapter_repository.dart';
import '../../database/database_helper.dart';

class ChapterRepositoryImpl implements ChapterRepository {
  final Connectivity _connectivity = Connectivity();
  Future<Database> get _database async =>
      await DatabaseHelper.instance.database;
  static const String baseUrl = 'http://172.50.4.230:5000/api';

  Future<bool> _isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _syncLocalData() async {
    if (!await _isOnline()) return;

    final db = await _database;
    final localChapters = await db.query('chapters');
    for (var chapterMap in localChapters) {
      final chapter = Chapter.fromMap(chapterMap);
      try {
        // Check if chapter exists on server
        final response =
            await http.get(Uri.parse('$baseUrl/chapters/${chapter.bookId}'));
        final serverChapters = jsonDecode(response.body) as List<dynamic>;
        final exists = serverChapters.any((c) => c['id'] == chapter.id);

        if (!exists) {
          // Add new chapter to server
          await http.post(
            Uri.parse('$baseUrl/addChapter'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(chapter.toMap()),
          );
        } else {
          // Update existing chapter
          await http.put(
            Uri.parse('$baseUrl/updateChapter'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(chapter.toMap()),
          );
        }
      } catch (e) {
        // Log error, continue with next chapter
        print('Sync error for chapter ${chapter.id}: $e');
      }
    }
  }

  @override
  Future<void> addChapter(Chapter chapter) async {
    final db = await _database;
    if (await _isOnline()) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/addChapter'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(chapter.toMap()),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to add chapter to API');
        }
      } catch (e) {
        // Fallback to SQLite
        await db.insert(
          'chapters',
          chapter.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } else {
      await db.insert(
        'chapters',
        chapter.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> updateChapter(Chapter chapter) async {
    final db = await _database;
    if (await _isOnline()) {
      try {
        final response = await http.put(
          Uri.parse('$baseUrl/updateChapter'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(chapter.toMap()),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to update chapter via API');
        }
      } catch (e) {
        // Fallback to SQLite
        await db.update(
          'chapters',
          chapter.toMap(),
          where: 'id = ?',
          whereArgs: [chapter.id],
        );
      }
    } else {
      await db.update(
        'chapters',
        chapter.toMap(),
        where: 'id = ?',
        whereArgs: [chapter.id],
      );
    }

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> deleteChapter(String chapterId) async {
    final db = await _database;
    if (await _isOnline()) {
      try {
        final response =
            await http.delete(Uri.parse('$baseUrl/deleteChapter/$chapterId'));
        if (response.statusCode != 200) {
          throw Exception('Failed to delete chapter from API');
        }
      } catch (e) {
        // Fallback to SQLite
        await db.delete(
          'chapters',
          where: 'id = ?',
          whereArgs: [chapterId],
        );
      }
    } else {
      await db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: [chapterId],
      );
    }

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<List<Chapter>> fetchChaptersByBook(String bookId) async {
    if (await _isOnline()) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/chapters/$bookId'));
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final chapters = data.map((map) => Chapter.fromMap(map)).toList();
          // Update local SQLite
          final db = await _database;
          await db
              .delete('chapters', where: 'book_id = ?', whereArgs: [bookId]);
          for (var chapter in chapters) {
            await db.insert('chapters', chapter.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          return chapters;
        }
      } catch (e) {
        // Fallback to SQLite
      }
    }

    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chapters',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'chapter_number ASC',
    );
    return maps.map((map) => Chapter.fromMap(map)).toList();
  }

  @override
  Future<void> updateChapterViews(String chapterId) async {
    if (await _isOnline()) {
      try {
        final response =
            await http.put(Uri.parse('$baseUrl/updateChapterViews/$chapterId'));
        if (response.statusCode != 200) {
          throw Exception('Failed to update chapter views via API');
        }
      } catch (e) {
        // Fallback to SQLite
        final db = await _database;
        await db.rawUpdate(
          'UPDATE chapters SET views = views + 1 WHERE id = ?',
          [chapterId],
        );
      }
    } else {
      final db = await _database;
      await db.rawUpdate(
        'UPDATE chapters SET views = views + 1 WHERE id = ?',
        [chapterId],
      );
    }

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> rateChapter(
      String chapterId, String userId, double rating) async {
    if (await _isOnline()) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/rateChapter'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'chapter_id': chapterId,
            'user_id': userId,
            'rating': rating,
          }),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to rate chapter via API');
        }
      } catch (e) {
        // Fallback to SQLite
        final db = await _database;
        await db.insert(
          'chapter_ratings',
          {
            'id': '$userId-$chapterId',
            'user_id': userId,
            'chapter_id': chapterId,
            'rating': rating,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        final ratings = await db.query(
          'chapter_ratings',
          columns: ['rating'],
          where: 'chapter_id = ?',
          whereArgs: [chapterId],
        );

        if (ratings.isNotEmpty) {
          double avgRating = ratings.fold<double>(
                  0, (sum, item) => sum + (item['rating'] as num).toDouble()) /
              ratings.length;
          await db.update(
            'chapters',
            {'rating': avgRating},
            where: 'id = ?',
            whereArgs: [chapterId],
          );
        }
      }
    } else {
      final db = await _database;
      await db.insert(
        'chapter_ratings',
        {
          'id': '$userId-$chapterId',
          'user_id': userId,
          'chapter_id': chapterId,
          'rating': rating,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final ratings = await db.query(
        'chapter_ratings',
        columns: ['rating'],
        where: 'chapter_id = ?',
        whereArgs: [chapterId],
      );

      if (ratings.isNotEmpty) {
        double avgRating = ratings.fold<double>(
                0, (sum, item) => sum + (item['rating'] as num).toDouble()) /
            ratings.length;
        await db.update(
          'chapters',
          {'rating': avgRating},
          where: 'id = ?',
          whereArgs: [chapterId],
        );
      }
    }

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> updateChapterContent(
      String chapterId, Map<String, dynamic> content) async {
    if (await _isOnline()) {
      try {
        final response = await http.put(
          Uri.parse('$baseUrl/updateChapterContent/$chapterId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'content': content}),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to update chapter content via API');
        }
      } catch (e) {
        // Fallback to SQLite
        final db = await _database;
        await db.update(
          'chapters',
          {'content': jsonEncode(content)},
          where: 'id = ?',
          whereArgs: [chapterId],
        );
      }
    } else {
      final db = await _database;
      await db.update(
        'chapters',
        {'content': jsonEncode(content)},
        where: 'id = ?',
        whereArgs: [chapterId],
      );
    }

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> updateChapterPublicationDate(
      String chapterId, String? publicationDate) async {
    if (await _isOnline()) {
      try {
        final response = await http.put(
          Uri.parse('$baseUrl/updateChapterPublicationDate/$chapterId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'publication_date': publicationDate}),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to update chapter publication date via API');
        }
      } catch (e) {
        // Fallback to SQLite
        final db = await _database;
        await db.update(
          'chapters',
          {'publication_date': publicationDate},
          where: 'id = ?',
          whereArgs: [chapterId],
        );
      }
    } else {
      final db = await _database;
      await db.update(
        'chapters',
        {'publication_date': publicationDate},
        where: 'id = ?',
        whereArgs: [chapterId],
      );
    }

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> updateChapterDetails(String chapterId,
      {String? title, String? description}) async {
    final Map<String, dynamic> values = {};
    if (title != null) values['title'] = title;
    if (description != null) values['description'] = description;

    if (values.isNotEmpty) {
      if (await _isOnline()) {
        try {
          final response = await http.put(
            Uri.parse('$baseUrl/updateChapterDetails/$chapterId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(values),
          );
          if (response.statusCode != 200) {
            throw Exception('Failed to update chapter details via API');
          }
        } catch (e) {
          // Fallback to SQLite
          final db = await _database;
          await db.update(
            'chapters',
            values,
            where: 'id = ?',
            whereArgs: [chapterId],
          );
        }
      } else {
        final db = await _database;
        await db.update(
          'chapters',
          values,
          where: 'id = ?',
          whereArgs: [chapterId],
        );
      }
    }

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<List<Chapter>> searchChapters(String query) async {
    if (await _isOnline()) {
      try {
        final response =
            await http.get(Uri.parse('$baseUrl/searchChapters?query=$query'));
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final chapters = data.map((map) => Chapter.fromMap(map)).toList();
          // Update local SQLite
          final db = await _database;
          for (var chapter in chapters) {
            await db.insert('chapters', chapter.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          return chapters;
        }
      } catch (e) {
        // Fallback to SQLite
      }
    }

    final db = await _database;
    final List<Map<String, dynamic>> result = await db.query(
      'chapters',
      where: 'title LIKE ? AND is_trashed = 0',
      whereArgs: ['%$query%'],
    );
    return result.map((map) => Chapter.fromMap(map)).toList();
  }
}
