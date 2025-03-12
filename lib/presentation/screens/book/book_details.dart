import 'dart:math';
import 'package:flutter/material.dart';
import 'package:books/presentation/widgets/global/custom_button.dart';
import 'package:books/domain/entities/book/book.dart';

class BookDetailsScreen extends StatefulWidget {
  final Book book;
  const BookDetailsScreen({super.key, required this.book});

  @override
  _BookDetailsScreenState createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  bool _descriptionExpanded = false;
  bool _showFullComments = false;
  final ScrollController _scrollController = ScrollController();

  // Genera un degradado aleatorio para el banner
  LinearGradient _generateRandomGradient() {
    final random = Random();
    Color randomColor() => Color.fromARGB(
          255,
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
    final color1 = randomColor();
    final color2 = randomColor();
    final begin =
        Alignment(random.nextDouble() * 2 - 1, random.nextDouble() * 2 - 1);
    final end = Alignment(-begin.x, -begin.y);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [color1, color2],
    );
  }

  void _toggleDescription() {
    setState(() {
      _descriptionExpanded = !_descriptionExpanded;
    });
  }

  void _toggleComments() {
    setState(() {
      _showFullComments = !_showFullComments;
      if (_showFullComments) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    });
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.thumb_down),
              title: const Text('No me interesa'),
              onTap: () {
                Navigator.pop(context);
                // Lógica para "no me interesa"
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Reportar'),
              onTap: () {
                Navigator.pop(context);
                // Lógica para reportar
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                onPressed: _showOptions,
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
                          "Autor: ${widget.book.authorId}",
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
                              onPressed: () {
                                // Acción para calificar el libro
                              },
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
                        // Navegar a la pantalla de lectura (modal) cuando se implemente
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Comentarios',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      const ListTile(
                        leading: CircleAvatar(child: Text('A')),
                        title: Text('Comentario 1'),
                        subtitle: Text('Muy interesante la trama.'),
                      ),
                      const ListTile(
                        leading: CircleAvatar(child: Text('B')),
                        title: Text('Comentario 2'),
                        subtitle: Text('Me encantó la narrativa.'),
                      ),
                      const ListTile(
                        leading: CircleAvatar(child: Text('C')),
                        title: Text('Comentario 3'),
                        subtitle: Text('Recomiendo este libro.'),
                      ),
                      if (_showFullComments)
                        const Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(child: Text('D')),
                              title: Text('Comentario 4'),
                              subtitle: Text('Un clásico renovado.'),
                            ),
                            ListTile(
                              leading: CircleAvatar(child: Text('E')),
                              title: Text('Comentario 5'),
                              subtitle: Text('Muy bien escrito.'),
                            ),
                            ListTile(
                              leading: CircleAvatar(child: Text('F')),
                              title: Text('Comentario 6'),
                              subtitle: Text('Me dejó pensando.'),
                            ),
                          ],
                        ),
                      Center(
                        child: TextButton(
                          onPressed: _toggleComments,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue,
                          ),
                          child: Text(
                            _showFullComments
                                ? 'Mostrar menos comentarios'
                                : 'Cargar más comentarios',
                            style: const TextStyle(
                                decoration: TextDecoration.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
