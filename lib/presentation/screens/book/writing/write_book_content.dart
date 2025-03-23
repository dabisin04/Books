// ignore_for_file: unused_import, unused_field, library_private_types_in_public_api, use_super_parameters

import 'dart:async';
import 'dart:convert';
import 'package:books/presentation/widgets/book/custom_quill_tool_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:books/domain/entities/book/book.dart';
import 'package:books/application/bloc/book/book_bloc.dart';
import 'package:books/application/bloc/book/book_event.dart';
import 'package:books/application/bloc/book/book_state.dart';
import 'package:books/services/gemini_service.dart';
import 'package:books/presentation/screens/loading.dart';
import 'package:books/presentation/widgets/book/publication_date_selector.dart';
import 'package:flutter_quill/quill_delta.dart' as quill;
import 'package:html/parser.dart' show parse;

class WriteBookContentScreen extends StatefulWidget {
  final Book book;

  const WriteBookContentScreen({Key? key, required this.book})
      : super(key: key);

  @override
  _WriteBookContentScreenState createState() => _WriteBookContentScreenState();
}

class _WriteBookContentScreenState extends State<WriteBookContentScreen> {
  late final quill.QuillController _controller;
  DateTime? _selectedPublicationDate;
  bool _isFetchingSuggestion = false;
  quill.Delta? _previousDelta;
  bool _showDiscardBanner = false;
  int _suggestionStart = 0;
  int _suggestionEnd = 0;
  Timer? _discardBannerTimer;
  final TextEditingController _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<BookBloc>().add(LoadBooks());
    _selectedPublicationDate = widget.book.publicationDate;

    if (widget.book.content != null && widget.book.content!.isNotEmpty) {
      try {
        final List<dynamic> deltaOps = widget.book.content!['ops'];
        final doc = quill.Document.fromJson(deltaOps);
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
    _discardBannerTimer?.cancel();
    _promptController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finishBookCreation() async {
    final deltaJson = _controller.document.toDelta().toJson();
    final contentMap = {'ops': deltaJson};

    print("Contenido guardado en DB: ${jsonEncode(contentMap)}");

    final updatedBook = widget.book.copyWith(
      content: contentMap,
      publicationDate: _selectedPublicationDate,
    );

    context.read<BookBloc>().add(UpdateBookContent(updatedBook.id, contentMap));
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

    String? previousBookContent;
    if (!widget.book.has_chapters) {
      final bookState = context.read<BookBloc>().state;
      if (bookState is BookLoaded) {
        final previousBooks = bookState.books
            .where((b) =>
                b.id != widget.book.id && b.authorId == widget.book.authorId)
            .toList();
        if (previousBooks.isNotEmpty) {
          previousBooks.sort((a, b) {
            return (b.publicationDate ?? DateTime.now())
                .compareTo(a.publicationDate ?? DateTime.now());
          });
          final previousBook = previousBooks.first;
          if (previousBook.content != null &&
              previousBook.content!['ops'] != null) {
            try {
              final doc = quill.Document.fromJson(previousBook.content!['ops']);
              previousBookContent = doc.toPlainText();
            } catch (e) {
              // Si falla la conversión, se deja como null.
            }
          }
        }
      }
    }

    try {
      final suggestionDelta = await GeminiService.getBookSuggestion(
        title: widget.book.title,
        primaryGenre: widget.book.genre,
        additionalGenres: widget.book.additionalGenres,
        isChapterBased: widget.book.has_chapters,
        userPrompt: userPrompt,
        currentContent: currentText,
        previousBook: previousBookContent,
      );

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
            baseOffset: _suggestionStart, extentOffset: _suggestionEnd),
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

  void _showSuggestionPrompt() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _promptController,
                decoration: const InputDecoration(
                  hintText: "Ingresa tu sugerencia",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final prompt = _promptController.text.trim();
                  if (prompt.isNotEmpty) {
                    Navigator.pop(context);
                    await _getGeminiSuggestion(prompt);
                  }
                },
                child: const Text("Enviar"),
              ),
              const SizedBox(height: 16),
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
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _finishBookCreation,
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
            PublicationDateSelector(
              initialDate: _selectedPublicationDate,
              onDateSelected: (selectedDate) {
                setState(() {
                  _selectedPublicationDate = selectedDate;
                });
              },
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
                      placeholder: 'Escribe tu contenido...',
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
      bottomNavigationBar: CustomQuillToolbar(controller: _controller),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: FloatingActionButton.extended(
          onPressed: _showSuggestionPrompt,
          label: const Text("Sugerir"),
          icon: const Icon(Icons.lightbulb_outline),
        ),
      ),
    );
  }
}
