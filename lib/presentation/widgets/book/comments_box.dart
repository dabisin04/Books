// ignore_for_file: library_private_types_in_public_api, use_super_parameters, curly_braces_in_flow_control_structures
import 'dart:math';
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
    if (_commentMode == CommentMode.add) {
      final comment = Comment(
        userId: currentUserState.user.id,
        bookId: widget.book.id,
        content: text,
        timestamp: DateTime.now().toIso8601String(),
      );
      context.read<CommentBloc>().add(AddComment(comment));
    } else if (_commentMode == CommentMode.edit && _targetCommentId != null) {
      context.read<CommentBloc>().add(UpdateComment(_targetCommentId!, text));
    } else if (_commentMode == CommentMode.reply && _targetCommentId != null) {
      final reply = Comment(
        userId: currentUserState.user.id,
        bookId: widget.book.id,
        content: text,
        timestamp: DateTime.now().toIso8601String(),
        parentCommentId: _targetCommentId,
      );
      context.read<CommentBloc>().add(AddComment(reply));
    }
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

  String _getUserName(String userId) {
    final userState = context.read<UserBloc>().state;
    if (userState is UserAuthenticated && userState.user.id == userId) {
      return userState.user.username;
    }
    return userId.substring(0, 1).toUpperCase() + userId.substring(1, 5);
  }

  Widget _buildCommentTree(List<Comment> comments,
      {String? parentId, int level = 0}) {
    final double indent = level >= 1 ? 20.0 : 0.0;
    final children =
        comments.where((c) => c.parentCommentId == parentId).toList();
    if (children.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((comment) {
        Comment? parentComment;
        if (comment.parentCommentId != null) {
          try {
            parentComment =
                comments.firstWhere((c) => c.id == comment.parentCommentId);
          } catch (e) {
            parentComment = null;
          }
        }
        final replyText = parentComment != null
            ? "@${_getUserName(parentComment.userId)} ${comment.content}"
            : comment.content;
        final bool isReply = level >= 1;
        final currentUserState = context.watch<UserBloc>().state;
        final bool isAuthor = currentUserState is UserAuthenticated &&
            currentUserState.user.id == comment.userId;
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
                title: CommentAuthor(userId: comment.userId),
                subtitle: Text(
                  isReply ? replyText : comment.content,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => _onCommentAction(value, comment),
                  itemBuilder: (context) {
                    if (isAuthor) {
                      return [
                        const PopupMenuItem(
                          value: 'editar',
                          child: Text("Editar", style: TextStyle(fontSize: 12)),
                        ),
                        const PopupMenuItem(
                          value: 'eliminar',
                          child:
                              Text("Eliminar", style: TextStyle(fontSize: 12)),
                        ),
                        if (level == 0)
                          const PopupMenuItem(
                            value: 'responder',
                            child: Text("Responder",
                                style: TextStyle(fontSize: 12)),
                          ),
                      ];
                    } else {
                      if (level == 0)
                        return [
                          const PopupMenuItem(
                            value: 'responder',
                            child: Text("Responder",
                                style: TextStyle(fontSize: 12)),
                          ),
                        ];
                      return [];
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
                    if (isReply)
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Text(
                          "Respuesta",
                          style:
                              TextStyle(fontSize: 10, color: Colors.blueGrey),
                        ),
                      ),
                  ],
                ),
              ),
              if (level < 1)
                _buildCommentTree(comments,
                    parentId: comment.id, level: level + 1),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CommentBloc, CommentState>(
      listener: (context, state) {
        if (state is CommentAdded ||
            state is CommentUpdated ||
            state is CommentDeleted) {
          context.read<CommentBloc>().add(FetchCommentsByBook(widget.book.id));
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
                return _buildCommentTree(comments);
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
