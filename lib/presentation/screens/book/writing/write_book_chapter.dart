// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'dart:async';
import 'package:books/domain/ports/book/chapter_repository.dart';
import 'package:books/presentation/screens/loading.dart';
import 'package:books/presentation/widgets/book/publication_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart' as quill;
import 'package:books/domain/entities/book/book.dart';
import 'package:books/domain/entities/book/chapter.dart';
import 'package:books/application/bloc/chapter/chapter_bloc.dart';
import 'package:books/application/bloc/chapter/chapter_event.dart';
import '../../../../services/gemini_service.dart';
import '../../../widgets/book/custom_quill_tool_bar.dart';

class WriteChapterScreen extends StatefulWidget {
  final Book book;
  final Chapter? chapter;

  const WriteChapterScreen({super.key, required this.book, this.chapter});

  @override
  _WriteChapterScreenState createState() => _WriteChapterScreenState();
}

class _WriteChapterScreenState extends State<WriteChapterScreen> {
  late final quill.QuillController _controller;
  final TextEditingController _chapterTitleController = TextEditingController();
  int _chapterNumber = 1;
  bool _isFetchingSuggestion = false;
  quill.Delta? _previousDelta;
  bool _showDiscardBanner = false;
  int _suggestionStart = 0;
  int _suggestionEnd = 0;
  Timer? _discardBannerTimer;

  @override
  void initState() {
    super.initState();
    if (widget.chapter != null) {
      _chapterTitleController.text = widget.chapter!.title;
      _chapterNumber = widget.chapter!.chapterNumber;
      if (widget.chapter!.content != null &&
          widget.chapter!.content!.isNotEmpty) {
        try {
          final List<dynamic>? ops = widget.chapter!.content!['ops'];
          if (ops != null) {
            _controller = quill.QuillController(
              document: quill.Document.fromJson(ops),
              selection: const TextSelection.collapsed(offset: 0),
            );
          } else {
            _controller = quill.QuillController.basic();
          }
        } catch (e) {
          _controller = quill.QuillController.basic();
        }
      } else {
        _controller = quill.QuillController.basic();
      }
    } else {
      _controller = quill.QuillController.basic();
      _chapterNumber = 1;
      Future.microtask(() async {
        try {
          final chapterRepo = RepositoryProvider.of<ChapterRepository>(context);
          final chapters =
              await chapterRepo.fetchChaptersByBook(widget.book.id);
          int nextNumber = 1;
          if (chapters.isNotEmpty) {
            nextNumber = chapters
                    .map((c) => c.chapterNumber)
                    .reduce((a, b) => a > b ? a : b) +
                1;
          }
          if (mounted) {
            setState(() {
              _chapterNumber = nextNumber;
            });
          }
        } catch (e) {
          debugPrint("Error al obtener el siguiente número de capítulo: $e");
        }
      });
    }
  }

