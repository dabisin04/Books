import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:books/domain/entities/book/book.dart';
import 'package:books/presentation/widgets/global/custom_button.dart';
import 'package:books/presentation/screens/book/book_details.dart';
import 'package:books/presentation/screens/user/widgets/profile_book_card.dart';
import '../../../application/bloc/book/book_bloc.dart';
import '../../../application/bloc/book/book_event.dart';
import '../../../application/bloc/book/book_state.dart';
import '../../../application/bloc/user/user_bloc.dart';
import '../../../application/bloc/user/user_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Book> _allBooks = [];
  String _selectedFilter = 'publicados'; // Initial filter

  @override
  void initState() {
    super.initState();
    context.read<BookBloc>().add(LoadBooks());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserBloc, UserState>(
      builder: (context, userState) {
        if (userState is UserUnauthenticated) {
          Future.microtask(
              () => Navigator.pushReplacementNamed(context, '/login'));
          return const Center(child: CircularProgressIndicator());
        } else if (userState is UserAuthenticated) {
          return BlocBuilder<BookBloc, BookState>(
            builder: (context, bookState) {
              if (bookState is BookLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (bookState is BookLoaded) {
                _allBooks = bookState.books;
                final query = _searchController.text.toLowerCase();
                final filteredBooks = query.isNotEmpty
                    ? _allBooks
                        .where(
                            (book) => book.title.toLowerCase().contains(query))
                        .toList()
                    : _allBooks;
                final publishedBooks =
                    filteredBooks.where((book) => book.isPublished).toList();
                final unpublishedBooks =
                    filteredBooks.where((book) => !book.isPublished).toList();

                List<Book> displayedBooks;
                if (query.isNotEmpty) {
                  displayedBooks = filteredBooks;
                } else if (_selectedFilter == 'publicados') {
                  displayedBooks = publishedBooks;
                } else {
                  displayedBooks = unpublishedBooks;
                }

                return Scaffold(
                  floatingActionButton: FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.pushNamed(context, '/write_book');
                    },
                    backgroundColor: Colors.redAccent,
                    icon: Image.asset(
                      'images/pluma.png',
                      width: 24,
                      height: 24,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "Escribir",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  body: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding:
                              const EdgeInsets.fromLTRB(16.0, 30.0, 16.0, 16.0),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.teal, Colors.greenAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.person,
                                    size: 40, color: Colors.grey),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userState.user.username,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Wrap(
                                      children: [
                                        Text(
                                          "ID: ${userState.user.id}",
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              CustomButton(
                                text: 'Editar',
                                onPressed: () {
                                  // Navigate to profile edit screen
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Search Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Buscar mis libros...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Filter Buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedFilter = 'publicados';
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _selectedFilter == 'publicados'
                                            ? Colors.redAccent
                                            : Colors.grey[300],
                                  ),
                                  child: const Text('Publicados',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedFilter = 'no_publicados';
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _selectedFilter == 'no_publicados'
                                            ? Colors.redAccent
                                            : Colors.grey[300],
                                  ),
                                  child: const Text('No Publicados',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Category Title
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            _searchController.text.isNotEmpty
                                ? 'Resultados de búsqueda'
                                : _selectedFilter == 'publicados'
                                    ? 'Libros Publicados'
                                    : 'Libros No Publicados',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // List of Filtered Books
                        displayedBooks.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20.0),
                                  child:
                                      Text("No hay libros en esta categoría"),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: displayedBooks.length,
                                  itemBuilder: (context, index) {
                                    final book = displayedBooks[index];
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                BookDetailsScreen(book: book),
                                          ),
                                        );
                                      },
                                      child: ProfileBookCard(book: book),
                                    );
                                  },
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 12),
                                ),
                              ),

                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                );
              }
              return const Center(child: Text("Error al cargar los libros"));
            },
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
