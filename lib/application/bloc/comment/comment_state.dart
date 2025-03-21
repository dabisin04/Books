import 'package:equatable/equatable.dart';
import '../../../domain/entities/interaction/comment.dart';

abstract class CommentState extends Equatable {
  const CommentState();

  @override
  List<Object?> get props => [];
}

class CommentInitial extends CommentState {}

class CommentLoading extends CommentState {}

class CommentLoaded extends CommentState {
  final List<Comment> comments;

  const CommentLoaded(this.comments);

  @override
  List<Object?> get props => [comments];
}

class CommentError extends CommentState {
  final String message;

  const CommentError(this.message);

  @override
  List<Object?> get props => [message];
}

class CommentAdded extends CommentState {
  final Comment comment;

  const CommentAdded(this.comment);

  @override
  List<Object?> get props => [comment];
}

class CommentDeleted extends CommentState {
  final String commentId;

  const CommentDeleted(this.commentId);

  @override
  List<Object?> get props => [commentId];
}

class CommentUpdated extends CommentState {
  final Comment comment;

  const CommentUpdated(this.comment);

  @override
  List<Object?> get props => [comment];
}

class RepliesLoading extends CommentState {}

class RepliesLoaded extends CommentState {
  final List<Comment> replies;

  const RepliesLoaded(this.replies);

  @override
  List<Object?> get props => [replies];
}
