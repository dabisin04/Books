// ignore_for_file: use_build_context_synchronously, use_super_parameters

import 'package:flutter/material.dart';
import 'package:books/domain/entities/book/book.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:books/application/bloc/book/book_bloc.dart';
import 'package:books/application/bloc/book/book_event.dart';

class PublicationDateModal extends StatelessWidget {
  final Book book;
  const PublicationDateModal({Key? key, required this.book}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final initialDate = book.publicationDate ?? DateTime.now();
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Cambiar Fecha de Publicación",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final DateTime? selectedDate = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (selectedDate != null) {
                context.read<BookBloc>().add(
                      UpdateBookPublicationDate(
                        book.id,
                        selectedDate.toIso8601String(),
                      ),
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Fecha actualizada a ${selectedDate.toLocal().toString().split(' ')[0]}",
                    ),
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text("Seleccionar Fecha"),
          ),
        ],
      ),
    );
  }
}
