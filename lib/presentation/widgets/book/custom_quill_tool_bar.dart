import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class CompactQuillToolbar extends StatelessWidget
    implements PreferredSizeWidget {
  final quill.QuillController controller;

  const CompactQuillToolbar({Key? key, required this.controller})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return quill.QuillSimpleToolbar(
      controller: controller,
      config: const quill.QuillSimpleToolbarConfig(
        // Use horizontal axis for a single-row toolbar.
        axis: Axis.horizontal,
        // Set multiRowsDisplay to false to force one row.
        multiRowsDisplay: false,
        // You can adjust toolbar size (smaller for compact toolbar).
        toolbarSize: 40,
        // Show only the essential buttons in your desired order.
        showUndo: false,
        showRedo: false,
        showFontFamily: false,
        showFontSize: false,
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
        // You can add additional configurations if needed.
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(40);
}
