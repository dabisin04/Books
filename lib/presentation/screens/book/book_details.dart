// ignore_for_file: library_private_types_in_public_api

import 'dart:math';
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
import 'package:books/presentation/screens/book/write_book.dart';

import '../../widgets/book/comment_author.dart';
import '../../widgets/global/custom_button.dart';

enum CommentMode { add, edit, reply }

class BookDetailsScreen extends StatefulWidget {
  final dynamic book; // Ajusta el tipo según tu entidad Book
  const BookDetailsScreen({super.key, required this.book});

  @override
  _BookDetailsScreenState createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  bool _descriptionExpanded = false;
  final ScrollController _scrollController = ScrollController();
  String? _authorName;
  final TextEditingController _commentController = TextEditingController();
  CommentMode _commentMode = CommentMode.add;
  String? _targetCommentId;

  @override
  void initState() {
    super.initState();
    _fetchAuthorName();
    context.read<CommentBloc>().add(FetchCommentsByBook(widget.book.id));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  LinearGradient _generateRandomGradient() {
    final random = Random();
    Color randomColor() => Color.fromARGB(
          255,
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [randomColor(), randomColor()],
    );
  }

  void _toggleDescription() {
    setState(() {
      _descriptionExpanded = !_descriptionExpanded;
    });
  }

  Future<void> _fetchAuthorName() async {
    final userState = context.read<UserBloc>().state;
    if (userState is UserAuthenticated) {
      final user = userState.user;
      if (user.id == widget.book.authorId) {
        setState(() {
          _authorName = user.username;
        });
        return;
      }
    }
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _authorName = "Desconocido";
    });
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

  // Función auxiliar para obtener un "nombre" a partir del userId, en caso de no disponer de uno real.
  String _getUserName(String userId) {
    final userState = context.read<UserBloc>().state;
    if (userState is UserAuthenticated && userState.user.id == userId) {
      return userState.user.username;
    }
    return userId.substring(0, 1).toUpperCase() + userId.substring(1, 5);
  }

  /// Construye recursivamente el árbol de comentarios.
  /// Se asume que los comentarios con parentCommentId == null son padres.
  Widget _buildCommentTree(List<Comment> comments,
      {String? parentId, int level = 0}) {
    final double indent = level >= 1 ? 20.0 : 0.0;
    final children =
        comments.where((c) => c.parentCommentId == parentId).toList();
    if (children.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((comment) {
        // Obtener el comentario padre de forma segura, si es que existe.
        Comment? parentComment;
        if (comment.parentCommentId != null) {
          try {
            parentComment =
                comments.firstWhere((c) => c.id == comment.parentCommentId);
          } catch (e) {
            parentComment = null;
          }
        }
        // Si existe, construir un texto que mencione su "nombre" y luego el contenido.
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
                        const PopupMenuItem(
                          value: 'responder',
                          child:
                              Text("Responder", style: TextStyle(fontSize: 12)),
                        ),
                      ];
                    } else {
                      return [
                        const PopupMenuItem(
                          value: 'responder',
                          child:
                              Text("Responder", style: TextStyle(fontSize: 12)),
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
              // Recursión: si level es menor a 1, incrementa; de lo contrario, forzamos nivel 1 para mantener solo dos columnas.
              _buildCommentTree(comments,
                  parentId: comment.id, level: level < 1 ? level + 1 : 1),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserBloc>().state;
    final bool isAuthor = userState is UserAuthenticated &&
        userState.user.id == widget.book.authorId;
    return BlocListener<CommentBloc, CommentState>(
      listener: (context, state) {
        if (state is CommentError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is CommentAdded ||
            state is CommentUpdated ||
            state is CommentDeleted) {
          context.read<CommentBloc>().add(FetchCommentsByBook(widget.book.id));
        }
      },
      child: Scaffold(
        floatingActionButton: isAuthor
            ? FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WriteBookScreen(book: widget.book),
                    ),
                  );
                },
                backgroundColor: Colors.redAccent[100],
                child: Image.asset(
                  'images/pluma.png',
                  width: 24,
                  height: 24,
                  color: Colors.white,
                ),
              )
            : null,
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Hero(
                  tag: widget.book.id,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _generateRandomGradient(),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.book.title,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Autor: ${_authorName ?? 'Cargando...'}",
                            style: const TextStyle(
                                fontSize: 16, color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.yellow, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                widget.book.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white24,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Icon(Icons.star_border,
                                    color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              const Icon(Icons.remove_red_eye,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                widget.book.views.toString(),
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _toggleDescription,
                      child: AnimatedCrossFade(
                        firstChild: Text(
                          widget.book.description ?? "Sin sinopsis disponible",
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        secondChild: Text(widget.book.description ??
                            "Sin sinopsis disponible"),
                        crossFadeState: _descriptionExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 300),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: CustomButton(
                        text: 'Leer Libro',
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/read_content',
                            arguments: widget.book,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Comentarios',
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
                    BlocBuilder<CommentBloc, CommentState>(
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
                          return _buildCommentTree(comments);
                        } else if (state is CommentError) {
                          return Center(child: Text(state.message));
                        }
                        return const SizedBox();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
