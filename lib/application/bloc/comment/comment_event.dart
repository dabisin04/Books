import 'package:equatable/equatable.dart';
import '../../../domain/entities/interaction/comment.dart';

abstract class CommentEvent extends Equatable {
  const CommentEvent();

  @override
  List<Object?> get props => [];
}

class AddComment extends CommentEvent {
  final Comment comment;

  const AddComment(this.comment);

  @override
  List<Object?> get props => [comment];
}

class DeleteComment extends CommentEvent {
  final String commentId;

  const DeleteComment(this.commentId);

  @override
  List<Object?> get props => [commentId];
}

class UpdateComment extends CommentEvent {
  final String commentId;
  final String newContent;

  const UpdateComment(this.commentId, this.newContent);

  @override
  List<Object?> get props => [commentId, newContent];
}

class FetchCommentsByBook extends CommentEvent {
  final String bookId;

  const FetchCommentsByBook(this.bookId);

  @override
  List<Object?> get props => [bookId];
}

class FetchReplies extends CommentEvent {
  final String commentId;

  const FetchReplies(this.commentId);

  @override
  List<Object?> get props => [commentId];
}

class LoadComments extends CommentEvent {
  final List<Comment> comments;

  const LoadComments(this.comments);

  @override
  List<Object?> get props => [comments];
}
