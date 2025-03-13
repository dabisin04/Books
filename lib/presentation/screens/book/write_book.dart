import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:books/domain/entities/book/book.dart';
import 'package:books/presentation/screens/book/write_book_content.dart';
import 'package:books/presentation/widgets/global/custom_button.dart';
import '../../../application/bloc/book/book_bloc.dart';
import '../../../application/bloc/book/book_event.dart';
import '../../../application/bloc/book/book_state.dart';
import '../../widgets/book/editable_animated_input_field.dart';

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
  final Book? book; // Parámetro opcional para edición
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
            genre: _selectedMainGenre ?? widget.book!.genre,
            additionalGenres: _selectedAdditionalGenres,
          ) ??
          Book(
            title: _titleController.text.trim(),
            authorId:
                "currentUserId", // Aquí deberías obtener el id del usuario actual
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

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WriteBookContentScreen(book: updatedBook),
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
    final List<String> tempSelected = List.from(_selectedAdditionalGenres);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Selecciona géneros adicionales"),
          content: SingleChildScrollView(
            child: Column(
              children: availableGenres.map((genre) {
                return StatefulBuilder(
                  builder: (context, setState) {
                    final selected = tempSelected.contains(genre);
                    return CheckboxListTile(
                      title: Text(genre),
                      value: selected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            tempSelected.add(genre);
                          } else {
                            tempSelected.remove(genre);
                          }
                        });
                      },
                    );
                  },
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
        // Si el usuario decide volver atrás, redirigimos a la pantalla de carga.
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/splash',
          (Route<dynamic> route) => false,
          arguments: {'initialTab': 4},
        );
        return false;
      },
      child: BlocListener<BookBloc, BookState>(
        listener: (context, state) {
          if (state is BookAdded) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WriteBookContentScreen(book: state.book),
              ),
            );
          } else if (state is BookUpdated) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WriteBookContentScreen(book: state.book),
              ),
            );
          }
        },
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
