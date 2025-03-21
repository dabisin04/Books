import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:books/domain/ports/book/book_repository.dart';
import 'package:books/domain/ports/user/user_repository.dart';
import 'package:books/application/bloc/book/book_bloc.dart';
import 'package:books/application/bloc/book/book_event.dart';
import 'package:books/application/bloc/book/book_state.dart';
import 'package:books/application/bloc/user/user_bloc.dart';
import 'package:books/application/bloc/user/user_state.dart';
import 'package:books/presentation/screens/book/reading/book_details.dart';
import '../../../widgets/book/book_list.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserBloc, UserState>(
      builder: (context, userState) {
        if (userState is UserAuthenticated) {
          return BlocProvider<BookBloc>(
            create: (context) {
              final bloc = BookBloc(
                context.read<BookRepository>(),
                context.read<UserRepository>(),
              );
              bloc.add(GetTrashedBooksByAuthor(userState.user.id));
              return bloc;
            },
            child: TrashScreenContent(user: userState.user),
          );
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class TrashScreenContent extends StatelessWidget {
  final dynamic user;

  const TrashScreenContent({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Papelera"),
      ),
      body: BlocBuilder<BookBloc, BookState>(
        builder: (context, state) {
          if (state is BookLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is BookLoaded) {
            final trashedBooks = state.books;
            if (trashedBooks.isEmpty) {
              return const Center(
                child: Text("No hay libros en la papelera."),
              );
            }
            return BooksListWidget(
              books: trashedBooks,
              isTrash: true,
              onBookTap: (book) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookDetailsScreen(book: book),
                  ),
                );
              },
              onRestore: (book) {
                context.read<BookBloc>().add(RestoreBook(book.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Libro restaurado.")),
                );
              },
              onDeleteForever: (book) {
                context.read<BookBloc>().add(DeleteBook(book.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Libro eliminado definitivamente.")),
                );
              },
            );
          } else if (state is BookError) {
            return Center(child: Text(state.message));
          }
          return const Center(child: Text("Error al cargar los libros."));
        },
      ),
    );
  }
}
