import 'package:flutter/material.dart';
import 'package:books/presentation/widgets/global/custom_button.dart';
import 'package:books/domain/entities/book/book.dart';

class BookDetailsScreen extends StatefulWidget {
  final Book book;
  const BookDetailsScreen({Key? key, required this.book}) : super(key: key);

  @override
  _BookDetailsScreenState createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  bool _descriptionExpanded = false;
  bool _showFullComments = false;

  void _toggleDescription() {
    setState(() {
      _descriptionExpanded = !_descriptionExpanded;
    });
  }

  void _toggleComments() {
    setState(() {
      _showFullComments = !_showFullComments;
    });
  }

  // Opciones de la appbar de detalles: "No me interesa" y "Reportar"
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
    // Usamos Hero para la transición (el tag debe ser único, por ejemplo, el id del libro)
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.transparent,
            // Botón para volver y otro para opciones
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
                    gradient: LinearGradient(
                      colors: [Colors.deepPurple, Colors.purpleAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
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
                  // Sinopsis o descripción con opción a expandir
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
                  CustomButton(
                    text: 'Leer Libro',
                    onPressed: () {
                      // Navegar a la pantalla de lectura (donde se muestra el contenido en un modal)
                    },
                  ),
                  const SizedBox(height: 16),
                  // Sección de comentarios (se muestran 3 inicialmente)
                  const Text(
                    'Comentarios',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      // Comentarios de ejemplo
                      ListTile(
                        leading: CircleAvatar(child: Text('A')),
                        title: Text('Comentario 1'),
                        subtitle: Text('Muy interesante la trama.'),
                      ),
                      ListTile(
                        leading: CircleAvatar(child: Text('B')),
                        title: Text('Comentario 2'),
                        subtitle: Text('Me encantó la narrativa.'),
                      ),
                      ListTile(
                        leading: CircleAvatar(child: Text('C')),
                        title: Text('Comentario 3'),
                        subtitle: Text('Recomiendo este libro.'),
                      ),
                    ],
                  ),
                  Center(
                    child: TextButton(
                      onPressed: _toggleComments,
                      child: Text(_showFullComments
                          ? 'Mostrar menos comentarios'
                          : 'Cargar más comentarios'),
                    ),
                  ),
                  // Si se han cargado más comentarios, se muestran (este es un ejemplo)
                  if (_showFullComments)
                    Column(
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
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.star, color: Colors.amber),
                onPressed: () {
                  // Acción para calificar el libro (puedes abrir un diálogo o navegar a una pantalla específica)
                },
              ),
              IconButton(
                icon: const Icon(Icons.comment, color: Colors.blue),
                onPressed: () {
                  // Aquí podrías desplazar el scroll hacia la sección de comentarios o abrir un modal
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
