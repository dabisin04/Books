import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:books/domain/entities/interaction/comment.dart';
import 'package:books/application/bloc/comment/comment_bloc.dart';
import 'package:books/application/bloc/comment/comment_event.dart';
import 'package:books/application/bloc/comment/comment_state.dart';
import 'package:books/application/bloc/user/user_bloc.dart';
import 'package:books/application/bloc/user/user_state.dart';

class CommentsModal extends StatefulWidget {
  final String bookId;
  const CommentsModal({Key? key, required this.bookId}) : super(key: key);

  @override
  _CommentsModalState createState() => _CommentsModalState();
}

class _CommentsModalState extends State<CommentsModal> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<CommentBloc>().add(FetchCommentsByBook(widget.bookId));
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isNotEmpty) {
      final currentUserState = context.read<UserBloc>().state;
      if (currentUserState is UserAuthenticated) {
        final comment = Comment(
          userId: currentUserState.user.id,
          bookId: widget.bookId,
          content: text,
          timestamp: DateTime.now().toIso8601String(),
        );
        context.read<CommentBloc>().add(AddComment(comment));
        _commentController.clear();
        context.read<CommentBloc>().add(FetchCommentsByBook(widget.bookId));
      }
    }
  }

  void _editComment(Comment comment) {
    _commentController.text = comment.content;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Editar comentario"),
          content: TextField(
            controller: _commentController,
            decoration: const InputDecoration(hintText: "Nuevo contenido"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final newText = _commentController.text.trim();
                if (newText.isNotEmpty) {
                  context
                      .read<CommentBloc>()
                      .add(UpdateComment(comment.id, newText));
                  Navigator.pop(context);
                  context
                      .read<CommentBloc>()
                      .add(FetchCommentsByBook(widget.bookId));
                }
              },
              child: const Text("Guardar"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
          ],
        );
      },
    );
  }

  void _deleteComment(Comment comment) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Eliminar comentario"),
          content: const Text("¿Estás seguro de eliminar este comentario?"),
          actions: [
            TextButton(
              onPressed: () {
                context.read<CommentBloc>().add(DeleteComment(comment.id));
                Navigator.pop(context);
                context
                    .read<CommentBloc>()
                    .add(FetchCommentsByBook(widget.bookId));
              },
              child: const Text("Eliminar"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
          ],
        );
      },
    );
  }

  void _showReplyDialog(Comment parentComment) {
    final replyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Responder comentario"),
          content: TextField(
            controller: replyController,
            decoration: const InputDecoration(hintText: "Escribe tu respuesta"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final text = replyController.text.trim();
                if (text.isNotEmpty) {
                  final currentUserState = context.read<UserBloc>().state;
                  if (currentUserState is UserAuthenticated) {
                    final reply = Comment(
                      userId: currentUserState.user.id,
                      bookId: widget.bookId,
                      content: text,
                      timestamp: DateTime.now().toIso8601String(),
                      parentCommentId: parentComment.id,
                    );
                    context.read<CommentBloc>().add(AddComment(reply));
                    Navigator.pop(context);
                    context
                        .read<CommentBloc>()
                        .add(FetchCommentsByBook(widget.bookId));
                  }
                }
              },
              child: const Text("Enviar"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
          ],
        );
      },
    );
  }

  String _formatTimestamp(String isoTimestamp) {
    try {
      final date = DateTime.parse(isoTimestamp);
      return DateFormat("dd/MM/yy 'a las' HH:mm").format(date);
    } catch (e) {
      return isoTimestamp;
    }
  }

  Widget _buildCommentTree(
      List<Comment> comments, String? parentId, int level) {
    final indent = level * 20.0;
    return Column(
      children: comments
          .where((c) => c.parentCommentId == parentId)
          .map((comment) => Padding(
                padding: EdgeInsets.only(left: indent),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        child:
                            Text(comment.userId.substring(0, 1).toUpperCase()),
                      ),
                      title: Text(
                        comment.content,
                        style: const TextStyle(
                          fontWeight: FontWeight.normal,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        _formatTimestamp(comment.timestamp),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (comment.userId ==
                              (context.watch<UserBloc>().state
                                      as UserAuthenticated?)
                                  ?.user
                                  .id)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'editar') {
                                  _editComment(comment);
                                } else if (value == 'eliminar') {
                                  _deleteComment(comment);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'editar',
                                  child: Text("Editar"),
                                ),
                                const PopupMenuItem(
                                  value: 'eliminar',
                                  child: Text("Eliminar"),
                                ),
                              ],
                            ),
                          IconButton(
                            icon: const Icon(Icons.reply),
                            onPressed: () => _showReplyDialog(comment),
                          ),
                        ],
                      ),
                    ),
                    _buildCommentTree(comments, comment.id, level + 1),
                  ],
                ),
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const Text(
                    "Comentarios",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: BlocBuilder<CommentBloc, CommentState>(
                      builder: (context, state) {
                        if (state is CommentLoading) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (state is CommentLoaded) {
                          final comments = state.comments;
                          if (comments.isEmpty) {
                            return const Center(
                                child: Text("No hay comentarios aún."));
                          }
                          return SingleChildScrollView(
                            controller: scrollController,
                            child: _buildCommentTree(comments, null, 0),
                          );
                        } else if (state is CommentError) {
                          return Center(child: Text(state.message));
                        } else if (state is CommentAdded ||
                            state is CommentUpdated ||
                            state is CommentDeleted) {
                          // Mientras se recarga la lista, mostrar un indicador de carga
                          context
                              .read<CommentBloc>()
                              .add(FetchCommentsByBook(widget.bookId));
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: "Escribe un comentario...",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _submitComment,
                      ),
                    ),
                    onSubmitted: (_) => _submitComment(),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
