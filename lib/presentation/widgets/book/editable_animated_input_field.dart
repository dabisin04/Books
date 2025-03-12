import 'package:flutter/material.dart';

/// A widget that shows a TextFormField when editing and then fades
/// to show a label (with no border) after text is entered. Tapping the label
/// returns to editing.
class EditableAnimatedInputField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final int maxLines;

  const EditableAnimatedInputField({
    Key? key,
    required this.label,
    required this.controller,
    this.validator,
    this.maxLines = 1,
  }) : super(key: key);

  @override
  _EditableAnimatedInputFieldState createState() =>
      _EditableAnimatedInputFieldState();
}

class _EditableAnimatedInputFieldState
    extends State<EditableAnimatedInputField> {
  bool _editing = true;

  @override
  void initState() {
    super.initState();
    // If text becomes non-empty and we lose focus, we want to switch to label.
    // Here we use onFieldSubmitted for simplicity.
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _editing
          ? TextFormField(
              key: const ValueKey('textfield'),
              controller: widget.controller,
              validator: widget.validator,
              maxLines: widget.maxLines,
              decoration: InputDecoration(
                labelText: widget.label,
                border: const OutlineInputBorder(),
              ),
              onEditingComplete: () {
                if (widget.controller.text.isNotEmpty) {
                  setState(() {
                    _editing = false;
                  });
                }
              },
            )
          : InkWell(
              key: const ValueKey('label'),
              onTap: () {
                setState(() {
                  _editing = true;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.controller.text,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
            ),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}
