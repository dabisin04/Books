// ignore_for_file: depend_on_referenced_packages, use_super_parameters, library_private_types_in_public_api, prefer_interpolation_to_compose_strings, sized_box_for_whitespace

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:turn_page_transition/turn_page_transition.dart';

class PaginatedBookViewer extends StatefulWidget {
  final quill.Document document;
  final double fontSize;

  const PaginatedBookViewer({
    Key? key,
    required this.document,
    this.fontSize = 16.0,
  }) : super(key: key);

  @override
  _PaginatedBookViewerState createState() => _PaginatedBookViewerState();
}

class _PaginatedBookViewerState extends State<PaginatedBookViewer> {
  late List<Widget> pages;
  final TurnPageController _turnPageController = TurnPageController();

  Widget _buildPageWidget(String text, double fullHeight, TextStyle textStyle,
      double horizontalPadding, double verticalPadding,
      {required bool isLast}) {
    return Container(
      color: Colors.white,
      height: fullHeight,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding, vertical: verticalPadding),
                child: Text(
                  text,
                  style: textStyle,
                ),
              ),
            ),
          ),
          Container(
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

  List<Widget> _buildPagesAdvanced(BoxConstraints constraints) {
    final plainText = widget.document.toPlainText();
    debugPrint("Texto extraído en PaginatedBookViewer:\n$plainText");

    List<String> paragraphs =
        plainText.split("\n\n").map((p) => p.trim()).toList();
    paragraphs.removeWhere((p) => p.isEmpty);

    final textStyle = TextStyle(fontSize: widget.fontSize);
    const horizontalPadding = 16.0;
    const verticalPadding = 16.0;
    final fullHeight = constraints.maxHeight;
    final availableHeight = fullHeight - (verticalPadding * 2);

    List<Widget> generatedPages = [];
    List<String> currentPageParagraphs = [];

    double measureHeight(String text) {
      final textPainter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: null,
      );
      textPainter.layout(
          maxWidth: constraints.maxWidth - (horizontalPadding * 2));
      return textPainter.height;
    }

    for (int i = 0; i < paragraphs.length; i++) {
      String para = paragraphs[i];
      if (i == paragraphs.length - 1) {
        currentPageParagraphs.add(para);
        String pageText = currentPageParagraphs.join("\n\n");
        generatedPages.add(_buildPageWidget(
            pageText, fullHeight, textStyle, horizontalPadding, verticalPadding,
            isLast: true));
        currentPageParagraphs = [];
        break;
      }
      String tentative = currentPageParagraphs.isEmpty
          ? para
          : currentPageParagraphs.join("\n\n") + "\n\n" + para;
      double tentativeHeight = measureHeight(tentative);

      if (currentPageParagraphs.length < 2) {
        currentPageParagraphs.add(para);
      } else {
        if (tentativeHeight <= availableHeight) {
          currentPageParagraphs.add(para);
        } else {
          if (currentPageParagraphs.length >= 3) {
            String pageText = currentPageParagraphs.join("\n\n");
            generatedPages.add(_buildPageWidget(pageText, fullHeight, textStyle,
                horizontalPadding, verticalPadding,
                isLast: false));
            currentPageParagraphs = [];
            currentPageParagraphs.add(para);
          } else {
            currentPageParagraphs.add(para);
          }
        }
      }
    }
    if (currentPageParagraphs.isNotEmpty) {
      String pageText = currentPageParagraphs.join("\n\n");
      generatedPages.add(_buildPageWidget(
          pageText, fullHeight, textStyle, horizontalPadding, verticalPadding,
          isLast: true));
    }

    debugPrint("Número total de páginas generadas: ${generatedPages.length}");
    return generatedPages;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        pages = _buildPagesAdvanced(constraints);
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
