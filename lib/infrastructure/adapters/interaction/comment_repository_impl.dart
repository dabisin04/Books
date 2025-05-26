import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/interaction/comment.dart';
import '../../../domain/ports/interaction/comment_repository.dart';
import '../../database/database_helper.dart';
import '../../utils/shared_prefs_helper.dart';

class CommentRepositoryImpl implements CommentRepository {
  final SharedPrefsService sharedPrefs;
  final Connectivity _connectivity = Connectivity();
  Future<Database> get _database async =>
      await DatabaseHelper.instance.database;
  static const String cacheKey = 'cached_comments';
  static String primaryApiUrl =
      (dotenv.env['API_BASE_URL'] ?? '').replaceAll('//api', '/api');
  static String altApiUrl =
      (dotenv.env['ALT_API_BASE_URL'] ?? '').replaceAll('//api', '/api');
  static String apiKey = dotenv.env['API_KEY'] ?? '';
  static final Duration apiTimeout = Duration(
    seconds: int.tryParse(dotenv.env['API_TIMEOUT'] ?? '5') ?? 5,
  );

  CommentRepositoryImpl(this.sharedPrefs);

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
      print('📤 [POST] Enviando a Flask: $endpoint');
      print('📦 Datos a Flask: ${jsonEncode(body)}');

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

