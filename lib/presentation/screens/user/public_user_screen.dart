// ignore_for_file: prefer_final_fields, unused_field, library_private_types_in_public_api, use_super_parameters

import 'package:books/domain/ports/book/book_repository.dart';
import 'package:books/domain/ports/user/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:books/application/bloc/user/user_bloc.dart';
import 'package:books/application/bloc/user/user_state.dart';
import 'package:books/application/bloc/book/book_bloc.dart';
import 'package:books/application/bloc/book/book_event.dart';
import 'package:books/application/bloc/book/book_state.dart';
import 'package:books/domain/entities/user/user.dart';

class PublicProfileScreen extends StatefulWidget {
  final User author;
  const PublicProfileScreen({Key? key, required this.author}) : super(key: key);

  @override
  _PublicProfileScreenState createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'publicados';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserBloc>().state;
    User? currentUser;
    if (userState is UserAuthenticated) {
      currentUser = userState.user;
    }

    return BlocProvider<BookBloc>(
      create: (context) {
        final bloc = BookBloc(
          context.read<BookRepository>(),
          context.read<UserRepository>(),
        );
        bloc.add(GetBooksByAuthor(widget.author.id));
        return bloc;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.author.username),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.blueAccent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Text(
                        widget.author.username.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.author.username,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.author.bio ?? "",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (currentUser == null ||
                        currentUser.id != widget.author.id)
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blueAccent,
                        ),
                        child: const Text("Seguir"),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                    fillColor: Colors.grey[200],
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: BlocBuilder<BookBloc, BookState>(
                  builder: (context, state) {
                    if (state is BookLoading) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (state is BookLoaded) {
                      final publishedBooks = state.books
                          .where((book) => book.isPublished)
                          .toList();
                      final query = _searchController.text.toLowerCase();
                      final filteredBooks = query.isNotEmpty
                          ? publishedBooks
                              .where((book) =>
                                  book.title.toLowerCase().contains(query))
                              .toList()
                          : publishedBooks;
                      if (filteredBooks.isEmpty) {
                        return const Center(
                            child: Text("No hay libros publicados."));
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredBooks.length,
                        itemBuilder: (context, index) {
                          final book = filteredBooks[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              title: Text(book.title),
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/bookDetails',
                                  arguments: book,
                                );
                              },
                            ),
                          );
                        },
                      );
                    } else if (state is BookError) {
                      return Center(child: Text("Error: ${state.message}"));
                    }
                    return const SizedBox();
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
