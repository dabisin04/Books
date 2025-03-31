// ignore_for_file: deprecated_member_use, library_private_types_in_public_api

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:books/domain/entities/book/book.dart';
import 'package:books/presentation/screens/book/writing/write_book_content.dart';
import 'package:books/presentation/screens/book/writing/write_book_chapter.dart';
import 'package:books/presentation/widgets/global/custom_button.dart';
import '../../../../application/bloc/book/book_bloc.dart';
import '../../../../application/bloc/book/book_event.dart';
import '../../../../application/bloc/book/book_state.dart';
import '../../../widgets/book/editable_animated_input_field.dart';

// Lista de géneros para libros
const List<String> availableGenres = [
  "Ficción",
  "Fantasía",
  "Misterio",
  "Romance",
  "Ciencia Ficción",
  "Histórico",
  "Policial",
  "Infantil",
  "No Ficción",
  "Biografía",
  "Autoayuda",
];

// Géneros para artículos (u otros contenidos no libro)
const List<String> availableArticleGenres = [
  "Científico",
  "Tecnología",
  "Salud",
  "Economía",
  "Educación",
  "Política",
  "Cultura",
  "Opinión",
  "Deportes",
];

// Lista de tipos de contenido (valores internos)
const List<String> availableContentTypes = [
  "book",
  "article",
  "review",
  "essay",
  "research",
  "blog",
  "news",
  "novel",
  "short_story",
  "tutorial",
  "guide",
];

// Mapeo para mostrar nombres amigables
final Map<String, String> contentTypeDisplayNames = {
  "book": "Libro",
  "article": "Artículo",
  "review": "Reseña",
  "essay": "Ensayo",
  "research": "Investigación",
  "blog": "Blog",
  "news": "Noticias",
  "novel": "Novela",
  "short_story": "Cuento",
  "tutorial": "Tutorial",
  "guide": "Guía",
};

class WriteBookScreen extends StatefulWidget {
  final Book? book;
  const WriteBookScreen({super.key, this.book});

  @override
  _WriteBookScreenState createState() => _WriteBookScreenState();
}

