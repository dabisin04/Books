// ignore_for_file: unused_local_variable, prefer_final_fields, library_private_types_in_public_api, use_super_parameters

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:turn_page_transition/turn_page_transition.dart';

class PaginatedBookViewer extends StatefulWidget {
  final quill.Document document;
  final double fontSize;
  final double textScaleFactor;

  const PaginatedBookViewer({
    Key? key,
    required this.document,
    this.fontSize = 16.0,
    this.textScaleFactor = 1.0,
  }) : super(key: key);

  @override
  _PaginatedBookViewerState createState() => _PaginatedBookViewerState();
}

class _PaginatedBookViewerState extends State<PaginatedBookViewer> {
  final TurnPageController _turnPageController = TurnPageController();
  List<Map<String, dynamic>> _linesWithAttributes = [];

  @override
  void initState() {
    super.initState();
    _parseDocument();
  }

  void _parseDocument() {
    final ops = widget.document.toDelta().toList();
    _linesWithAttributes.clear();
    List<TextSpan> currentLine = [];

    for (var op in ops) {
      final data = op.data;
      if (data is String) {
        final parts = data.split('\n');
        for (int i = 0; i < parts.length; i++) {
          if (parts[i].isNotEmpty) {
            currentLine.add(_buildInlineSpan(parts[i], op.attributes));
          }
          if (i < parts.length - 1 || data.endsWith('\n')) {
            if (currentLine.isNotEmpty) {
              _linesWithAttributes.add({
                "spans": List<TextSpan>.from(currentLine),
                "blockAttributes": op.attributes,
              });
              currentLine = [];
            }
          }
        }
      }
    }
    if (currentLine.isNotEmpty) {
      _linesWithAttributes.add({
        "spans": List<TextSpan>.from(currentLine),
        "blockAttributes": null,
      });
    }
    debugPrint("Total líneas generadas: ${_linesWithAttributes.length}");
  }

  TextSpan _buildInlineSpan(String text, Map<String, dynamic>? attrs) {
    double sizeMultiplier = 1.0;
    if (attrs != null && attrs.containsKey("size")) {
      final sizeAttr = attrs["size"];
      if (sizeAttr is String) {
        if (sizeAttr == "small") {
          sizeMultiplier = 0.8;
        } else if (sizeAttr == "large") {
          sizeMultiplier = 1.2;
        } else if (sizeAttr == "huge") {
          sizeMultiplier = 1.4;
        }
      } else if (sizeAttr is num) {
        sizeMultiplier = sizeAttr.toDouble() / 16.0;
      }
    }
    final effectiveSize =
        widget.fontSize * widget.textScaleFactor * sizeMultiplier;
    FontWeight fontWeight = FontWeight.normal;
    FontStyle fontStyle = FontStyle.normal;
    TextDecoration? decoration;

    if (attrs != null) {
      if (attrs['bold'] == true) fontWeight = FontWeight.bold;
      if (attrs['italic'] == true) fontStyle = FontStyle.italic;
      if (attrs['underline'] == true) decoration = TextDecoration.underline;
    }
    return TextSpan(
      text: text,
      style: TextStyle(
        fontSize: effectiveSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        decoration: decoration,
        height: 1.4,
        color: Colors.black,
      ),
    );
  }

  List<Widget> _buildPages(BoxConstraints constraints) {
    final fullHeight = constraints.maxHeight;
    const horizontalPadding = 16.0;
    const verticalPadding = 16.0;
    final availableHeight = fullHeight - (verticalPadding * 2);

    List<Widget> pages = [];
    List<Map<String, dynamic>> currentPageLines = [];
    double currentHeight = 0.0;

    for (int i = 0; i < _linesWithAttributes.length; i++) {
      final lineData = _linesWithAttributes[i];
      final lineSpans = lineData["spans"] as List<TextSpan>;
      final lineHeight = _measureLineHeight(lineSpans, constraints);

      if (lineHeight > availableHeight) {
        if (currentPageLines.isNotEmpty) {
          pages.add(
              _buildPageWidget(currentPageLines, fullHeight, isLast: false));
          currentPageLines = [];
          currentHeight = 0;
        }
        pages.add(_buildPageWidget([lineData], fullHeight, isLast: false));
        continue;
      }

      if (currentHeight + lineHeight > availableHeight &&
          currentPageLines.isNotEmpty) {
        pages
            .add(_buildPageWidget(currentPageLines, fullHeight, isLast: false));
        currentPageLines = [];
        currentHeight = 0;
      }

      currentPageLines.add(lineData);
      currentHeight += lineHeight;
    }

    if (currentPageLines.isNotEmpty) {
      pages.add(_buildPageWidget(currentPageLines, fullHeight, isLast: true));
    }

    debugPrint("Número total de páginas generadas: ${pages.length}");
    return pages;
  }

  double _measureLineHeight(
      List<TextSpan> lineSpans, BoxConstraints constraints) {
    final textPainter = TextPainter(
      text: TextSpan(children: lineSpans),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    textPainter.layout(
      maxWidth: constraints.maxWidth - (horizontalPadding * 2),
    );
    return textPainter.height;
  }

  static const double horizontalPadding = 16.0;

  Widget _buildPageWidget(
      List<Map<String, dynamic>> pageLines, double fullHeight,
      {required bool isLast}) {
    return Container(
      color: Colors.white,
      height: fullHeight,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: horizontalPadding, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: pageLines.map((lineData) {
                    final spans = lineData["spans"] as List<TextSpan>;
                    final blockAttributes =
                        lineData["blockAttributes"] as Map<String, dynamic>?;
                    int indentLevel = 0;
                    if (blockAttributes != null &&
                        blockAttributes.containsKey("indent")) {
                      indentLevel = blockAttributes["indent"] is int
                          ? blockAttributes["indent"] as int
                          : 0;
                    }
                    final indentPadding = indentLevel * 20.0;
                    return Padding(
                      padding: EdgeInsets.only(left: indentPadding),
                      child: RichText(
                        text: TextSpan(children: spans),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 20,
            child: Center(
              child: isLast
                  ? const Text("Fin", style: TextStyle(color: Colors.grey))
                  : const Icon(Icons.arrow_downward, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pages = _buildPages(constraints);
        return TurnPageView.builder(
          controller: _turnPageController,
          itemCount: pages.length,
          itemBuilder: (context, index) => pages[index],
          overleafColorBuilder: (index) => Colors.white,
          animationTransitionPoint: 0.5,
          useOnTap: true,
          useOnSwipe: true,
          onTap: (isNext) => debugPrint(isNext
              ? "Pasando a la siguiente página"
              : "Volviendo a la anterior"),
          onSwipe: (isNext) => debugPrint(
              isNext ? "Swipe a la siguiente página" : "Swipe a la anterior"),
        );
      },
    );
  }
}