  @override
  void dispose() {
    _chapterTitleController.dispose();
    _discardBannerTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finishChapter() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return PublicationDateModal(book: widget.book);
      },
    );

    final deltaJson = _controller.document.toDelta().toJson();
    final contentMap = {'ops': deltaJson};

    if (widget.chapter != null) {
      final updatedChapter = widget.chapter!.copyWith(
        title: _chapterTitleController.text.trim(),
        content: contentMap,
      );
      context.read<ChapterBloc>().add(UpdateChapterEvent(updatedChapter));
    } else {
      final newChapter = Chapter(
        bookId: widget.book.id,
        title: _chapterTitleController.text.trim(),
        content: contentMap,
        uploadDate: DateTime.now().toIso8601String(),
        chapterNumber: _chapterNumber,
      );
      context.read<ChapterBloc>().add(AddChapterEvent(newChapter));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Capítulo guardado correctamente"),
        duration: Duration(seconds: 2),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoadingScreen()),
    );
  }

  Future<void> _getGeminiSuggestion(String userPrompt) async {
    setState(() {
      _isFetchingSuggestion = true;
    });
    _previousDelta = _controller.document.toDelta();
    final currentText = _controller.document.toPlainText().trim();

    final chapterTitleOrNumber = _chapterTitleController.text.isNotEmpty
        ? _chapterTitleController.text
        : "Capítulo $_chapterNumber";

    try {
      final suggestionText = await GeminiService.getBookSuggestion(
        title: "${widget.book.title} - $chapterTitleOrNumber",
        primaryGenre: widget.book.genre,
        additionalGenres: widget.book.additionalGenres,
        userPrompt: userPrompt,
        currentContent: currentText,
      );
      String processedSuggestion = suggestionText.trim();
      if (processedSuggestion.isNotEmpty) {
        processedSuggestion = processedSuggestion[0].toLowerCase() +
            processedSuggestion.substring(1);
      }
      final suggestionDelta = quill.Delta()..insert(processedSuggestion);
      final currentLength = _controller.document.length;
      _suggestionStart = currentLength;
      if (currentLength <= 1) {
        _controller.document.compose(suggestionDelta, quill.ChangeSource.local);
      } else {
        final retainDelta = quill.Delta()..retain(currentLength - 1);
        final fullDelta = retainDelta.concat(suggestionDelta);
        _controller.document.compose(fullDelta, quill.ChangeSource.local);
      }
      _suggestionEnd = _controller.document.length;
      _controller.updateSelection(
        TextSelection(
          baseOffset: _suggestionStart,
          extentOffset: _suggestionEnd,
        ),
        quill.ChangeSource.local,
      );
      setState(() {
        _showDiscardBanner = true;
      });
      _discardBannerTimer?.cancel();
      _discardBannerTimer = Timer(const Duration(seconds: 5), () {
        _clearSelectionAndHideBanner();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error obteniendo sugerencia: $e")),
      );
    }
    setState(() {
      _isFetchingSuggestion = false;
    });
  }

  void _clearSelectionAndHideBanner() {
    _controller.updateSelection(
      TextSelection.collapsed(offset: _controller.document.length),
      quill.ChangeSource.local,
    );
    if (mounted) {
      setState(() {
        _showDiscardBanner = false;
      });
    }
  }

  void _discardSuggestion() {
    _discardBannerTimer?.cancel();
    if (_previousDelta != null) {
      _controller.document.replace(0, _controller.document.length, "");
      _controller.document.compose(_previousDelta!, quill.ChangeSource.local);
      _controller.updateSelection(
        TextSelection.collapsed(offset: _controller.document.length),
        quill.ChangeSource.local,
      );
      setState(() {
        _showDiscardBanner = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.chapter != null ? "Editar Capítulo" : "Nuevo Capítulo"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _finishChapter,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          if (_showDiscardBanner) {
            _discardBannerTimer?.cancel();
            _clearSelectionAndHideBanner();
          }
        },
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 600),
                child: TextField(
                  controller: _chapterTitleController,
                  maxLines: 1,
                  decoration: const InputDecoration(
                    labelText: "Título del Capítulo",
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  quill.QuillEditor(
                    focusNode: FocusNode(),
                    scrollController: ScrollController(),
                    controller: _controller,
                    config: const quill.QuillEditorConfig(
                      scrollable: true,
                      padding: EdgeInsets.all(8.0),
                      autoFocus: true,
                      expands: false,
                      placeholder: 'Escribe el contenido del capítulo...',
                    ),
                  ),
                  if (_showDiscardBanner)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: MaterialBanner(
                        backgroundColor: Colors.amber.shade200,
                        content: const Text("Sugerencia aplicada"),
                        actions: [
                          TextButton(
                            onPressed: _discardSuggestion,
                            child: const Text("Descartar"),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomQuillToolbar(
        controller: _controller,
        onSuggestionSubmit: _getGeminiSuggestion,
        isFetching: _isFetchingSuggestion,
      ),
    );
  }
}
