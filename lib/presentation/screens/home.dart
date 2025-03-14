// ignore_for_file: library_private_types_in_public_api, prefer_const_constructors, sized_box_for_whitespace

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

import '../../application/bloc/user/user_state.dart';
import '../widgets/home/small_book_card.dart';

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
    context.read<BookBloc>().add(LoadBooks());
  }

  void didPopNext() {
    context.read<BookBloc>().add(LoadBooks());
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    context.read<BookBloc>().add(LoadBooks());
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null &&
          args is Map<String, dynamic> &&
          args.containsKey('initialTab')) {
        setState(() {
          _currentIndex = args['initialTab'] as int;
          _pageController.jumpToPage(_currentIndex);
        });
      }
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
          final List<Book> publishedBooks =
              state.books.where((book) => book.isPublished).toList();

          if (_searchQuery.isNotEmpty) {
            final List<Book> searchResults = publishedBooks.where((book) {
              return book.title.toLowerCase().contains(_searchQuery) ||
                  book.genre.toLowerCase().contains(_searchQuery);
            }).toList();
            return _buildSearchResults(searchResults);
          }

          final recentBooks = publishedBooks
              .where((book) => book.publicationDate != null)
              .toList()
            ..sort((a, b) => b.publicationDate!.compareTo(a.publicationDate!));
          final List<Book> mostRecentBooks = recentBooks.take(10).toList();

          List<Book> bestRatedBooks;
          if (publishedBooks.length > 5) {
            bestRatedBooks =
                publishedBooks.where((book) => (book.rating ?? 0) > 4).toList();
          } else {
            bestRatedBooks = List<Book>.from(publishedBooks)
              ..sort((a, b) => b.rating!.compareTo(a.rating!));
            bestRatedBooks = bestRatedBooks.take(3).toList();
          }

          final int totalViews =
              publishedBooks.fold(0, (prev, book) => prev + (book.views ?? 0));
          final double avgViews = publishedBooks.isNotEmpty
              ? totalViews / publishedBooks.length
              : 0;
          final List<Book> mostViewedBooks = publishedBooks
              .where((book) =>
                  (book.views ?? 0) > 10 && (book.views ?? 0) > avgViews)
              .toList()
            ..sort((a, b) => b.views!.compareTo(a.views!));

          final genreSections = _buildGenreSections(publishedBooks);

          if (publishedBooks.isEmpty) {
            return const Center(child: Text("No hay libros publicados aún"));
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mostRecentBooks.isNotEmpty)
                  RecentBooksCarousel(books: mostRecentBooks),
                const SizedBox(height: 24.0),
                if (bestRatedBooks.isNotEmpty)
                  _buildHorizontalList(
                    title: "Mejor Calificados",
                    books: bestRatedBooks,
                  ),
                const SizedBox(height: 24.0),
                if (mostViewedBooks.isNotEmpty)
                  _buildHorizontalList(
                    title: "Más Vistos",
                    books: mostViewedBooks,
                  ),
                const SizedBox(height: 24.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "Géneros",
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8.0),
                Container(
                  height: 240,
                  child: genreSections,
                ),
              ],
            ),
          );
        } else if (state is BookError) {
          return Center(child: Text('Error: ${state.message}'));
        }
        return const Center(child: Text("Cargando datos..."));
      },
    );
  }

  Widget _buildSearchResults(List<Book> books) {
    if (books.isEmpty) {
      return const Center(child: Text("No se encontraron resultados"));
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.7,
        ),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return GestureDetector(
            onTap: () => _navigateToBookDetails(book),
            child: BookCard(
              title: book.title,
              rating: book.rating,
              views: book.views,
            ),
          );
        },
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
        return Padding(
          // Se añade un espacio extra en la parte inferior (16.0)
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título del género (más pequeño)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    genre,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  height: 120,
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
          ),
        );
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

    return BlocListener<UserBloc, UserState>(
      listener: (context, state) {
        if (state is UserUnauthenticated) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      },
      child: Scaffold(
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
                      Navigator.pushReplacementNamed(context, '/login');
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
            if (_pageController.hasClients) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else {
              setState(() {
                _currentIndex = index;
              });
            }
          },
        ),
      ),
    );
  }
}
