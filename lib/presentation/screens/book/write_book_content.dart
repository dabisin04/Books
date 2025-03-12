import 'dart:convert';
import 'package:books/presentation/widgets/book/custom_quill_tool_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:books/domain/entities/book/book.dart';
import 'package:books/application/bloc/book/book_bloc.dart';
import 'package:books/application/bloc/book/book_event.dart';

class WriteBookContentScreen extends StatefulWidget {
  final Book book;

  const WriteBookContentScreen({super.key, required this.book});

  @override
  _WriteBookContentScreenState createState() => _WriteBookContentScreenState();
}

class _WriteBookContentScreenState extends State<WriteBookContentScreen> {
  late final quill.QuillController _controller;
  final ScrollController _editorScrollController = ScrollController();
  final FocusNode _editorFocusNode = FocusNode();
  DateTime? _selectedPublicationDate;

  @override
  void initState() {
    super.initState();
    _selectedPublicationDate = widget.book.publicationDate;
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
    _editorScrollController.dispose();
    _editorFocusNode.dispose();
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
    Navigator.pop(context, updatedBook);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Editor de Contenido")),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: quill.QuillEditor(
                  controller: _controller,
                  scrollController: _editorScrollController,
                  focusNode: _editorFocusNode,
                ),
              ),
            ),
          ),
          // Use the custom compact toolbar as a bottom toolbar.
          CompactQuillToolbar(controller: _controller),
          // Publication date selector.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _pickPublicationDate,
                  child: const Text("Fecha de publicación"),
                ),
                const SizedBox(width: 16),
                Text(
                  _selectedPublicationDate != null
                      ? "Fecha: ${_selectedPublicationDate!.toLocal().toIso8601String().substring(0, 10)}"
                      : "Sin fecha",
                ),
              ],
            ),
          ),
          // Save button.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: ElevatedButton(
              onPressed: _finishBookCreation,
              child: const Text("Guardar"),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
