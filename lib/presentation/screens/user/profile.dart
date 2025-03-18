// ignore_for_file: use_build_context_synchronously, unused_element_parameter, library_private_types_in_public_api, deprecated_member_use
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
import '../../../domain/ports/book/book_repository.dart';
import '../../../domain/ports/user/user_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'publicados';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserBloc, UserState>(
      builder: (context, userState) {
        if (userState is UserUnauthenticated) {
          Future.microtask(
              () => Navigator.pushReplacementNamed(context, '/login'));
          return const Center(child: CircularProgressIndicator());
        } else if (userState is UserAuthenticated) {
          return BlocProvider<BookBloc>(
            create: (context) {
              final bloc = BookBloc(
                context.read<BookRepository>(),
                context.read<UserRepository>(),
              );
              bloc.add(GetBooksByAuthor(userState.user.id));
              return bloc;
            },
            child: _ProfileScreenContent(
              searchController: _searchController,
              selectedFilter: _selectedFilter,
              onFilterChanged: (filter) {
                setState(() {
                  _selectedFilter = filter;
                });
                context
                    .read<BookBloc>()
                    .add(GetBooksByAuthor(userState.user.id));
              },
              user: userState.user,
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class _ProfileScreenContent extends StatelessWidget {
  final TextEditingController searchController;
  final String selectedFilter;
  final Function(String) onFilterChanged;
  final dynamic user;

  const _ProfileScreenContent({
    super.key,
    required this.searchController,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<BookBloc, BookState>(
      listener: (context, state) {
        if (state is BookDeleted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
      child: BlocBuilder<BookBloc, BookState>(
        builder: (context, bookState) {
          if (bookState is BookLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (bookState is BookLoaded) {
            final allBooks = bookState.books;
            final query = searchController.text.toLowerCase();
            List<Book> displayedBooks;

            final filteredBooks = query.isNotEmpty
                ? allBooks
                    .where((book) => book.title.toLowerCase().contains(query))
                    .toList()
                : allBooks;
            final publishedBooks =
                filteredBooks.where((book) => book.isPublished).toList();
            final unpublishedBooks =
                filteredBooks.where((book) => !book.isPublished).toList();

            displayedBooks = selectedFilter == 'publicados'
                ? publishedBooks
                : unpublishedBooks;

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
                label: const Text("Escribir",
                    style: TextStyle(color: Colors.white)),
              ),
              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: double.infinity,
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
                                      user.username,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Wrap(
                                      children: [
                                        Text(
                                          "ID: ${user.id}",
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
                                  // Navegar a la pantalla de edición de perfil
                                },
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 2.0,
                          right: 16.0,
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/trash');
                            },
                            icon: const Icon(Icons.delete,
                                size: 16, color: Colors.white),
                            label: const Text(
                              "Papelera",
                              style:
                                  TextStyle(fontSize: 12, color: Colors.white),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  Colors.redAccent.withOpacity(0.8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Barra de búsqueda
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: searchController,
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
                          (context as Element).markNeedsBuild();
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Botones de filtro: Publicados y No Publicados
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => onFilterChanged('publicados'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedFilter == 'publicados'
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
                              onPressed: () => onFilterChanged('no_publicados'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    selectedFilter == 'no_publicados'
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
                    // Título de la categoría
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        searchController.text.isNotEmpty
                            ? 'Resultados de búsqueda'
                            : selectedFilter == 'publicados'
                                ? 'Libros Publicados'
                                : 'Libros No Publicados',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Lista de libros filtrados
                    displayedBooks.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.0),
                              child: Text("No hay libros en esta categoría"),
                            ),
                          )
                        : Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: displayedBooks.length,
                              itemBuilder: (context, index) {
                                final book = displayedBooks[index];
                                return Dismissible(
                                  key: ValueKey(book.id),
                                  background: Container(
                                    color: Colors.redAccent,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20.0),
                                    child: const Icon(Icons.delete,
                                        color: Colors.white),
                                  ),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (direction) {
                                    if (selectedFilter == 'publicados' ||
                                        selectedFilter == 'no_publicados') {
                                      context
                                          .read<BookBloc>()
                                          .add(TrashBook(book.id));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Libro movido a la papelera')),
                                      );
                                    } else {
                                      context
                                          .read<BookBloc>()
                                          .add(DeleteBook(book.id));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Libro eliminado definitivamente')),
                                      );
                                    }
                                  },
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              BookDetailsScreen(book: book),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0),
                                      child: ProfileBookCard(book: book),
                                    ),
                                  ),
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
      ),
    );
  }
}
