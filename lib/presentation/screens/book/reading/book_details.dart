// ignore_for_file: library_private_types_in_public_api
import 'dart:math';
import 'package:books/presentation/screens/book/writing/write_book_chapter.dart';
import 'package:books/presentation/widgets/book/book_options.dart';
import 'package:books/presentation/widgets/book/novel_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:books/application/bloc/comment/comment_bloc.dart';
import 'package:books/application/bloc/comment/comment_event.dart';
import 'package:books/application/bloc/user/user_bloc.dart';
import 'package:books/application/bloc/user/user_state.dart';
import 'package:books/application/bloc/chapter/chapter_bloc.dart';
import 'package:books/application/bloc/chapter/chapter_state.dart';
import 'package:books/application/bloc/chapter/chapter_event.dart';
import 'package:books/domain/entities/book/book.dart';
import 'package:books/domain/entities/book/chapter.dart';
import '../../../widgets/book/comments_box.dart';
import '../../../widgets/global/custom_button.dart';

class BookDetailsScreen extends StatefulWidget {
  final Book book;
  const BookDetailsScreen({super.key, required this.book});

  @override
  _BookDetailsScreenState createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  bool _descriptionExpanded = false;
  final ScrollController _scrollController = ScrollController();
  String? _authorName;
  Chapter? _recentlyDeletedChapter;

  @override
  void initState() {
    super.initState();
    _fetchAuthorName();
    context.read<CommentBloc>().add(FetchCommentsByBook(widget.book.id));
    if (widget.book.has_chapters) {
      context.read<ChapterBloc>().add(LoadChaptersByBook(widget.book.id));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

  void _deleteChapter(Chapter chapter) {
    _recentlyDeletedChapter = chapter;
    context
        .read<ChapterBloc>()
        .add(DeleteChapterEvent(chapter.id, widget.book.id));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Capítulo '${chapter.title}' eliminado"),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: "Deshacer",
          onPressed: () {
            if (_recentlyDeletedChapter != null) {
              context
                  .read<ChapterBloc>()
                  .add(AddChapterEvent(_recentlyDeletedChapter!));
              _recentlyDeletedChapter = null;
            }
          },
        ),
      ),
    );
  }

  void _editChapter(Chapter chapter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WriteChapterScreen(
          book: widget.book,
          chapter: chapter,
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(bool isAuthor) {
    if (!isAuthor) return const SizedBox();
    if (widget.book.has_chapters) {
      return FloatingActionButton(
        mini: true,
        backgroundColor: Colors.redAccent[100],
        child: Image.asset("images/pluma.png",
            width: 20, height: 20, color: Colors.white),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => NovelOptionsModal(book: widget.book),
          );
        },
      );
    } else {
      return FloatingActionButton(
        mini: true,
        backgroundColor: Colors.redAccent[100],
        child: Image.asset("images/pluma.png",
            width: 20, height: 20, color: Colors.white),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => BookOptions(book: widget.book),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserBloc>().state;
    final bool isAuthor = userState is UserAuthenticated &&
        userState.user.id == widget.book.authorId;
    return Scaffold(
      floatingActionButton: _buildFloatingActionButton(isAuthor),
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
                        if (!widget.book.has_chapters) ...[
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
                              const Icon(Icons.remove_red_eye,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                widget.book.views.toString(),
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                            ],
                          )
                        ],
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
                    onTap: () => setState(
                        () => _descriptionExpanded = !_descriptionExpanded),
                    child: AnimatedCrossFade(
                      firstChild: Text(
                        widget.book.description ?? "Sin sinopsis disponible",
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      secondChild: Text(
                          widget.book.description ?? "Sin sinopsis disponible"),
                      crossFadeState: _descriptionExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: CustomButton(
                      text: widget.book.has_chapters
                          ? 'Ver Capítulos'
                          : 'Leer Libro',
                      onPressed: () {
                        if (widget.book.has_chapters) {
                        } else {
                          Navigator.pushNamed(
                            context,
                            '/read_content',
                            arguments: widget.book,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (widget.book.has_chapters) ...[
                    const Text(
                      'Capítulos',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    BlocBuilder<ChapterBloc, ChapterState>(
                      builder: (context, state) {
                        if (state is ChapterLoading) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (state is ChapterLoaded) {
                          final chapters = state.chapters;
                          if (chapters.isEmpty) {
                            return const Text("No se encontraron capítulos.");
                          }
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: chapters.length,
                            separatorBuilder: (context, index) =>
                                const Divider(),
                            itemBuilder: (context, index) {
                              final chapter = chapters[index];
                              return ListTile(
                                title: Text(
                                    "Capítulo ${chapter.chapterNumber}: ${chapter.title}"),
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/read_content',
                                    arguments: chapter,
                                  );
                                },
                                trailing: isAuthor
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () =>
                                                _editChapter(chapter),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed: () =>
                                                _deleteChapter(chapter),
                                          ),
                                        ],
                                      )
                                    : null,
                              );
                            },
                          );
                        } else {
                          return const Center(
                              child: Text("Error al cargar capítulos."));
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Comentarios',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  CommentsBox(book: widget.book),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
