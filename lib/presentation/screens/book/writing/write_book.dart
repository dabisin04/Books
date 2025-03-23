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

// Crear una lista de géneros disponibles
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

  LinearGradient _currentGradient = _generateRandomGradient();

  // Generar un gradiente aleatorio para la portada (Se eliminara en la siguiente versión)
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

  // Crear un libro con los datos ingresados y navegar a la pantalla de contenido
  void _goToContentScreen() {
    if (_formKey.currentState!.validate()) {
      final updatedBook = widget.book?.copyWith(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            genre: _selectedMainGenre ?? widget.book!.genre,
            additionalGenres: _selectedAdditionalGenres,
            has_chapters: _hasChapters,
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
          );

      if (widget.book != null) {
        context.read<BookBloc>().add(UpdateBookDetails(
              bookId: widget.book!.id,
              title: updatedBook.title,
              description: updatedBook.description,
              genre: updatedBook.genre,
              additionalGenres: updatedBook.additionalGenres,
            ));
      } else {
        context.read<BookBloc>().add(AddBook(updatedBook));
      }

      // Basado en si el libro tiene capítulos o no, navegar a la pantalla correspondiente
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

  // Mostrar un diálogo para seleccionar los géneros adicionales
  Future<void> _selectAdditionalGenres() async {
    final List<String> tempSelected = List.from(_selectedAdditionalGenres);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("Selecciona géneros adicionales"),
          content: SingleChildScrollView(
            child: Column(
              // Filtrar los géneros disponibles para que el genero principal no se repita
              children: availableGenres
                  .where((genre) => genre != _selectedMainGenre)
                  .map((genre) {
                final isSelected = tempSelected.contains(genre);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        tempSelected.remove(genre);
                      } else {
                        tempSelected.add(genre);
                      }
                    });
                  },
                  // Mostrar un card con el género y un icono de selección
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.white,
                    elevation: 4,
                    child: ListTile(
                      title: Text(
                        genre,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                      trailing: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).primaryColor,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, tempSelected),
              child: const Text("OK"),
            ),
          ],
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
                      value: _selectedMainGenre,
                      decoration: InputDecoration(
                        labelText: "Género Principal",
                        border: _selectedMainGenre == null
                            ? const OutlineInputBorder()
                            : InputBorder.none,
                      ),
                      items: availableGenres.map((genre) {
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
                          ? "Selecciona el género principal"
                          : null,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _selectAdditionalGenres,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: "Géneros adicionales",
                          border: _selectedAdditionalGenres.isEmpty
                              ? const OutlineInputBorder()
                              : InputBorder.none,
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
                    SwitchListTile(
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
