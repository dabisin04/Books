import '../../entities/interaction/comment.dart';

abstract class CommentRepository {
  Future<void> addComment(Comment comment);
  Future<void> deleteComment(String commentId, String userId);
  Future<List<Comment>> getCommentsByBook(String bookId);
  Future<List<Comment>> getCommentsByUser(String userId);
  Future<void> replyToComment(String parentCommentId, Comment reply);
}
