import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/interaction/comment.dart';
import '../../domain/ports/interaction/comment_repository.dart';
import '../database/database_helper.dart';
import '../utils/shared_prefs_helper.dart';

class CommentRepositoryImpl implements CommentRepository {
  final SharedPrefsService sharedPrefs;
  CommentRepositoryImpl(this.sharedPrefs);

  Future<Database> get _database async =>
      await DatabaseHelper.instance.database;

  static const String cacheKey = 'cached_comments';

  String? getCurrentUserId() {
    return sharedPrefs.getValue<String>('user_id');
  }

  @override
  Future<void> addComment(Comment comment) async {
    final db = await DatabaseHelper.instance.database;

    comment = comment.copyWith(id: comment.id ?? const Uuid().v4());

    final rootCommentId = (comment.parentCommentId == null)
        ? null
        : (await db.query(
              'comments',
              columns: ['root_comment_id'],
              where: 'id = ?',
              whereArgs: [comment.parentCommentId],
            ))
                .firstOrNull?['root_comment_id'] as String? ??
            comment.parentCommentId;

    await db.insert('comments', {
      'id': comment.id,
      'user_id': comment.userId,
      'book_id': comment.bookId,
      'content': comment.content,
      'timestamp': comment.timestamp,
      'parent_comment_id': comment.parentCommentId,
      'root_comment_id': rootCommentId,
      'reports': comment.reports,
    });
  }

  @override
  Future<void> deleteComment(String commentId) async {
    final db = await _database;
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) {
      throw Exception("Error: Usuario no autenticado.");
    }
    final List<Map<String, dynamic>> result = await db.query(
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
    await db.delete('comments', where: 'id = ?', whereArgs: [commentId]);
  }

  @override
  Future<List<Comment>> fetchCommentsByBook(String bookId) async {
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
    final List<Map<String, dynamic>> result = await db.query(
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
    await db.update(
      'comments',
      {'content': newContent},
      where: 'id = ?',
      whereArgs: [commentId],
    );
  }
}
