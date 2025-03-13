import '../../entities/interaction/comment.dart';

abstract class CommentRepository {
  Future<void> addComment(Comment comment);
  Future<void> deleteComment(String commentId);
  Future<List<Comment>> fetchCommentsByBook(String bookId);
  Future<List<Comment>> fetchReplies(String commentId);
  Future<void> updateComment(String commentId, String newContent);
}
