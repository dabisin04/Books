import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  static const String baseUrl = 'http://172.50.4.230:5000/api';

  CommentRepositoryImpl(this.sharedPrefs);

  String? getCurrentUserId() {
    return sharedPrefs.getValue<String>('user_id');
  }

  Future<bool> _isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _syncLocalData() async {
    if (!await _isOnline()) return;

    final db = await _database;
    final localComments = await db.query('comments');
    for (var commentMap in localComments) {
      final comment = Comment.fromMap(commentMap);
      try {
        // Check if comment exists on server
        final response = await http
            .get(Uri.parse('$baseUrl/commentsByBook/${comment.bookId}'));
        final serverComments = jsonDecode(response.body) as List<dynamic>;
        final exists = serverComments.any((c) => c['id'] == comment.id);

        if (!exists) {
          // Add new comment to server
          await http.post(
            Uri.parse('$baseUrl/addComment'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(comment.toMap()),
          );
        } else {
          // Update existing comment
          await http.put(
            Uri.parse('$baseUrl/updateComment/${comment.id}'),
            headers: {
              'Content-Type': 'application/json',
              'user_id': comment.userId,
            },
            body: jsonEncode({'content': comment.content}),
          );
        }
      } catch (e) {
        // Log error, continue with next comment
        print('Sync error for comment ${comment.id}: $e');
      }
    }
  }

  @override
  Future<void> addComment(Comment comment) async {
    final db = await _database;
    final commentId = comment.id.isEmpty ? const Uuid().v4() : comment.id;
    final newComment = comment.copyWith(id: commentId);

    String? rootCommentId;
    if (newComment.parentCommentId != null) {
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
      'root_comment_id': rootCommentId,
      'reports': newComment.reports,
    };

    if (await _isOnline()) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/addComment'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(commentMap),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to add comment to API');
        }
      } catch (e) {
        // Fallback to SQLite
        await db.insert('comments', commentMap);
      }
    } else {
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

    final result = await db.query(
      'comments',
      where: 'id = ?',
      whereArgs: [commentId],
    );
    if (result.isEmpty) {
      throw Exception("Error: Comentario no encontrado.");
    }
    final comment = Comment.fromMap(result.first);
    if (comment.userId != currentUserId) {
      throw Exception(
          "Error: No se tiene permiso para eliminar este comentario.");
    }

    if (await _isOnline()) {
      try {
        final response = await http.delete(
          Uri.parse('$baseUrl/deleteComment/$commentId'),
          headers: {'user_id': currentUserId},
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to delete comment from API');
        }
      } catch (e) {
        // Fallback to SQLite
        await db.delete('comments', where: 'id = ?', whereArgs: [commentId]);
      }
    } else {
      await db.delete('comments', where: 'id = ?', whereArgs: [commentId]);
    }

    if (await _isOnline()) await _syncLocalData();
  }

  @override
  Future<List<Comment>> fetchCommentsByBook(String bookId) async {
    if (await _isOnline()) {
      try {
        final response =
            await http.get(Uri.parse('$baseUrl/commentsByBook/$bookId'));
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final comments = data.map((map) => Comment.fromMap(map)).toList();
          // Update local SQLite
          final db = await _database;
          await db
              .delete('comments', where: 'book_id = ?', whereArgs: [bookId]);
          for (var comment in comments) {
            await db.insert('comments', comment.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          return comments;
        }
      } catch (e) {
        // Fallback to SQLite
      }
    }

    final db = await _database;
    final List<Map<String, dynamic>> result = await db.query(
      'comments',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    return result.map((map) => Comment.fromMap(map)).toList();
  }

  @override
  Future<List<Comment>> fetchReplies(String commentId) async {
    if (await _isOnline()) {
      try {
        final response =
            await http.get(Uri.parse('$baseUrl/replies/$commentId'));
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final replies = data.map((map) => Comment.fromMap(map)).toList();
          // Update local SQLite
          final db = await _database;
          for (var reply in replies) {
            await db.insert('comments', reply.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          return replies;
        }
      } catch (e) {
        // Fallback to SQLite
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

    final result = await db.query(
      'comments',
      where: 'id = ?',
      whereArgs: [commentId],
    );
    if (result.isEmpty) {
      throw Exception("Error: Comentario no encontrado.");
    }
    final comment = Comment.fromMap(result.first);
    if (comment.userId != currentUserId) {
      throw Exception(
          "Error: No se tiene permiso para actualizar este comentario.");
    }

    if (await _isOnline()) {
      try {
        final response = await http.put(
          Uri.parse('$baseUrl/updateComment/$commentId'),
          headers: {
            'Content-Type': 'application/json',
            'user_id': currentUserId,
          },
          body: jsonEncode({'content': newContent}),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to update comment via API');
        }
      } catch (e) {
        // Fallback to SQLite
        await db.update(
          'comments',
          {'content': newContent},
          where: 'id = ?',
          whereArgs: [commentId],
        );
      }
    } else {
      await db.update(
        'comments',
        {'content': newContent},
        where: 'id = ?',
        whereArgs: [commentId],
      );
    }

    if (await _isOnline()) await _syncLocalData();
  }
}
