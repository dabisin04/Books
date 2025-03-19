import 'package:flutter/material.dart';
import 'package:books/domain/entities/book/book.dart';
import 'package:books/presentation/widgets/user/profile_book_card.dart';

class BooksListWidget extends StatelessWidget {
  final List<Book> books;
  final bool isTrash;
  final Function(Book) onBookTap;
  final Function(Book)? onDismiss; // Para la vista normal (swipe)
  final Function(Book)? onRestore; // Para la vista de papelera
  final Function(Book)?
      onDeleteForever; // Para eliminar definitivamente en papelera
  final EdgeInsetsGeometry padding;

  const BooksListWidget({
    Key? key,
    required this.books,
    required this.isTrash,
    required this.onBookTap,
    this.onDismiss,
    this.onRestore,
    this.onDeleteForever,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.0),
          child: Text("No hay libros en esta categoría"),
        ),
      );
    }

    return Padding(
      padding: padding,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: books.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final book = books[index];
          if (isTrash) {
            // Vista de papelera: se muestra la carta y botones para restaurar y eliminar
            return GestureDetector(
              onTap: () => onBookTap(book),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: ProfileBookCard(book: book)),
                    IconButton(
                      icon: const Icon(Icons.restore, color: Colors.black),
                      onPressed: () => onRestore?.call(book),
                      tooltip: 'Restaurar',
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.delete_forever, color: Colors.black),
                      onPressed: () => onDeleteForever?.call(book),
                      tooltip: 'Eliminar definitivamente',
                    ),
                  ],
                ),
              ),
            );
          } else {
            // Vista normal: se usa Dismissible con la carta
            return Dismissible(
              key: ValueKey(book.id),
              background: Container(
                color: Colors.redAccent,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20.0),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              direction: DismissDirection.endToStart,
              onDismissed: (direction) => onDismiss?.call(book),
              child: GestureDetector(
                onTap: () => onBookTap(book),
                child: ProfileBookCard(book: book),
              ),
            );
          }
        },
      ),
    );
  }
}
