import 'package:books/presentation/widgets/book/publication_date.dart';
import 'package:flutter/material.dart';
import 'package:books/domain/entities/book/book.dart';
import 'package:books/presentation/screens/book/write_book_content.dart';
import 'package:books/presentation/screens/book/write_book.dart';

class BookOptions extends StatelessWidget {
  final Book book;
  const BookOptions({Key? key, required this.book}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        ListTile(
          leading: const Icon(Icons.text_fields),
          title: const Text("Editar Contenido"),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => WriteBookContentScreen(book: book)),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.date_range),
          title: const Text("Cambiar Fecha de Publicación"),
          onTap: () {
            Navigator.pop(context);
            showModalBottomSheet(
              context: context,
              builder: (context) => PublicationDateModal(book: book),
            );
          },
        ),
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
      ],
    );
  }
}