  Future<http.Response> _put(String endpoint, Map<String, dynamic> body,
      {Map<String, String> headers = const {}}) async {
    try {
      print('📤 [PUT] Enviando a Flask: $endpoint');
      print('📦 Datos a Flask: ${jsonEncode(body)}');
      print('📤 [PUT] Headers: ${{..._headers(), ...headers}}');

      final allHeaders = {..._headers(), ...headers};

      final futures = [
        http
            .put(
              Uri.parse('$primaryApiUrl/$endpoint'),
              headers: allHeaders,
              body: jsonEncode(body),
            )
            .timeout(apiTimeout),
        http
            .put(
              Uri.parse('$altApiUrl/$endpoint'),
              headers: allHeaders,
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
              .put(
                Uri.parse('$primaryApiUrl/$endpoint'),
                headers: allHeaders,
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
      print('❌ Error in PUT request: $e');
      rethrow;
    }
  }

  Future<http.Response> _delete(
      String endpoint, Map<String, String> headers) async {
    try {
      final allHeaders = {..._headers(), ...headers};
      print('📤 [DELETE] Headers: $allHeaders');

      final futures = [
        http
            .delete(
              Uri.parse('$primaryApiUrl/$endpoint'),
              headers: allHeaders,
            )
            .timeout(apiTimeout),
        http
            .delete(
              Uri.parse('$altApiUrl/$endpoint'),
              headers: allHeaders,
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
                headers: allHeaders,
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

  String? getCurrentUserId() {
    final id = sharedPrefs.getValue<String>('user_id');
    print('🔐 Usuario actual: $id');
    return id;
  }

  Future<bool> _isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    final online = connectivityResult != ConnectivityResult.none;
    print('🌐 Conectividad: ${online ? 'Online' : 'Offline'}');
    return online;
  }

  Future<void> _syncLocalData() async {
    if (!await _isOnline()) return;

    final db = await _database;
    final localComments = await db.query('comments');
    print('🔄 Comentarios locales a sincronizar: ${localComments.length}');

    for (var commentMap in localComments) {
      final comment = Comment.fromMap(commentMap);
      try {
        final response = await _get('commentsByBook/${comment.bookId}');
        if (_isSuccessfulResponse(response.statusCode)) {
          final serverComments = jsonDecode(response.body) as List<dynamic>;
          final exists = serverComments.any((c) => c['id'] == comment.id);

          if (!exists) {
            print('📤 Enviando comentario nuevo: ${comment.id}');
            await _post('addComment', comment.toMap());
          } else {
            print('✏️ Actualizando comentario existente: ${comment.id}');
            await _put('updateComment/${comment.id}', {
              'content': comment.content,
            }, headers: {
              'X-User-Id': comment.userId
            });
          }
        }
      } catch (e) {
        print('❌ Error sincronizando ${comment.id}: $e');
      }
    }
  }

  @override
  Future<void> addComment(Comment comment) async {
    final db = await _database;
    final commentId = comment.id.isEmpty ? const Uuid().v4() : comment.id;
    final newComment = comment.copyWith(id: commentId);

    print('📝 Agregando comentario: ${newComment.toMap()}');

    String? rootCommentId;
    if (!await _isOnline() && newComment.parentCommentId != null) {
      final result = await db.query(
        'comments',
        columns: ['root_comment_id'],
        where: 'id = ?',
        whereArgs: [newComment.parentCommentId],
      );
      rootCommentId = result.firstOrNull?['root_comment_id'] as String? ??
          newComment.parentCommentId;
    }

    final commentMap = {
      'id': newComment.id,
      'user_id': newComment.userId,
      'book_id': newComment.bookId,
      'content': newComment.content,
      'timestamp': newComment.timestamp,
      'parent_comment_id': newComment.parentCommentId,
      if (rootCommentId != null) 'root_comment_id': rootCommentId,
      'reports': newComment.reports,
    };

    if (await _isOnline()) {
      try {
        print('📤 Registrando comentario primero en Flask...');
        final flaskResponse = await http
            .post(
              Uri.parse('$primaryApiUrl/addComment'),
              headers: _headers(),
              body: jsonEncode(commentMap),
            )
            .timeout(apiTimeout);

        if (flaskResponse.statusCode < 200 || flaskResponse.statusCode >= 300) {
          final error = jsonDecode(flaskResponse.body);
          throw Exception(error['error'] ?? 'Error al registrar en Flask');
        }

        final flaskData = jsonDecode(flaskResponse.body);
        print('✅ Comentario creado en Flask con ID: ${flaskData["id"]}');

        // Ahora registrar en FastAPI incluyendo `from_flask = true`
        final fastapiResponse = await http
            .post(
              Uri.parse('$altApiUrl/addComment'),
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

        final commentToInsert = Comment.fromMap(flaskData);
        await db.insert('comments', commentToInsert.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        print(
            '💾 Comentario guardado en DB local con ID: ${commentToInsert.id}');
      } catch (e) {
        print('❌ Error completo en registro dual: $e');
        throw Exception('Error al registrar el comentario: $e');
      }
    } else {
      print('💾 Guardando comentario offline.');
      await db.insert('comments', commentMap);
    }

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<void> deleteComment(String commentId) async {
    final db = await _database;
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) {
      throw Exception("Error: Usuario no autenticado.");
    }

    print('🗑️ Eliminando comentario $commentId por usuario $currentUserId');

    await db.delete('comments', where: 'id = ?', whereArgs: [commentId]);

    if (await _isOnline()) {
      try {
        await _delete('deleteComment/$commentId', {'X-User-Id': currentUserId});
      } catch (e) {
        print('❌ API error: $e');
      }
    }
  }

  @override
  Future<List<Comment>> fetchCommentsByBook(String bookId) async {
    final db = await _database;
    await db.delete('comments', where: 'book_id = ?', whereArgs: [bookId]);

    if (await _isOnline()) {
      try {
        final response = await _get('commentsByBook/$bookId');

        if (_isSuccessfulResponse(response.statusCode)) {
          final List<dynamic> data = jsonDecode(response.body);
          final comments = data.map((map) => Comment.fromMap(map)).toList();

          for (var comment in comments) {
            await db.insert(
              'comments',
              comment.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          return comments;
        }
      } catch (e) {
        print('❌ API error: $e');
      }
    }

    return [];
  }

  @override
  Future<List<Comment>> fetchReplies(String commentId) async {
    if (await _isOnline()) {
      try {
        final response = await _get('replies/$commentId');

        if (_isSuccessfulResponse(response.statusCode)) {
          final List<dynamic> data = jsonDecode(response.body);
          final replies = data.map((map) => Comment.fromMap(map)).toList();

          final db = await _database;
          for (var reply in replies) {
            await db.insert('comments', reply.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          return replies;
        }
      } catch (e) {
        print('❌ API error fetchReplies: $e');
      }
    }

    final db = await _database;
    final List<Map<String, dynamic>> result = await db.query(
      'comments',
      where: 'parent_comment_id = ?',
      whereArgs: [commentId],
    );
    return result.map((map) => Comment.fromMap(map)).toList();
  }

  @override
  Future<void> updateComment(String commentId, String newContent) async {
    final db = await _database;
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) {
      throw Exception("Error: Usuario no autenticado.");
    }

    print('✏️ Editando comentario $commentId por usuario $currentUserId');

    await db.update(
      'comments',
      {'content': newContent},
      where: 'id = ?',
      whereArgs: [commentId],
    );

    if (await _isOnline()) {
      try {
        await _put('updateComment/$commentId', {
          'content': newContent,
        }, headers: {
          'X-User-Id': currentUserId
        });
      } catch (e) {
        print('❌ API error updateComment: $e');
      }
    }
  }
}
