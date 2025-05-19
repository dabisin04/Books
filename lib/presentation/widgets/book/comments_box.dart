// ignore_for_file: library_private_types_in_public_api, use_super_parameters, curly_braces_in_flow_control_structures
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:books/domain/entities/interaction/comment.dart';
import 'package:books/application/bloc/comment/comment_bloc.dart';
import 'package:books/application/bloc/comment/comment_event.dart';
import 'package:books/application/bloc/comment/comment_state.dart';
import 'package:books/application/bloc/user/user_bloc.dart';
import 'package:books/application/bloc/user/user_state.dart';
import 'package:books/presentation/widgets/book/comment_author.dart';

enum CommentMode { add, edit, reply }

class CommentsBox extends StatefulWidget {
  final dynamic book;
  const CommentsBox({Key? key, required this.book}) : super(key: key);

  @override
  _CommentsBoxState createState() => _CommentsBoxState();
}

class _CommentsBoxState extends State<CommentsBox> {
  final TextEditingController _commentController = TextEditingController();
  CommentMode _commentMode = CommentMode.add;
  String? _targetCommentId;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    final comments = await context
        .read<CommentBloc>()
        .commentRepository
        .fetchCommentsByBook(widget.book.id);
    if (mounted) {
      context.read<CommentBloc>().add(LoadComments(comments));
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _cancelCommentMode() {
    setState(() {
      _commentMode = CommentMode.add;
      _targetCommentId = null;
      _commentController.clear();
    });
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final currentUserState = context.read<UserBloc>().state;
    if (currentUserState is! UserAuthenticated) return;

    final comment = Comment(
      userId: currentUserState.user.id,
      bookId: widget.book.id,
      content: text,
      timestamp: DateTime.now().toIso8601String(),
      parentCommentId:
          _commentMode == CommentMode.reply ? _targetCommentId : null,
      rootCommentId:
          _commentMode == CommentMode.reply ? _targetCommentId : null,
    );

    context.read<CommentBloc>().add(AddComment(comment));
    _cancelCommentMode();
  }

  void _onCommentAction(String action, Comment comment) {
    if (action == 'editar') {
      setState(() {
        _commentMode = CommentMode.edit;
        _targetCommentId = comment.id;
        _commentController.text = comment.content;
      });
    } else if (action == 'eliminar') {
      context.read<CommentBloc>().add(DeleteComment(comment.id));
    } else if (action == 'responder') {
      setState(() {
        _commentMode = CommentMode.reply;
        _targetCommentId = comment.id;
        _commentController.clear();
      });
    }
  }

  String _formatTimestamp(String isoTimestamp) {
    try {
      final date = DateTime.parse(isoTimestamp);
      return DateFormat("dd/MM/yy 'a las' HH:mm").format(date);
    } catch (e) {
      return isoTimestamp;
    }
  }

  Future<String> _getUserName(String userId) async {
    try {
      final userState = context.read<UserBloc>().state;
      if (userState is UserAuthenticated && userState.user.id == userId) {
        return userState.user.username;
      }

      final user =
          await context.read<UserBloc>().userRepository.getUserById(userId);
      return user?.username ?? 'Usuario';
    } catch (e) {
      print('Error obteniendo username: $e');
      return 'Usuario';
    }
  }

  Widget _buildCommentsList(List<Comment> comments) {
    final topLevelComments =
        comments.where((c) => c.parentCommentId == null).toList();
    final Map<String, List<Comment>> repliesByRoot = {};

    for (var comment in comments) {
      if (comment.parentCommentId != null) {
        final rootId = comment.rootCommentId ?? comment.parentCommentId!;
        repliesByRoot.putIfAbsent(rootId, () => []).add(comment);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: topLevelComments.map((topComment) {
        final replies = repliesByRoot[topComment.id] ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCommentTile(topComment, indent: 0),
            ...replies.map((reply) => FutureBuilder<String>(
                  future: _getUserName(topComment.userId),
                  builder: (context, snapshot) {
                    return _buildCommentTile(
                      reply,
                      indent: 20,
                      prefixUsername: snapshot.data,
                    );
                  },
                )),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCommentTile(Comment comment,
      {double indent = 0, String? prefixUsername}) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.only(left: 16.0, right: 8.0),
            leading: CircleAvatar(
              child: Text(
                comment.userId.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            title: FutureBuilder<String>(
              future: _getUserName(comment.userId),
              builder: (context, snapshot) {
                return Text(
                  snapshot.data ?? 'Usuario',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                );
              },
            ),
            subtitle: Text(
              prefixUsername != null
                  ? "@$prefixUsername ${comment.content}"
                  : comment.content,
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _onCommentAction(value, comment),
              itemBuilder: (context) {
                final currentUserState = context.read<UserBloc>().state;
                final bool isAuthor = currentUserState is UserAuthenticated &&
                    currentUserState.user.id == comment.userId;

                if (isAuthor) {
                  return [
                    const PopupMenuItem(
                      value: 'editar',
                      child: Text("Editar", style: TextStyle(fontSize: 12)),
                    ),
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: Text("Eliminar", style: TextStyle(fontSize: 12)),
                    ),
                    const PopupMenuItem(
                      value: 'responder',
                      child: Text("Responder", style: TextStyle(fontSize: 12)),
                    ),
                  ];
                } else {
                  return [
                    const PopupMenuItem(
                      value: 'responder',
                      child: Text("Responder", style: TextStyle(fontSize: 12)),
                    ),
                  ];
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 72.0, bottom: 4.0),
            child: Row(
              children: [
                Text(
                  _formatTimestamp(comment.timestamp),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (comment.parentCommentId != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text(
                      "Respuesta",
                      style: TextStyle(fontSize: 10, color: Colors.blueGrey),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CommentBloc, CommentState>(
      listener: (context, state) {
        if (state is CommentAdded) {
          // No recargamos todos los comentarios, solo añadimos el nuevo
          final currentState = context.read<CommentBloc>().state;
          if (currentState is CommentLoaded) {
            final updatedComments = List<Comment>.from(currentState.comments);
            updatedComments.add(state.comment);
            context.read<CommentBloc>().add(LoadComments(updatedComments));
          }
        } else if (state is CommentDeleted || state is CommentUpdated) {
          _loadComments(); // Solo recargamos si se elimina o actualiza
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_commentMode != CommentMode.add)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Text(
                    _commentMode == CommentMode.edit
                        ? "Editando comentario"
                        : "Respondiendo a comentario",
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.blue),
                    onPressed: _cancelCommentMode,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 16),
          BlocBuilder<CommentBloc, CommentState>(
            builder: (context, state) {
              if (state is CommentLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is CommentLoaded) {
                final comments = state.comments;
                if (comments.isEmpty) {
                  return const Center(child: Text("No hay comentarios aún."));
                }
                return _buildCommentsList(comments);
              } else if (state is CommentError) {
                return Center(child: Text(state.message));
              }
              return const SizedBox();
            },
          ),
        ],
      ),
    );
  }
}
