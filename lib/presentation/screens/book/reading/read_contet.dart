// ignore_for_file: depend_on_referenced_packages, use_super_parameters, library_private_types_in_public_api, prefer_interpolation_to_compose_strings, sized_box_for_whitespace

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:books/domain/entities/book/book.dart';
import 'package:books/domain/entities/book/chapter.dart';
import 'package:books/application/bloc/book/book_bloc.dart';
import 'package:books/application/bloc/book/book_event.dart';
import 'package:books/application/bloc/chapter/chapter_bloc.dart';
import 'package:books/application/bloc/chapter/chapter_state.dart';
import 'package:books/application/bloc/chapter/chapter_event.dart';
import '../../../widgets/book/comments_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../widgets/book/paginated_book_viewer.dart';

class ReadBookContentScreen extends StatefulWidget {
  final dynamic contentEntity;
  const ReadBookContentScreen({Key? key, required this.contentEntity})
      : super(key: key);

  @override
  _ReadBookContentScreenState createState() => _ReadBookContentScreenState();
}

class _ReadBookContentScreenState extends State<ReadBookContentScreen> {
  late final quill.Document _document;
  bool _isChapter = false;
  bool _bookHasChapters = false;
  // Factor de escala para el tamaño de fuente (valor base 1.0)
  double _textScaleFactor = 1.0;

  @override
  void initState() {
    super.initState();
    _loadTextScaleFactor(); // Cargar el valor guardado
    _isChapter = widget.contentEntity is Chapter;
    if (!_isChapter && widget.contentEntity is Book) {
      _bookHasChapters = (widget.contentEntity as Book).has_chapters;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context
            .read<BookBloc>()
            .add(UpdateBookViews((widget.contentEntity as Book).id));
      });
    }

    if (_isChapter) {
      final Chapter chapter = widget.contentEntity as Chapter;
      _document = _loadDocument(chapter.content);
    } else if (_bookHasChapters) {
      // Si el libro tiene capítulos, se muestra la lista de capítulos.
      _document = quill.Document()..insert(0, '');
      context
          .read<ChapterBloc>()
          .add(LoadChaptersByBook((widget.contentEntity as Book).id));
    } else {
      final Book book = widget.contentEntity as Book;
      _document = _loadDocument(book.content);
    }
  }

  Future<void> _loadTextScaleFactor() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _textScaleFactor = prefs.getDouble('textScaleFactor') ?? 1.0;
    });
  }

  Future<void> _saveTextScaleFactor() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('textScaleFactor', _textScaleFactor);
  }

  quill.Document _loadDocument(Map<String, dynamic>? content) {
    if (content != null && content.isNotEmpty) {
      try {
        final List<dynamic>? ops = content['ops'];
        if (ops != null) {
          return quill.Document.fromJson(ops);
        }
      } catch (e) {
        // Error en el parseo, se retorna un documento vacío.
      }
    }
    return quill.Document();
  }

  void _openCommentsModal() {
    final targetId = _isChapter
        ? (widget.contentEntity as Chapter).id
        : (widget.contentEntity as Book).id;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.5),
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsModal(
        targetId: targetId,
        targetType: _isChapter ? "chapter" : "book",
      ),
    );
  }

  void _increaseTextScale() {
    setState(() {
      _textScaleFactor += 0.1;
    });
    _saveTextScaleFactor();
  }

  void _decreaseTextScale() {
    if (_textScaleFactor > 0.5) {
      setState(() {
        _textScaleFactor -= 0.1;
      });
      _saveTextScaleFactor();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isChapter
              ? "Capítulo ${(widget.contentEntity as Chapter).chapterNumber}: ${(widget.contentEntity as Chapter).title}"
              : (widget.contentEntity as Book).title,
          style: const TextStyle(fontSize: 16),
        ),
        toolbarHeight: 44,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Botones para aumentar o disminuir el tamaño de texto
          IconButton(
            tooltip: "Aumentar tamaño de texto",
            icon: const Icon(Icons.zoom_in),
            onPressed: _increaseTextScale,
          ),
          IconButton(
            tooltip: "Reducir tamaño de texto",
            icon: const Icon(Icons.zoom_out),
            onPressed: _decreaseTextScale,
          ),
        ],
      ),
      body: _isChapter || !_bookHasChapters
          ? PaginatedBookViewer(
              document: _document,
              // Se usa un tamaño base (por ejemplo, 16) que se multiplica por el factor de escala.
              fontSize: 16.0,
              textScaleFactor: _textScaleFactor,
            )
          : BlocBuilder<ChapterBloc, ChapterState>(
              builder: (context, state) {
                if (state is ChapterLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is ChapterLoaded) {
                  final chapters = state.chapters;
                  if (chapters.isEmpty) {
                    return const Center(
                        child: Text("No se encontraron capítulos."));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(
                              "Capítulo ${chapter.chapterNumber}: ${chapter.title}"),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReadBookContentScreen(
                                    contentEntity: chapter),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                } else {
                  return const Center(
                      child: Text("Error al cargar capítulos."));
                }
              },
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
          ],
        ),
      ),
    );
  }
}
