// ignore_for_file: library_private_types_in_public_api, use_super_parameters

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class CustomQuillToolbar extends StatefulWidget implements PreferredSizeWidget {
  final quill.QuillController controller;
  final Future<void> Function(String prompt) onSuggestionSubmit;
  final bool isFetching;

  const CustomQuillToolbar({
    Key? key,
    required this.controller,
    required this.onSuggestionSubmit,
    this.isFetching = false,
  }) : super(key: key);

  @override
  _CustomQuillToolbarState createState() => _CustomQuillToolbarState();

  @override
  Size get preferredSize => const Size.fromHeight(80);
}

class _CustomQuillToolbarState extends State<CustomQuillToolbar> {
  bool _showPromptField = false;
  final TextEditingController _promptController = TextEditingController();
  late String _currentHintText;
  final List<String> _hintTexts = [
    "¿Necesitas sugerencias?",
    "¿Buscas ideas?",
    "¿Te hacen falta sugerencias?",
    "¿Quieres inspiración?"
  ];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _currentHintText = _hintTexts.first;
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _togglePromptField() {
    setState(() {
      _showPromptField = !_showPromptField;
      // Al mostrar el campo, seleccionamos un hint aleatorio de la lista.
      if (_showPromptField) {
        _currentHintText = _hintTexts[_random.nextInt(_hintTexts.length)];
      }
    });
  }

  Future<void> _submitPrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    await widget.onSuggestionSubmit(prompt);
    setState(() {
      _showPromptField = false;
      _promptController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showPromptField)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: InputDecoration(
                      hintText: _currentHintText,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _submitPrompt,
                ),
              ],
            ),
          ),
        SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Container(
            color: Colors.red.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: widget.isFetching
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lightbulb_outline),
                  onPressed: _togglePromptField,
                ),
                const SizedBox(width: 8),
                Flexible(
                  fit: FlexFit.loose,
                  child: quill.QuillSimpleToolbar(
                    controller: widget.controller,
                    config: const quill.QuillSimpleToolbarConfig(
                      axis: Axis.horizontal,
                      showFontFamily: true,
                      showFontSize: true,
                      multiRowsDisplay: false,
                      toolbarSize: 40,
                      showUndo: false,
                      showRedo: false,
                      showAlignmentButtons: true,
                      showBoldButton: true,
                      showItalicButton: true,
                      showUnderLineButton: true,
                      showStrikeThrough: false,
                      showInlineCode: false,
                      showListNumbers: true,
                      showListBullets: true,
                      showListCheck: false,
                      showClearFormat: false,
                      showColorButton: false,
                      showBackgroundColorButton: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
