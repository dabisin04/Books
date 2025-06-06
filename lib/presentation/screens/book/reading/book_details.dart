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
import 'package:books/application/bloc/book/book_bloc.dart';
import 'package:books/application/bloc/chapter/chapter_bloc.dart';
import 'package:books/application/bloc/chapter/chapter_state.dart';
import 'package:books/application/bloc/chapter/chapter_event.dart';
import 'package:books/domain/entities/book/book.dart';
import 'package:books/domain/entities/book/chapter.dart';
import '../../../widgets/book/comments_box.dart';
import '../../../widgets/global/custom_button.dart';
import 'package:books/application/bloc/report/report_bloc.dart';
import 'package:books/application/bloc/report/report_event.dart';
import 'package:books/domain/entities/interaction/report.dart';

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
  late Book _currentBook;

  @override
  void initState() {
    super.initState();
    _currentBook = widget.book;
    _fetchAuthorName();
    context.read<CommentBloc>().add(FetchCommentsByBook(_currentBook.id));
    if (_currentBook.has_chapters) {
      context.read<ChapterBloc>().add(LoadChaptersByBook(_currentBook.id));
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
    try {
      final userState = context.read<UserBloc>().state;
      if (userState is UserAuthenticated) {
        final user = userState.user;
        if (user.id == _currentBook.authorId) {
          setState(() {
            _authorName = user.username;
          });
          return;
        }
      }

      final author = await context
          .read<UserBloc>()
          .userRepository
          .getUserById(_currentBook.authorId);
      setState(() {
        _authorName = author?.username ?? "Desconocido";
      });
    } catch (e) {
      print('Error obteniendo nombre del autor: $e');
      setState(() {
        _authorName = "Desconocido";
      });
    }
  }

  void _deleteChapter(Chapter chapter) {
    _recentlyDeletedChapter = chapter;
    context
        .read<ChapterBloc>()
        .add(DeleteChapterEvent(chapter.id, _currentBook.id));

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
          book: _currentBook,
          chapter: chapter,
        ),
      ),
    );
  }

  void _reloadBookAfterRating() async {
    final updatedBook = await context
        .read<BookBloc>()
        .bookRepository
        .getBookById(_currentBook.id);
    if (updatedBook != null) {
      setState(() {
        _currentBook = updatedBook;
      });
    }
  }

  void _showReportDialog() {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reportar libro'),
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
            onPressed: () async {
              final userState = context.read<UserBloc>().state;
              if (userState is UserAuthenticated) {
                // Obtener el usuario actualizado para asegurar que tenemos el ID correcto
                final currentUser = await context
                    .read<UserBloc>()
                    .userRepository
                    .getUserById(userState.user.id);
                if (currentUser == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error: Usuario no encontrado'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                final report = Report(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  reporterId: currentUser.id,
                  targetId: _currentBook.id,
                  targetType: 'book',
                  reason: reasonController.text.trim(),
                  status: 'pending',
                  timestamp: DateTime.now(),
                );

                print(
                    '📝 Creando reporte con ID de usuario: ${currentUser.id}');
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

  Widget _buildFloatingActionButton(bool isAuthor) {
    if (!isAuthor) return const SizedBox();
    if (_currentBook.has_chapters) {
      return FloatingActionButton(
        mini: true,
        backgroundColor: Colors.redAccent[100],
        child: Image.asset("images/pluma.png",
            width: 20, height: 20, color: Colors.white),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => NovelOptionsModal(book: _currentBook),
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
            builder: (context) => BookOptions(book: _currentBook),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserBloc>().state;
    final bool isAuthor = userState is UserAuthenticated &&
        userState.user.id == _currentBook.authorId;
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
                    _showReportDialog();
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
                tag: _currentBook.id,
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
                          _currentBook.title,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final userState = context.read<UserBloc>().state;
                            if (userState is UserAuthenticated) {
                              final user = userState.user;
                              if (user.id != _currentBook.authorId) {
                                final author = await context
                                    .read<UserBloc>()
                                    .userRepository
                                    .getUserById(_currentBook.authorId);
                                if (author != null && mounted) {
                                  Navigator.pushNamed(
                                    context,
                                    '/public_profile',
                                    arguments: author,
                                  );
                                }
                              }
                            }
                          },
                          child: Text(
                            "Autor: ${_authorName ?? 'Cargando...'}",
                            style: const TextStyle(
                                fontSize: 16, color: Colors.white70),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!_currentBook.has_chapters) ...[
                          Row(
                            children: [
                              GestureDetector(
                                child: const Icon(Icons.star,
                                    color: Colors.yellow, size: 20),
                                onTap: () => showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  isScrollControlled: true,
                                  builder: (_) => RatingModal(
                                    bookId: _currentBook.id,
                                    onRated:
                                        _reloadBookAfterRating, // ← Aquí lo pasas
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _currentBook.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              const Icon(Icons.remove_red_eye,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                _currentBook.views.toString(),
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
                                          .contains(_currentBook.id);

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
                                            userId, _currentBook.id));
                                      } else {
                                        favBloc.add(AddFavoriteEvent(
                                            userId, _currentBook.id));
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
                        _currentBook.description ?? "Sin sinopsis disponible",
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      secondChild: Text(_currentBook.description ??
                          "Sin sinopsis disponible"),
                      crossFadeState: _descriptionExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_currentBook.has_chapters) ...[
                    Center(
                      child: CustomButton(
                        text: 'Leer Libro',
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/read_content',
                            arguments: _currentBook,
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_currentBook.has_chapters) ...[
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
                  CommentsBox(book: _currentBook),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
