import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../../../domain/entities/book/chapter.dart';
import '../../../domain/ports/book/chapter_repository.dart';
import '../../database/database_helper.dart';

class ChapterRepositoryImpl implements ChapterRepository {
  final Connectivity _connectivity = Connectivity();
  Future<Database> get _database async =>
      await DatabaseHelper.instance.database;
  static String primaryApiUrl =
      (dotenv.env['API_BASE_URL'] ?? '').replaceAll('//api', '/api');
  static String altApiUrl =
      (dotenv.env['ALT_API_BASE_URL'] ?? '').replaceAll('//api', '/api');
  static String apiKey = dotenv.env['API_KEY'] ?? '';
  static final Duration apiTimeout = Duration(
    seconds: int.tryParse(dotenv.env['API_TIMEOUT'] ?? '5') ?? 5,
  );

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

  Future<void> _syncLocalData() async {
    if (!await _isOnline()) return;

    final db = await _database;
    final localChapters = await db.query('chapters');
    for (var chapterMap in localChapters) {
      final chapter = Chapter.fromMap(chapterMap);
      try {
        final response = await _get('chapters/${chapter.bookId}');
        if (_isSuccessfulResponse(response.statusCode)) {
          final serverChapters = jsonDecode(response.body) as List<dynamic>;
          final exists = serverChapters.any((c) => c['id'] == chapter.id);

          if (!exists) {
            await _post('addChapter', chapter.toMap());
          } else {
            await _put('updateChapter', chapter.toMap());
          }
        }
      } catch (e) {
        print('Sync error for chapter ${chapter.id}: $e');
      }
    }
  }

  @override
  Future<void> addChapter(Chapter chapter) async {
    final db = await _database;
    if (await _isOnline()) {
      try {
        print('📤 Registrando capítulo primero en Flask...');
        final flaskResponse = await http
            .post(
              Uri.parse('$primaryApiUrl/addChapter'),
              headers: _headers(),
              body: jsonEncode(chapter.toMap()),
            )
            .timeout(apiTimeout);

        if (flaskResponse.statusCode != 201) {
          final error = jsonDecode(flaskResponse.body);
          throw Exception(error['error'] ?? 'Error al registrar en Flask');
        }

        final flaskData = jsonDecode(flaskResponse.body);
        print('✅ Capítulo creado en Flask con ID: ${flaskData["id"]}');

        // Ahora registrar en FastAPI incluyendo `from_flask = true`
        final fastapiResponse = await http
            .post(
              Uri.parse('$altApiUrl/addChapter'),
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

        final chapterToInsert = Chapter.fromMap(flaskData);
        await db.insert('chapters', chapterToInsert.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        print('💾 Capítulo guardado en DB local con ID: ${chapterToInsert.id}');
      } catch (e) {
        print('❌ Error completo en registro dual: $e');
        throw Exception('Error al registrar el capítulo: $e');
      }
    } else {
      print("📴 Sin conexión. Guardando localmente.");
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
        await _put('updateChapter', chapter.toMap());
      } catch (e) {
        print('API error during updateChapter: $e');
      }
    }

    await db.update(
      'chapters',
      chapter.toMap(),
      where: 'id = ?',
      whereArgs: [chapter.id],
    );

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> deleteChapter(String chapterId) async {
    final db = await _database;
    if (await _isOnline()) {
      try {
        await _delete('deleteChapter/$chapterId');
      } catch (e) {
        print('API error during deleteChapter: $e');
      }
    }

    await db.delete(
      'chapters',
      where: 'id = ?',
      whereArgs: [chapterId],
    );

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<List<Chapter>> fetchChaptersByBook(String bookId) async {
    if (await _isOnline()) {
      try {
        final response = await _get('chapters/$bookId');
        if (_isSuccessfulResponse(response.statusCode)) {
          final List<dynamic> data = jsonDecode(response.body);
          final chapters = data.map((map) => Chapter.fromMap(map)).toList();
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
        print('API error during fetchChaptersByBook: $e');
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
        await _put('updateChapterViews/$chapterId', {});
      } catch (e) {
        print('API error during updateChapterViews: $e');
      }
    }

    final db = await _database;
    await db.rawUpdate(
      'UPDATE chapters SET views = views + 1 WHERE id = ?',
      [chapterId],
    );

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> rateChapter(
      String chapterId, String userId, double rating) async {
    if (await _isOnline()) {
      try {
        await _post('rateChapter', {
          'chapter_id': chapterId,
          'user_id': userId,
          'rating': rating,
        });
      } catch (e) {
        print('API error during rateChapter: $e');
      }
    }

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

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> updateChapterContent(
      String chapterId, Map<String, dynamic> content) async {
    if (await _isOnline()) {
      try {
        await _put('updateChapterContent/$chapterId', {'content': content});
      } catch (e) {
        print('API error during updateChapterContent: $e');
      }
    }

    final db = await _database;
    await db.update(
      'chapters',
      {'content': jsonEncode(content)},
      where: 'id = ?',
      whereArgs: [chapterId],
    );

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> updateChapterPublicationDate(
      String chapterId, String? publicationDate) async {
    if (await _isOnline()) {
      try {
        await _put('updateChapterPublicationDate/$chapterId', {
          'publication_date': publicationDate,
        });
      } catch (e) {
        print('API error during updateChapterPublicationDate: $e');
      }
    }

    final db = await _database;
    await db.update(
      'chapters',
      {'publication_date': publicationDate},
      where: 'id = ?',
      whereArgs: [chapterId],
    );

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
          await _put('updateChapterDetails/$chapterId', values);
        } catch (e) {
          print('API error during updateChapterDetails: $e');
        }
      }

      final db = await _database;
      await db.update(
        'chapters',
        values,
        where: 'id = ?',
        whereArgs: [chapterId],
      );
    }

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<List<Chapter>> searchChapters(String query) async {
    if (await _isOnline()) {
      try {
        final response = await _get('searchChapters?query=$query');
        if (_isSuccessfulResponse(response.statusCode)) {
          final List<dynamic> data = jsonDecode(response.body);
          final chapters = data.map((map) => Chapter.fromMap(map)).toList();
          final db = await _database;
          for (var chapter in chapters) {
            await db.insert('chapters', chapter.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          return chapters;
        }
      } catch (e) {
        print('API error during searchChapters: $e');
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