class _WriteBookScreenState extends State<WriteBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedMainGenre;
  List<String> _selectedAdditionalGenres = [];
  bool _hasChapters = false;
  String _selectedContentType = "book";
  LinearGradient _currentGradient = _generateRandomGradient();

  static LinearGradient _generateRandomGradient() {
    final random = Random();
    Color randomColor() => Color.fromARGB(
          255,
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
    return LinearGradient(
      colors: [randomColor(), randomColor()],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  void _onTitleChanged() {
    setState(() {
      _currentGradient = _generateRandomGradient();
    });
  }

  void _goToContentScreen() {
    if (_formKey.currentState!.validate()) {
      final updatedBook = widget.book?.copyWith(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            genre: _selectedMainGenre ?? '',
            additionalGenres: _selectedAdditionalGenres,
            has_chapters: _hasChapters,
            contentType: _selectedContentType,
          ) ??
          Book(
            title: _titleController.text.trim(),
            authorId: "currentUserId",
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            genre: _selectedMainGenre ?? '',
            additionalGenres: _selectedAdditionalGenres,
            uploadDate: DateTime.now().toIso8601String(),
            publicationDate: null,
            views: 0,
            rating: 0.0,
            ratingsCount: 0,
            reports: 0,
            content: null,
            has_chapters: _hasChapters,
            contentType: _selectedContentType,
          );

      if (widget.book != null) {
        context.read<BookBloc>().add(UpdateBookDetails(
              bookId: widget.book!.id,
              title: updatedBook.title,
              description: updatedBook.description,
              genre: updatedBook.genre,
              additionalGenres: updatedBook.additionalGenres,
              contentType: updatedBook.contentType,
            ));
      } else {
        context.read<BookBloc>().add(AddBook(updatedBook));
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _hasChapters
              ? WriteChapterScreen(book: updatedBook)
              : WriteBookContentScreen(book: updatedBook),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.book != null) {
      _titleController.text = widget.book!.title;
      _descriptionController.text = widget.book!.description ?? '';
      _selectedMainGenre = widget.book!.genre;
      _selectedAdditionalGenres = widget.book!.additionalGenres;
      _hasChapters = widget.book!.has_chapters;
      _selectedContentType = widget.book!.contentType;
    }
    _titleController.addListener(_onTitleChanged);
    _descriptionController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _descriptionController.removeListener(() {
      setState(() {});
    });
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectAdditionalGenres() async {
    if (_selectedContentType != 'book' && _selectedContentType != 'novel') {
      setState(() {
        _selectedAdditionalGenres = [];
      });
      return;
    }

    final List<String> selected = List.from(_selectedAdditionalGenres);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final List<String> currentAvailableGenres =
                (_selectedContentType == 'article')
                    ? availableArticleGenres
                    : availableGenres;
            final available = currentAvailableGenres
                .where((genre) =>
                    genre != _selectedMainGenre && !selected.contains(genre))
                .toList();
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text("Selecciona géneros adicionales"),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selected.isNotEmpty) ...[
                      const Text("Seleccionados:"),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selected.map((genre) {
                          return Chip(
                            label: Text(genre),
                            onDeleted: () {
                              setState(() {
                                selected.remove(genre);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const Divider(),
                    ],
                    const Text("Disponibles:"),
                    const SizedBox(height: 8),
                    Column(
                      children: available.map((genre) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selected.add(genre);
                            });
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            color: Theme.of(context).primaryColor,
                            elevation: 4,
                            child: ListTile(
                              title: Text(
                                genre,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, selected),
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null) {
      setState(() {
        _selectedAdditionalGenres = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isBookOrNovel =
        _selectedContentType == 'book' || _selectedContentType == 'novel';
    final List<String> currentAvailableGenres =
        isBookOrNovel ? availableGenres : availableArticleGenres;
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (Route<dynamic> route) => false,
          arguments: {'initialTab': 4},
        );
        return false;
      },
      child: BlocListener<BookBloc, BookState>(
        listener: (context, state) {},
        child: Scaffold(
          appBar: AppBar(
            title:
                Text(widget.book != null ? "Editar Libro" : "Escribir Libro"),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: 120,
                          width: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: _currentGradient,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _titleController.text.isEmpty
                                ? "Portada"
                                : _titleController.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: EditableAnimatedInputField(
                            label: "Título",
                            controller: _titleController,
                            validator: (value) => value == null || value.isEmpty
                                ? "Ingresa el título"
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: "Descripción (opcional)",
                        border: _descriptionController.text.isEmpty
                            ? const OutlineInputBorder()
                            : InputBorder.none,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedContentType,
                      decoration: const InputDecoration(
                        labelText: "Tipo de contenido",
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      items: availableContentTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(contentTypeDisplayNames[type] ??
                              type.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedContentType = value;
                            _selectedMainGenre = null;
                            if (!isBookOrNovel) {
                              _selectedAdditionalGenres = [];
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedMainGenre,
                      decoration: InputDecoration(
                        labelText:
                            isBookOrNovel ? "Género Principal" : "Enfoque",
                        border: _selectedMainGenre == null
                            ? const OutlineInputBorder()
                            : InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                      ),
                      items: currentAvailableGenres.map((genre) {
                        return DropdownMenuItem(
                          value: genre,
                          child: Text(genre),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMainGenre = value;
                        });
                      },
                      validator: (value) => value == null || value.isEmpty
                          ? "Selecciona ${isBookOrNovel ? 'el género principal' : 'un enfoque'}"
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // Mostrar géneros adicionales solo si es libro o novela
                    if (isBookOrNovel)
                      GestureDetector(
                        onTap: _selectAdditionalGenres,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: "Géneros adicionales",
                            border: _selectedAdditionalGenres.isEmpty
                                ? const OutlineInputBorder()
                                : InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          child: Text(
                            _selectedAdditionalGenres.isEmpty
                                ? "Selecciona géneros adicionales (opcional)"
                                : _selectedAdditionalGenres.join(', '),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: isBookOrNovel
                          ? SwitchListTile(
                              key: const ValueKey('chapterSwitch'),
                              title: const Text("¿El libro tendrá capítulos?"),
                              value: _hasChapters,
                              onChanged: (bool value) {
                                setState(() {
                                  _hasChapters = value;
                                });
                              },
                              secondary: Icon(
                                _hasChapters ? Icons.list : Icons.text_snippet,
                                color: Theme.of(context).primaryColor,
                              ),
                            )
                          : const SizedBox(key: ValueKey('noChapterSwitch')),
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: "Siguiente",
                      onPressed: _goToContentScreen,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
