// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

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
import 'package:books/application/bloc/report/report_bloc.dart';
import 'package:books/application/bloc/report/report_event.dart';
import 'package:books/domain/entities/interaction/report.dart';

enum CommentMode { add, edit, reply }

class CommentsModal extends StatefulWidget {
  final String targetId; // Puede ser el id del libro o del capítulo
  final String? targetType; // Ejemplo: "book" o "chapter" (opcional)
  const CommentsModal({super.key, required this.targetId, this.targetType});

  @override
  _CommentsModalState createState() => _CommentsModalState();
}

class _CommentsModalState extends State<CommentsModal> {
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
        .fetchCommentsByBook(widget.targetId);
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
      bookId: widget.targetId,
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
        final String key = comment.rootCommentId ?? comment.parentCommentId!;
        repliesByRoot.putIfAbsent(key, () => []).add(comment);
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
    final currentUserState = context.read<UserBloc>().state;
    final bool isAuthor = currentUserState is UserAuthenticated &&
        currentUserState.user.id == comment.userId;

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.only(left: 16.0, right: 8.0),
            leading: GestureDetector(
              onTap: isAuthor
                  ? null
                  : () async {
                      final user = await context
                          .read<UserBloc>()
                          .userRepository
                          .getUserById(comment.userId);
                      if (user != null && mounted) {
                        Navigator.pushNamed(
                          context,
                          '/public_profile',
                          arguments: user,
                        );
                      }
                    },
              child: CircleAvatar(
                child: Text(
                  comment.userId.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            title: GestureDetector(
              onTap: isAuthor
                  ? null
                  : () async {
                      final user = await context
                          .read<UserBloc>()
                          .userRepository
                          .getUserById(comment.userId);
                      if (user != null && mounted) {
                        Navigator.pushNamed(
                          context,
                          '/public_profile',
                          arguments: user,
                        );
                      }
                    },
              child: FutureBuilder<String>(
                future: _getUserName(comment.userId),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? 'Usuario',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  );
                },
              ),
            ),
            subtitle: Text(
              prefixUsername != null
                  ? "@$prefixUsername ${comment.content}"
                  : comment.content,
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'editar') {
                  setState(() {
                    _commentMode = CommentMode.edit;
                    _targetCommentId = comment.id;
                    _commentController.text = comment.content;
                  });
                } else if (value == 'eliminar') {
                  context.read<CommentBloc>().add(DeleteComment(comment.id));
                } else if (value == 'responder') {
                  setState(() {
                    _commentMode = CommentMode.reply;
                    _targetCommentId = comment.id;
                    _commentController.clear();
                  });
                } else if (value == 'reportar') {
                  _showReportDialog(comment);
                }
              },
              itemBuilder: (context) {
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
                    const PopupMenuItem(
                      value: 'reportar',
                      child: Text("Reportar", style: TextStyle(fontSize: 12)),
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

  void _showReportDialog(Comment comment) {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reportar comentario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Por favor, describe el motivo del reporte:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Motivo del reporte...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final userState = context.read<UserBloc>().state;
              if (userState is UserAuthenticated) {
                final report = Report(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  reporterId: userState.user.id,
                  targetId: comment.id,
                  targetType: 'comment',
                  reason: reasonController.text.trim(),
                  status: 'pending',
                  timestamp: DateTime.now(),
                );
                context.read<ReportBloc>().add(SubmitReport(report));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reporte enviado correctamente'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Enviar'),
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
      child: Stack(
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
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
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
                              icon: const Icon(Icons.close,
                                  size: 16, color: Colors.blue),
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
                              child: _buildCommentsList(comments),
                            );
                          } else if (state is CommentError) {
                            return Center(child: Text(state.message));
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
