import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../application/bloc/book/book_bloc.dart';
import '../../application/bloc/book/book_event.dart';
import '../../application/bloc/book/book_state.dart';
import '../../application/bloc/user/user_bloc.dart';
import '../../application/bloc/user/user_event.dart';
import '../../application/bloc/user/user_state.dart';
import '../../domain/entities/book/book.dart';
import '../widgets/home/book_card.dart';
import '../widgets/home/hamburguer_menu.dart';
import '../widgets/home/small_book_card.dart';
import '../widgets/home/recent_books_carousel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _samplesAdded = false;

  @override
  void initState() {
    super.initState();
    context.read<BookBloc>().add(LoadBooks());
  }

  // Agregar libros de ejemplo si está vacío
  void _addSampleBooks() {
    if (_samplesAdded) return;
    _samplesAdded = true;

    final List<Book> sampleBooks = [
      Book(
        id: Uuid().v4(),
        title: 'El Gran Gatsby',
        authorId: 'author1',
        description: 'Una novela clásica...',
        genre: 'Ficción',
        uploadDate: DateTime.now().toIso8601String(),
        views: 10,
        rating: 4.5,
        ratingsCount: 100,
      ),
      Book(
        id: Uuid().v4(),
        title: 'Cien Años de Soledad',
        authorId: 'author2',
        description: 'Una obra maestra...',
        genre: 'Fantasía',
        uploadDate: DateTime.now().toIso8601String(),
        views: 20,
        rating: 4.8,
        ratingsCount: 200,
      ),
      // Agrega más libros...
    ];

    for (var book in sampleBooks) {
      context.read<BookBloc>().add(AddBook(book));
    }
  }

  Widget _buildHorizontalList({
    required double height,
    required List<Book> books,
    required Widget Function(Book) itemBuilder,
  }) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        itemBuilder: (context, index) => itemBuilder(books[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserBloc, UserState>(
      listener: (context, state) {
        if (state is UserUnauthenticated) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      },
      child: Scaffold(
        drawer: const HamburgerMenu(),
        appBar: AppBar(
          title: const Text('Home'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                context.read<UserBloc>().add(LogoutUser());
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar libros...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  context.read<BookBloc>().add(SearchBooks(value));
                },
              ),
            ),
          ),
        ),
        body: BlocListener<BookBloc, BookState>(
          listener: (context, state) {
            if (state is BookLoaded && state.books.isEmpty) {
              _addSampleBooks();
            }
          },
          child: BlocBuilder<BookBloc, BookState>(
            builder: (context, state) {
              if (state is BookLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is BookLoaded) {
                final allBooks = state.books;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Carrusel de libros recientes/destacados
                      RecentBooksCarousel(books: allBooks),

                      const SizedBox(height: 24.0),
                      // Sección: Mejor Calificados
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Mejor Calificados',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 16.0),
                      _buildHorizontalList(
                        height: 180,
                        books: allBooks, // Filtra si deseas solo los top
                        itemBuilder: (book) => BookCard(
                          title: book.title,
                          rating: book.rating,
                        ),
                      ),

                      const SizedBox(height: 24.0),
                      // Sección: Más Vistos
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Más Vistos',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 16.0),
                      _buildHorizontalList(
                        height: 180,
                        books: allBooks, // Filtra si deseas solo los más vistos
                        itemBuilder: (book) => BookCard(
                          title: book.title,
                          views: book.views,
                        ),
                      ),

                      const SizedBox(height: 24.0),
                      // Sección: Géneros
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Géneros',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 16.0),
                      // Ejemplo: Filtrar libros por género y mostrar cartas más pequeñas
                      _buildGenreSections(allBooks),
                    ],
                  ),
                );
              } else if (state is BookError) {
                return Center(child: Text('Error: ${state.message}'));
              }
              return Container();
            },
          ),
        ),
      ),
    );
  }

  // Ejemplo: Mostrar secciones horizontales por género
  Widget _buildGenreSections(List<Book> allBooks) {
    final genres = <String>{};
    for (var book in allBooks) {
      genres.add(book.genre);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: genres.map((genre) {
        final booksInGenre = allBooks.where((b) => b.genre == genre).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  genre,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8.0),
              SizedBox(
                height: 130,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: booksInGenre.length,
                  itemBuilder: (context, index) {
                    final book = booksInGenre[index];
                    return SmallBookCard(book: book);
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
