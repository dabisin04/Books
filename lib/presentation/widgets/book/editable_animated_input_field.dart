import 'package:flutter/material.dart';

class EditableAnimatedInputField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const EditableAnimatedInputField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
  });

  @override
  _EditableAnimatedInputFieldState createState() =>
      _EditableAnimatedInputFieldState();
}

class _EditableAnimatedInputFieldState
    extends State<EditableAnimatedInputField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      setState(() {}); // Actualiza el estado cuando cambia el texto
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(() {
      setState(() {});
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.label,
        border: widget.controller.text.isEmpty
            ? const OutlineInputBorder()
            : InputBorder.none,
      ),
      validator: widget.validator,
    );
  }
}
