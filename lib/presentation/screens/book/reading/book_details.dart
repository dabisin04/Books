// ignore_for_file: library_private_types_in_public_api, no_leading_underscores_for_local_identifiers
import 'dart:math';
import 'package:books/application/bloc/favorite/favorite_bloc.dart';
import 'package:books/application/bloc/favorite/favorite_event.dart';
import 'package:books/application/bloc/favorite/favorite_state.dart';
import 'package:books/presentation/screens/book/writing/write_book_chapter.dart';
import 'package:books/presentation/widgets/book/book_options.dart';
import 'package:books/presentation/widgets/book/novel_options.dart';
import 'package:books/presentation/widgets/book/rating_modal.dart';
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

    final userState = context.read<UserBloc>().state;
    if (userState is UserAuthenticated) {
      context.read<FavoriteBloc>().add(LoadFavoritesEvent(userState.user.id));
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
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'report') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text("Funcionalidad de reporte próximamente")),
                    );
                  } else if (value == 'favorite') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Añadido a favoritos (simulado)")),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'report',
                    child: Text('Reportar'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'favorite',
                    child: Text('Añadir a favoritos'),
                  ),
                ],
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
                              GestureDetector(
                                child: const Icon(Icons.star,
                                    color: Colors.yellow, size: 20),
                                onTap: () => showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  isScrollControlled: true,
                                  builder: (_) =>
                                      RatingModal(bookId: widget.book.id),
                                ),
                              ),
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
                              const SizedBox(width: 12),
                              BlocConsumer<FavoriteBloc, FavoriteState>(
                                listener: (context, favState) {},
                                builder: (context, favState) {
                                  final userState =
                                      context.read<UserBloc>().state;
                                  if (userState is! UserAuthenticated)
                                    return const SizedBox();
                                  final userId = userState.user.id;

                                  final isFav = favState is FavoriteLoaded &&
                                      favState.favoriteBookIds
                                          .contains(widget.book.id);

                                  return IconButton(
                                    icon: Icon(
                                      isFav
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      final favBloc =
                                          context.read<FavoriteBloc>();
                                      if (isFav) {
                                        favBloc.add(RemoveFavoriteEvent(
                                            userId, widget.book.id));
                                      } else {
                                        favBloc.add(AddFavoriteEvent(
                                            userId, widget.book.id));
                                      }
                                    },
                                  );
                                },
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
                  widget.book.has_chapters
                      ? const SizedBox.shrink()
                      : Center(
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
                  if (widget.book.has_chapters) ...[
                    const Text(
                      'Capítulos',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    StatefulBuilder(
                      builder: (context, setState) {
                        return BlocBuilder<ChapterBloc, ChapterState>(
                          builder: (context, state) {
                            if (state is ChapterLoading) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            } else if (state is ChapterLoaded) {
                              final chapters = state.chapters;
                              if (chapters.isEmpty) {
                                return const Text(
                                    "No se encontraron capítulos.");
                              }
                              int _visibleChapterCount = 3;
                              final visibleChapters =
                                  chapters.take(_visibleChapterCount).toList();
                              return Column(
                                children: [
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: visibleChapters.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(),
                                    itemBuilder: (context, index) {
                                      final chapter = visibleChapters[index];
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
                                                    icon:
                                                        const Icon(Icons.edit),
                                                    onPressed: () =>
                                                        _editChapter(chapter),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.delete),
                                                    onPressed: () =>
                                                        _deleteChapter(chapter),
                                                  ),
                                                ],
                                              )
                                            : null,
                                      );
                                    },
                                  ),
                                  if (_visibleChapterCount < chapters.length)
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _visibleChapterCount =
                                              chapters.length;
                                        });
                                      },
                                      child: const Text("Cargar más capítulos"),
                                    ),
                                ],
                              );
                            } else {
                              return const Center(
                                  child: Text("Error al cargar capítulos."));
                            }
                          },
                        );
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
