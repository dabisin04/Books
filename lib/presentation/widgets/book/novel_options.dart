import 'package:flutter/material.dart';
import 'package:books/domain/entities/book/book.dart';
import 'package:books/presentation/screens/book/write_book.dart';
import 'package:books/presentation/screens/book/write_book_chapter.dart';

class NovelOptionsModal extends StatelessWidget {
  final Book book;
  const NovelOptionsModal({Key? key, required this.book}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text("Editar Detalles del Libro"),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => WriteBookScreen(book: book)),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text("Añadir Capítulo"),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WriteChapterScreen(book: book),
              ),
            );
          },
        ),
      ],
    );
  }
}
