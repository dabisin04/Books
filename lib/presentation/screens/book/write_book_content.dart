import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:books/domain/entities/book/book.dart';
import 'package:books/application/bloc/book/book_bloc.dart';
import 'package:books/application/bloc/book/book_event.dart';

class WriteBookContentScreen extends StatefulWidget {
  final Book book;
  const WriteBookContentScreen({Key? key, required this.book})
      : super(key: key);

  @override
  _WriteBookContentScreenState createState() => _WriteBookContentScreenState();
}

class _WriteBookContentScreenState extends State<WriteBookContentScreen> {
  final TextEditingController _contentController = TextEditingController();
  DateTime? _selectedPublicationDate;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickPublicationDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedPublicationDate = picked;
      });
    }
  }

  Future<void> _finishBookCreation() async {
    // Actualizamos el libro con el contenido y la fecha de publicación.
    final String content = _contentController.text.trim();
    final String? pubDateStr = _selectedPublicationDate?.toIso8601String();

    // Enviar eventos al Bloc para actualizar el contenido y la fecha de publicación
    context.read<BookBloc>().add(UpdateBookContent(widget.book.id, content));
    if (pubDateStr != null) {
      context
          .read<BookBloc>()
          .add(UpdateBookPublicationDate(widget.book.id, pubDateStr));
    }

    // Simulamos un retardo (por ejemplo, para mostrar una pantalla de carga)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    // Mostramos un diálogo de confirmación y luego volvemos a la pantalla anterior.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Libro actualizado"),
        content: const Text("Se han guardado los cambios."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cierra el diálogo.
              Navigator.pop(context); // Vuelve a la pantalla anterior.
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Escribir Contenido"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              "Título: ${widget.book.title}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text("Género: ${widget.book.genre}"),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: "Contenido del libro",
                border: OutlineInputBorder(),
              ),
              maxLines: 8,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _pickPublicationDate,
                  child: const Text("Seleccionar fecha de publicación"),
                ),
                const SizedBox(width: 16),
                Text(
                  _selectedPublicationDate != null
                      ? "Fecha: ${_selectedPublicationDate!.toLocal().toIso8601String().substring(0, 10)}"
                      : "Sin fecha",
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _finishBookCreation,
              child: const Text("Finalizar"),
            ),
          ],
        ),
      ),
    );
  }
}
