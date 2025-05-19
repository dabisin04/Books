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
  static String baseUrl = dotenv.env['API_BASE_URL'] ?? '';
  static final Duration apiTimeout = Duration(
    seconds: int.tryParse(dotenv.env['API_TIMEOUT'] ?? '5') ?? 5,
  );

  CommentRepositoryImpl(this.sharedPrefs);

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
        final response = await http
            .get(Uri.parse('$baseUrl/commentsByBook/${comment.bookId}'));
        final serverComments = jsonDecode(response.body) as List<dynamic>;
        final exists = serverComments.any((c) => c['id'] == comment.id);

        if (!exists) {
          print('📤 Enviando comentario nuevo: ${comment.id}');
          await http.post(
            Uri.parse('$baseUrl/addComment'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(comment.toMap()),
          );
        } else {
          print('✏️ Actualizando comentario existente: ${comment.id}');
          await http.put(
            Uri.parse('$baseUrl/updateComment/${comment.id}'),
            headers: {
              'Content-Type': 'application/json',
              'X-User-Id': comment.userId,
            },
            body: jsonEncode({'content': comment.content}),
          );
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
        final response = await http.post(
          Uri.parse('$baseUrl/addComment'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(commentMap),
        );

        print(
            '📥 Respuesta addComment: ${response.statusCode} - ${response.body}');

        if (response.statusCode != 200) {
          throw Exception('API rechazó el comentario: ${response.body}');
        }
      } catch (e) {
        print('❌ Error al enviar a la API. Guardando local: $e');
        await db.insert('comments', commentMap);
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
        final response = await http.delete(
          Uri.parse('$baseUrl/deleteComment/$commentId'),
          headers: {'X-User-Id': currentUserId},
        );
        print(
            '📥 Respuesta deleteComment: ${response.statusCode} - ${response.body}');
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
        final response =
            await http.get(Uri.parse('$baseUrl/commentsByBook/$bookId'));
        print('📥 Comentarios obtenidos: ${response.statusCode}');

        if (response.statusCode == 200) {
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
        final response =
            await http.get(Uri.parse('$baseUrl/replies/$commentId'));
        print('📥 Respuesta fetchReplies: ${response.statusCode}');

        if (response.statusCode == 200) {
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

    print('✏️ Editando comentario $commentId');

    await db.update(
      'comments',
      {'content': newContent},
      where: 'id = ?',
      whereArgs: [commentId],
    );

    if (await _isOnline()) {
      try {
        final response = await http.put(
          Uri.parse('$baseUrl/updateComment/$commentId'),
          headers: {
            'Content-Type': 'application/json',
            'X-User-Id': currentUserId,
          },
          body: jsonEncode({'content': newContent}),
        );
        print(
            '📥 Respuesta updateComment: ${response.statusCode} - ${response.body}');
      } catch (e) {
        print('❌ API error updateComment: $e');
      }
    }
  }
}
