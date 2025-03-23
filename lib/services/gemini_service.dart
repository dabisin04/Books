// ignore_for_file: unused_import, unused_local_variable

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_quill/quill_delta.dart' as quill;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class GeminiService {
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";

  static Future<String> getSuggestion(String prompt) async {
    if (_apiKey.isEmpty) {
      throw Exception("API Key de Gemini no encontrada en .env");
    }

    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 8192,
        responseMimeType: 'text/plain',
      ),
    );

    final chat = model.startChat(history: []);
    final content = Content.text(prompt);

    try {
      final response = await chat.sendMessage(content);
      return response.text ?? "Sin respuesta";
    } catch (e) {
      throw Exception("Error en la API de Gemini: $e");
    }
  }

  static Future<quill.Delta> getBookSuggestion({
    required String title,
    required String primaryGenre,
    List<String>? additionalGenres,
    required String userPrompt,
    required String currentContent,
    required bool isChapterBased,
    String? previousChapter,
    String? previousBook,
  }) async {
    String genreInfo = "Género principal: $primaryGenre";
    if (additionalGenres != null && additionalGenres.isNotEmpty) {
      genreInfo += ", Géneros adicionales: ${additionalGenres.join(", ")}";
    }

    String context = "";
    if (isChapterBased &&
        previousChapter != null &&
        previousChapter.isNotEmpty) {
      context =
          "Aquí tienes el capítulo anterior para mantener la coherencia:\n\n$previousChapter\n\n, este es el titulo del capitulo: $title\n\n y este es el $genreInfo\n\n";
    } else if (!isChapterBased &&
        previousBook != null &&
        previousBook.isNotEmpty) {
      context =
          "Aquí tienes un libro previo del usuario para captar su estilo de escritura:\n\n$previousBook\n\n, este es el titulo del libro: $title\n\n y este es el $genreInfo\n\n";
    }

    String markdownInstructions =
        "Por favor, utiliza Markdown para formatear tu respuesta, incluyendo **negrita** (**texto**), *cursiva* (*texto*), encabezados (# Encabezado) y usa '>' y '-' al inicio de la línea para indicar sangría en diálogos.";

    String finalPrompt;
    if (userPrompt.isNotEmpty) {
      finalPrompt =
          "Con base en el contenido proporcionado, sin mencionar de forma redundante el título ni el género, y sin saludos ni encabezados, $userPrompt. $context Utiliza el siguiente contenido:\n\n$currentContent\n\n$markdownInstructions";
    } else if (currentContent.isNotEmpty) {
      finalPrompt =
          "Con base en el contenido actual, sin repetir información obvia (como el título y género), continúa la narrativa del libro de forma concisa. $context Contenido actual:\n\n$currentContent\n\n$markdownInstructions";
    } else {
      finalPrompt =
          "Genera una introducción creativa, inspiradora y original para un libro, sin saludos ni encabezados y sin repetir información obvia (título y género). $context\n\n$markdownInstructions";
    }

    final suggestionText = await getSuggestion(finalPrompt);
    return markdownToDelta(suggestionText.trim());
  }

  static quill.Delta markdownToDelta(String markdown) {
    final delta = quill.Delta();
    final lines = markdown.split('\n');
    for (var line in lines) {
      if (line.startsWith('# ')) {
        final text = line.substring(2).trim();
        delta.insert(text, {'header': 1});
        delta.insert('\n');
      } else if (line.startsWith('## ')) {
        final text = line.substring(3).trim();
        delta.insert(text, {'header': 2});
        delta.insert('\n');
      } else if (line.startsWith('### ')) {
        final text = line.substring(4).trim();
        delta.insert(text, {'header': 3});
        delta.insert('\n');
      } else if (line.startsWith('> ')) {
        final text = line.substring(2).trim();
        final spans = _parseInline(text);
        for (var span in spans) {
          delta.insert(span['text'], span['attributes']);
        }
        delta.insert('\n', {'indent': 1});
      } else {
        final spans = _parseInline(line);
        for (var span in spans) {
          delta.insert(span['text'], span['attributes']);
        }
        delta.insert('\n');
      }
    }
    return delta;
  }

  static List<Map<String, dynamic>> _parseInline(String text) {
    final spans = <Map<String, dynamic>>[];
    final boldPattern = RegExp(r'\*\*(.*?)\*\*');
    final italicPattern = RegExp(r'\*(.*?)\*');
    int index = 0;

    while (index < text.length) {
      final boldMatch = boldPattern.firstMatch(text.substring(index));
      final italicMatch = italicPattern.firstMatch(text.substring(index));
      if (boldMatch != null &&
          (italicMatch == null || boldMatch.start < italicMatch.start)) {
        if (boldMatch.start > 0) {
          spans.add({
            'text': text.substring(index, index + boldMatch.start),
            'attributes': null,
          });
        }
        spans.add({
          'text': boldMatch.group(1)!,
          'attributes': {'bold': true},
        });
        index += boldMatch.end;
      } else if (italicMatch != null) {
        if (italicMatch.start > 0) {
          spans.add({
            'text': text.substring(index, index + italicMatch.start),
            'attributes': null,
          });
        }
        spans.add({
          'text': italicMatch.group(1)!,
          'attributes': {'italic': true},
        });
        index += italicMatch.end;
      } else {
        spans.add({
          'text': text.substring(index),
          'attributes': null,
        });
        break;
      }
    }
    return spans;
  }
}
