// ignore_for_file: library_private_types_in_public_api
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:books/application/bloc/comment/comment_bloc.dart';
import 'package:books/application/bloc/comment/comment_event.dart';
import 'package:books/application/bloc/user/user_bloc.dart';
import 'package:books/application/bloc/user/user_state.dart';
import 'package:books/presentation/screens/book/write_book.dart';
import '../../widgets/book/comments_box.dart';
import '../../widgets/global/custom_button.dart';

class BookDetailsScreen extends StatefulWidget {
  final dynamic book;
  const BookDetailsScreen({super.key, required this.book});

  @override
  _BookDetailsScreenState createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  bool _descriptionExpanded = false;
  final ScrollController _scrollController = ScrollController();
  String? _authorName;

  @override
  void initState() {
    super.initState();
    _fetchAuthorName();
    context.read<CommentBloc>().add(FetchCommentsByBook(widget.book.id));
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

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserBloc>().state;
    final bool isAuthor = userState is UserAuthenticated &&
        userState.user.id == widget.book.authorId;
    return Scaffold(
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
