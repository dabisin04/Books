import 'dart:math';
import 'package:flutter/material.dart';
import 'package:books/domain/entities/book/book.dart';
import 'package:books/presentation/screens/book/write_book_content.dart';
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
  const WriteBookScreen({Key? key}) : super(key: key);

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
      final newBook = Book(
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
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WriteBookContentScreen(book: newBook),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Escribe tu libro"),
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
                  decoration: const InputDecoration(
                    labelText: "Descripción (opcional)",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedMainGenre,
                  decoration: const InputDecoration(
                    labelText: "Género Principal",
                    border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: "Géneros adicionales",
                      border: OutlineInputBorder(),
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
                ElevatedButton(
                  onPressed: _goToContentScreen,
                  child: const Text("Siguiente"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
}
