// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart' as quill;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:books/domain/entities/book/book.dart';
import 'package:books/application/bloc/book/book_bloc.dart';
import 'package:books/application/bloc/book/book_event.dart';
import '../../../../services/gemini_service.dart';
import '../../../widgets/book/custom_quill_tool_bar.dart';
import '../../../widgets/book/publication_date_selector.dart';
import '../../loading.dart';

class WriteBookContentScreen extends StatefulWidget {
  final Book book;

  const WriteBookContentScreen({super.key, required this.book});

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

  quill.Delta htmlToDelta(String html) {
    final document = parse(html);
    final delta = quill.Delta();

    void processNode(dom.Node node) {
      if (node is dom.Text) {
        delta.insert(node.text);
      } else if (node is dom.Element) {
        switch (node.localName) {
          case 'p':
            for (var child in node.nodes) {
              processNode(child);
            }
            delta.insert('\n');
            break;
          case 'strong':
          case 'b':
            final attributes = {'bold': true};
            for (var child in node.nodes) {
              if (child is dom.Text) {
                delta.insert(child.text, attributes);
              } else {
                processNode(child);
              }
            }
            break;
          case 'ul':
            for (var child in node.nodes) {
              if (child is dom.Element && child.localName == 'li') {
                for (var liChild in child.nodes) {
                  processNode(liChild);
                }
                delta.insert('\n', {'list': 'bullet'});
              }
            }
            break;
          case 'ol':
            for (var child in node.nodes) {
              if (child is dom.Element && child.localName == 'li') {
                for (var liChild in child.nodes) {
                  processNode(liChild);
                }
                delta.insert('\n', {'list': 'ordered'});
              }
            }
            break;
          default:
            for (var child in node.nodes) {
              processNode(child);
            }
            break;
        }
      }
    }

    for (var node in document.body!.nodes) {
      processNode(node);
    }

    return delta;
  }

  Future<void> _getGeminiSuggestion(String userPrompt) async {
    setState(() {
      _isFetchingSuggestion = true;
    });
    _previousDelta = _controller.document.toDelta();
    final currentText = _controller.document.toPlainText().trim();

    try {
      final suggestionText = await GeminiService.getBookSuggestion(
        title: widget.book.title,
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
      bottomNavigationBar: CustomQuillToolbar(
        controller: _controller,
        onSuggestionSubmit: _getGeminiSuggestion,
        isFetching: _isFetchingSuggestion,
      ),
    );
  }
}
