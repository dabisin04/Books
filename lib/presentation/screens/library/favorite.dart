// ignore_for_file: use_build_context_synchronously
import 'package:books/presentation/widgets/home/small_book_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:books/application/bloc/favorite/favorite_bloc.dart';
import 'package:books/application/bloc/favorite/favorite_event.dart';
import 'package:books/application/bloc/favorite/favorite_state.dart';
import 'package:books/application/bloc/user/user_bloc.dart';
import 'package:books/application/bloc/user/user_state.dart';
import 'package:books/application/bloc/book/book_bloc.dart';
import 'package:books/application/bloc/book/book_state.dart';

class FavoriteBooksScreen extends StatefulWidget {
  const FavoriteBooksScreen({Key? key}) : super(key: key);

  @override
  _FavoriteBooksScreenState createState() => _FavoriteBooksScreenState();
}

class _FavoriteBooksScreenState extends State<FavoriteBooksScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final userState = context.read<UserBloc>().state;
    if (userState is UserAuthenticated) {
      context.read<FavoriteBloc>().add(LoadFavoritesEvent(userState.user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mis Favoritos")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar libro',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() {
                _searchQuery = value.toLowerCase();
              }),
            ),
          ),
          Expanded(
            child: BlocBuilder<FavoriteBloc, FavoriteState>(
              builder: (context, favState) {
                if (favState is FavoriteLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (favState is FavoriteLoaded) {
                  return BlocBuilder<BookBloc, BookState>(
                    builder: (context, bookState) {
                      if (bookState is BookLoaded) {
                        final favoriteBooks = bookState.books
                            .where((book) =>
                                favState.favoriteBookIds.contains(book.id) &&
                                book.title.toLowerCase().contains(_searchQuery))
                            .toList();

                        if (favoriteBooks.isEmpty) {
                          return const Center(
                              child: Text("No tienes libros favoritos aún."));
                        }

                        final screenWidth = MediaQuery.of(context).size.width;
                        final cardWidth = 120.0;
                        final spacing = 16.0;
                        final cardsPerRow =
                            (screenWidth / (cardWidth + spacing)).floor();
                        final totalSpacing = spacing * (cardsPerRow - 1);
                        final usedWidth =
                            cardsPerRow * cardWidth + totalSpacing;
                        final sidePadding = (screenWidth - usedWidth) / 2 > 0
                            ? (screenWidth - usedWidth) / 2
                            : 0.0;

                        return GridView.builder(
                          padding: EdgeInsets.symmetric(
                              horizontal: sidePadding, vertical: 8),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cardsPerRow,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: favoriteBooks.length,
                          itemBuilder: (context, index) {
                            final book = favoriteBooks[index];
                            return Stack(
                              children: [
                                SmallBookCard(book: book),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: IconButton(
                                    icon: const Icon(Icons.favorite,
                                        color: Colors.redAccent),
                                    onPressed: () {
                                      final userState =
                                          context.read<UserBloc>().state;
                                      if (userState is UserAuthenticated) {
                                        context.read<FavoriteBloc>().add(
                                              RemoveFavoriteEvent(
                                                  userState.user.id, book.id),
                                            );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      } else {
                        return const Center(child: Text("Cargando libros..."));
                      }
                    },
                  );
                } else if (favState is FavoriteError) {
                  return Center(child: Text(favState.message));
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }
}
