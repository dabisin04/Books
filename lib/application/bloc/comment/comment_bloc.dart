import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/interaction/comment.dart';
import '../../../domain/ports/interaction/comment_repository.dart';
import 'comment_event.dart';
import 'comment_state.dart';

class CommentBloc extends Bloc<CommentEvent, CommentState> {
  final CommentRepository commentRepository;

  CommentBloc(this.commentRepository) : super(CommentInitial()) {
    on<AddComment>(_onAddComment);
    on<DeleteComment>(_onDeleteComment);
    on<UpdateComment>(_onUpdateComment);
    on<FetchCommentsByBook>(_onFetchCommentsByBook);
    on<FetchReplies>(_onFetchReplies);
  }

  Future<void> _onAddComment(
      AddComment event, Emitter<CommentState> emit) async {
    try {
      await commentRepository.addComment(event.comment);
      emit(CommentAdded(event.comment));
    } catch (e, stackTrace) {
      debugPrint('Error in _onAddComment: $e\n$stackTrace');
      emit(CommentError('Error al agregar comentario: $e'));
    }
  }

  Future<void> _onDeleteComment(
      DeleteComment event, Emitter<CommentState> emit) async {
    try {
      await commentRepository.deleteComment(event.commentId);
      emit(CommentDeleted(event.commentId));
    } catch (e, stackTrace) {
      debugPrint('Error in _onDeleteComment: $e\n$stackTrace');
      emit(CommentError('Error al eliminar comentario: $e'));
    }
  }

  Future<void> _onUpdateComment(
      UpdateComment event, Emitter<CommentState> emit) async {
    try {
      await commentRepository.updateComment(event.commentId, event.newContent);
      emit(CommentUpdated(
        Comment(
          id: event.commentId,
          userId: '',
          bookId: '',
          content: event.newContent,
          timestamp: DateTime.now().toIso8601String(),
        ),
      ));
    } catch (e, stackTrace) {
      debugPrint('Error in _onUpdateComment: $e\n$stackTrace');
      emit(CommentError('Error al actualizar comentario: $e'));
    }
  }

  Future<void> _onFetchCommentsByBook(
      FetchCommentsByBook event, Emitter<CommentState> emit) async {
    try {
      emit(CommentLoading());
      final comments =
          await commentRepository.fetchCommentsByBook(event.bookId);
      emit(CommentLoaded(comments));
    } catch (e, stackTrace) {
      debugPrint('Error in _onFetchCommentsByBook: $e\n$stackTrace');
      emit(CommentError('Error al obtener comentarios: $e'));
    }
  }

  Future<void> _onFetchReplies(
      FetchReplies event, Emitter<CommentState> emit) async {
    try {
      emit(CommentLoading());
      final replies = await commentRepository.fetchReplies(event.commentId);
      emit(RepliesLoaded(replies));
    } catch (e, stackTrace) {
      debugPrint('Error in _onFetchReplies: $e\n$stackTrace');
      emit(CommentError('Error al obtener respuestas: $e'));
    }
  }
}
