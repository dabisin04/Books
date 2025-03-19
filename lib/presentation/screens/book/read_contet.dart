// ignore_for_file: depend_on_referenced_packages, use_super_parameters, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:books/domain/entities/book/book.dart';
import 'package:books/application/bloc/book/book_bloc.dart';
import '../../../application/bloc/book/book_event.dart';
import '../../widgets/book/comments_modal.dart';
import '../../widgets/book/paginated_book_viewer.dart';

class ReadBookContentScreen extends StatefulWidget {
  final Book book;
  const ReadBookContentScreen({Key? key, required this.book}) : super(key: key);

  @override
  _ReadBookContentScreenState createState() => _ReadBookContentScreenState();
}

class _ReadBookContentScreenState extends State<ReadBookContentScreen> {
  late final quill.Document _document;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookBloc>().add(UpdateBookViews(widget.book.id));
    });

    debugPrint(
        "Contenido recibido en ReadBookContentScreen: ${widget.book.content}");
    if (widget.book.content != null && widget.book.content!.isNotEmpty) {
      try {
        final List<dynamic>? ops = widget.book.content!['ops'];
        if (ops == null) {
          debugPrint("Error: 'ops' es null o no está definido.");
          _document = quill.Document();
        } else {
          _document = quill.Document.fromJson(ops);
        }
      } catch (e) {
        debugPrint("Error al cargar contenido del libro: $e");
        _document = quill.Document();
      }
    } else {
      debugPrint("Error: El contenido del libro está vacío o es null.");
      _document = quill.Document();
    }
  }

  void _openCommentsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.5),
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsModal(bookId: widget.book.id),
    );
  }

  void _openRatingModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.5),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        double rating = 0.0;
        final TextEditingController ratingController = TextEditingController();
        return FractionallySizedBox(
          heightFactor: 0.4,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const Text(
                  "Calificar",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ratingController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: "Ingresa tu puntaje (1-5)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final input = double.tryParse(ratingController.text);
                    rating = (input != null && input >= 1 && input <= 5)
                        ? input
                        : 0.0;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Calificación enviada: $rating"),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text("Enviar"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final dynamicFontSize = screenHeight * 0.022;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.book.title,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: PaginatedBookViewer(
        document: _document,
        fontSize: dynamicFontSize,
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
              onPressed: _openCommentsModal,
              icon: const Icon(Icons.comment),
              label: const Text("Comentar",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
              onPressed: _openRatingModal,
              icon: const Icon(Icons.star),
              label: const Text("Calificar",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
