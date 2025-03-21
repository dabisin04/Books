// ignore_for_file: depend_on_referenced_packages, use_super_parameters, library_private_types_in_public_api, deprecated_member_use

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

  @override
  void initState() {
    super.initState();
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
      _document = quill.Document()..insert(0, '');
      context
          .read<ChapterBloc>()
          .add(LoadChaptersByBook((widget.contentEntity as Book).id));
    } else {
      final Book book = widget.contentEntity as Book;
      _document = _loadDocument(book.content);
    }
  }

  quill.Document _loadDocument(Map<String, dynamic>? content) {
    if (content != null && content.isNotEmpty) {
      try {
        final List<dynamic>? ops = content['ops'];
        if (ops != null) {
          return quill.Document.fromJson(ops);
        }
      } catch (e) {
        // error en parseo, se retorna documento vacío.
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final dynamicFontSize = screenHeight * 0.022;

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
      ),
      body: _isChapter || !_bookHasChapters
          ? PaginatedBookViewer(
              document: _document,
              fontSize: dynamicFontSize,
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
                      print("este es el capitulo #$chapter.chapterNumber");
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
