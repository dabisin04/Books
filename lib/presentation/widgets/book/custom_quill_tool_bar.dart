import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class CustomQuillToolbar extends StatelessWidget
    implements PreferredSizeWidget {
  final quill.QuillController controller;

  const CustomQuillToolbar({super.key, required this.controller});

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: quill.QuillSimpleToolbar(
        controller: controller,
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
    );
  }
}
