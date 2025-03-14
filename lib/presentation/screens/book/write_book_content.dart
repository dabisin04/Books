import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:books/domain/entities/book/book.dart';
import 'package:books/application/bloc/book/book_bloc.dart';
import 'package:books/application/bloc/book/book_event.dart';
import '../../widgets/book/custom_quill_tool_bar.dart';
import '../loading.dart';

class WriteBookContentScreen extends StatefulWidget {
  final Book book;

  const WriteBookContentScreen({super.key, required this.book});

  @override
  _WriteBookContentScreenState createState() => _WriteBookContentScreenState();
}

class _WriteBookContentScreenState extends State<WriteBookContentScreen> {
  late final quill.QuillController _controller;
  DateTime? _selectedPublicationDate;

  @override
  void initState() {
    super.initState();
    _selectedPublicationDate = widget.book.publicationDate;
    // Si existe contenido, se carga desde JSON; de lo contrario, se crea un documento vacío.
    if (widget.book.content != null && widget.book.content!.isNotEmpty) {
      try {
        final doc = quill.Document.fromJson(jsonDecode(widget.book.content!));
        _controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        _controller = quill.QuillController.basic();
      }
    } else {
      _controller = quill.QuillController.basic();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickPublicationDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedPublicationDate ?? DateTime.now(),
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
    final String contentJson =
        jsonEncode(_controller.document.toDelta().toJson());
    final updatedBook = widget.book.copyWith(
      content: contentJson,
      publicationDate: _selectedPublicationDate,
    );

    context
        .read<BookBloc>()
        .add(UpdateBookContent(updatedBook.id, contentJson));
    if (_selectedPublicationDate != null) {
      context.read<BookBloc>().add(
            UpdateBookPublicationDate(
              updatedBook.id,
              _selectedPublicationDate!.toIso8601String(),
            ),
          );
    }

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Libro actualizado correctamente"),
        duration: Duration(seconds: 2),
      ),
    );

    // Redirigir a la pantalla de carga
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoadingScreen()),
    );
  }

  void _showSaveModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Opciones de publicación",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Fecha de publicación:",
                      style: TextStyle(fontSize: 16)),
                  TextButton(
                    onPressed: _pickPublicationDate,
                    child: Text(
                      _selectedPublicationDate != null
                          ? _selectedPublicationDate!
                              .toLocal()
                              .toIso8601String()
                              .substring(0, 10)
                          : "Seleccionar",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _finishBookCreation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
                ),
                child: const Text("Guardar",
                    style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar"),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.book.title,
          style: const TextStyle(fontSize: 16),
        ),
        toolbarHeight: 44,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _showSaveModal,
          ),
        ],
      ),
      body: quill.QuillEditor(
        focusNode: FocusNode(),
        scrollController: ScrollController(),
        controller: _controller,
        config: const quill.QuillEditorConfig(
          scrollable: true,
          padding: EdgeInsets.all(8.0),
          autoFocus: true,
          expands: false,
          placeholder: 'Escribe tu contenido...',
          // Puedes agregar otros parámetros si lo deseas
        ),
      ),
      bottomSheet: Container(
        color: Colors.grey.shade200,
        width: double.infinity,
        child: CompactQuillToolbar(controller: _controller),
      ),
    );
  }
}
