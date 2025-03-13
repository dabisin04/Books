import 'package:books/presentation/screens/book/book_details.dart';
import 'package:books/presentation/screens/user/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:books/domain/entities/book/book.dart';
import 'package:books/application/bloc/book/book_bloc.dart';
import 'package:books/application/bloc/book/book_event.dart';
import 'package:books/application/bloc/book/book_state.dart';
import 'package:books/application/bloc/user/user_bloc.dart';
import 'package:books/application/bloc/user/user_event.dart';
import 'package:books/presentation/widgets/home/book_card.dart';
import 'package:books/presentation/widgets/home/hamburguer_menu.dart';
import 'package:books/presentation/widgets/home/recent_books_carousel.dart';
import 'package:books/presentation/widgets/home/bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null &&
        args is Map<String, dynamic> &&
        args.containsKey('initialTab')) {
      _currentIndex = args['initialTab'] as int;
    }
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void initState() {
    super.initState();
    context.read<BookBloc>().add(LoadBooks());
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildHomeContent() {
    return BlocBuilder<BookBloc, BookState>(
      builder: (context, state) {
        if (state is BookLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is BookLoaded) {
          // Filtrar solo los libros publicados.
          final List<Book> publishedBooks =
              state.books.where((book) => book.isPublished).toList();

          // Se realiza la búsqueda entre los libros publicados.
          final List<Book> filteredBooks = publishedBooks.where((book) {
            return book.title.toLowerCase().contains(_searchQuery) ||
                book.genre.toLowerCase().contains(_searchQuery);
          }).toList();

          if (_searchQuery.isNotEmpty) {
            return _buildSearchResults(filteredBooks);
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RecentBooksCarousel(books: publishedBooks),
                const SizedBox(height: 24.0),
                _buildHorizontalList(
                  title: "Mejor Calificados",
                  books: List<Book>.from(publishedBooks)
                    ..sort((a, b) => b.rating.compareTo(a.rating)),
                ),
                const SizedBox(height: 24.0),
                _buildHorizontalList(
                  title: "Más Vistos",
                  books: List<Book>.from(publishedBooks)
                    ..sort((a, b) => b.views.compareTo(a.views)),
                ),
                const SizedBox(height: 24.0),
                _buildGenreSections(publishedBooks),
              ],
            ),
          );
        } else if (state is BookError) {
          return Center(child: Text('Error: ${state.message}'));
        }
        return Container();
      },
    );
  }

  Widget _buildSearchResults(List<Book> books) {
    if (books.isEmpty) {
      return const Center(child: Text("No se encontraron resultados"));
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHorizontalList(
              title: "Resultados de la búsqueda", books: books),
        ],
      ),
    );
  }

  Widget _buildHorizontalList(
      {required String title, required List<Book> books}) {
    if (books.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(title,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8.0),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return GestureDetector(
                onTap: () => _navigateToBookDetails(book),
                child: BookCard(title: book.title, rating: book.rating),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGenreSections(List<Book> books) {
    final genres = books.map((book) => book.genre).toSet();
    if (genres.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: genres.map((genre) {
        final booksInGenre = books.where((b) => b.genre == genre).toList();
        return _buildHorizontalList(title: genre, books: booksInGenre);
      }).toList(),
    );
  }

  void _navigateToBookDetails(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookDetailsScreen(book: book),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeContent(),
      const Center(child: Text('Search Screen')),
      const Center(child: Text('Favorites Screen')),
      const Center(child: Text('Notifications Screen')),
      const ProfileScreen(),
    ];

    return Scaffold(
      drawer: const HamburguerMenu(),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(_currentIndex == 4 ? 0 : 82),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _currentIndex == 4 ? 0 : 82,
          child: AppBar(
            backgroundColor: Colors.redAccent,
            title: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar libros...',
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.black54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: () {
                    context.read<UserBloc>().add(LogoutUser());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        children: pages,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),
    );
  }
}
