// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'dart:isolate';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_quill/quill_delta.dart' as quill_delta;

class DeepSeekService {
  static const String _apiUrl = 'https://api.deepseek.com/v1/chat/completions';
  static const String _model = 'deepseek-chat';

  static void _isolateEntry(List<dynamic> args) {
    final SendPort port = args[0];
    final String prompt = args[1];
    final String apiKey = args[2];

    _getSuggestion(prompt, apiKey).then((result) {
      port.send(result);
    }).catchError((e, stack) {
      port.send('ERROR: $e');
    });
  }

  static Future<String> getSuggestionIsolated(String prompt) async {
    final receivePort = ReceivePort();
    final apiKey = dotenv.env['DEEPSEEK_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw Exception("API Key de DeepSeek no encontrada en .env");
    }
    await Isolate.spawn(_isolateEntry, [receivePort.sendPort, prompt, apiKey]);
    return await receivePort.first;
  }

  static Future<String> _getSuggestion(String prompt, String apiKey) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final body = jsonEncode({
      'model': _model,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'temperature': 0.7,
      'top_p': 0.95,
      'max_tokens': 2048
    });

    final response =
        await http.post(Uri.parse(_apiUrl), headers: headers, body: body);
    if (response.statusCode == 200) {
      final decoded = utf8.decode(response.bodyBytes);
      final data = jsonDecode(decoded);
      return data['choices'][0]['message']['content'] ?? 'Sin respuesta';
    } else {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }
  }

  static Future<quill_delta.Delta> getBookSuggestion({
    required String title,
    required String primaryGenre,
    List<String>? additionalGenres,
    required String userPrompt,
    required String currentContent,
    required bool isChapterBased,
    required String contentType,
    String? previousChapter,
    String? previousBook,
  }) async {
    final safeContent = _smartExcerpt(currentContent, segmentLength: 1500);

    String genreInfo = primaryGenre;
    if (additionalGenres != null && additionalGenres.isNotEmpty) {
      genreInfo += ', ${additionalGenres.join(", ")}';
    }

    String context = '';
    if (isChapterBased &&
        previousChapter != null &&
        previousChapter.isNotEmpty) {
      context = _smartExcerpt(previousChapter, segmentLength: 1500);
    } else if (!isChapterBased &&
        previousBook != null &&
        previousBook.isNotEmpty) {
      context = _smartExcerpt(previousBook, segmentLength: 1500);
    }

    const instructions = """
Eres un escritor profesional en español, especializado en narrativa coherente y fluida. Tu tarea es continuar directamente el contenido actual del libro (texto principal), respetando el tono, género y estilo del autor. 

Si se proporciona un capítulo anterior o un libro previo, **úsalo solo como referencia contextual para el estilo narrativo**, pero **nunca debes continuar la historia desde esos textos anteriores**. El foco es únicamente el contenido actual.

Prohibido:
- Comenzar con frases incoherentes o fuera de contexto.
- Incluir encabezados, títulos, subtítulos o separadores.
- Repetir fragmentos del contenido anterior o previo.
- Usar saludos, preguntas al lector o explicaciones sobre lo que haces.
- Cambiar drásticamente el estilo narrativo sin motivo.

Recomendado:
- Continúa justo desde el punto donde termina el texto actual.
- Usa puntuación y gramática correcta, manteniendo un ritmo narrativo natural.
- Escribe como lo haría un autor humano, con claridad, creatividad y lógica.
- Usa Markdown cuando aplique:
  - En ficción: *cursiva* para pensamientos, **negrita** para énfasis, y > para diálogos o citas, recordando que el estilo narrativo es el que se usa en el libro original, o si se lleva en el actual usar ese, tambien usar comillas y saltos de linea (estilo narrativo).
  - En no ficción: estructura clara según el tipo (ensayo, artículo, blog, etc.).
  - En investigaciones: lenguaje objetivo y sin adornos.

No hagas pausas forzadas. No justifiques tus frases. No interrumpas la continuidad. El lector debe sentir que el texto generado es una continuación natural del libro original.
""";

    String prompt;
    if (userPrompt.isNotEmpty) {
      prompt =
          "Título: $title\nGénero: $genreInfo\n\nEstilo previo:\n$context\n\n$userPrompt\n\nTexto actual:\n$safeContent\n\n$instructions";
    } else if (safeContent.isNotEmpty) {
      prompt =
          "Título: $title\nGénero: $genreInfo\n\nEstilo previo:\n$context\n\nContinúa esta historia:\n$safeContent\n\n$instructions";
    } else {
      prompt =
          "Título: $title\nGénero: $genreInfo\n\nEstilo previo:\n$context\n\nGenera una introducción para esta obra.\n\n$instructions";
    }

    final suggestionText = await getSuggestionIsolated(prompt);
    if (suggestionText.startsWith('ERROR:')) {
      throw Exception(suggestionText);
    }

    return markdownToDelta(suggestionText.trim());
  }

  static quill_delta.Delta markdownToDelta(String markdown) {
    final delta = quill_delta.Delta();
    final lines = markdown.split('\n');
    for (var line in lines) {
      if (line.startsWith('# ')) {
        delta.insert(line.substring(2).trim(), {'header': 1});
        delta.insert('\n');
      } else if (line.startsWith('## ')) {
        delta.insert(line.substring(3).trim(), {'header': 2});
        delta.insert('\n');
      } else if (line.startsWith('### ')) {
        delta.insert(line.substring(4).trim(), {'header': 3});
        delta.insert('\n');
      } else if (line.startsWith('> ')) {
        final spans = _parseInline(line.substring(2));
        for (var span in spans) {
          delta.insert(
            span['text'] as String,
            span['attributes'] == null
                ? null
                : Map<String, dynamic>.from(span['attributes']),
          );
        }
        delta.insert('\n', {'indent': 1});
      } else {
        final spans = _parseInline(line);
        for (var span in spans) {
          delta.insert(
            span['text'] as String,
            span['attributes'] == null
                ? null
                : Map<String, dynamic>.from(span['attributes']),
          );
        }
        delta.insert('\n');
      }
    }
    return delta;
  }

  static List<Map<String, dynamic>> _parseInline(String text) {
    final spans = <Map<String, dynamic>>[];
    final bold = RegExp(r'\*\*(.*?)\*\*');
    final italic = RegExp(r'\*(.*?)\*');
    int i = 0;
    while (i < text.length) {
      final bm = bold.firstMatch(text.substring(i));
      final im = italic.firstMatch(text.substring(i));
      if (bm != null && (im == null || bm.start < im.start)) {
        if (bm.start > 0) {
          spans
              .add({'text': text.substring(i, i + bm.start), 'attributes': {}});
        }
        spans.add({
          'text': bm.group(1)!,
          'attributes': {'bold': true}
        });
        i += bm.end;
      } else if (im != null) {
        if (im.start > 0) {
          spans
              .add({'text': text.substring(i, i + im.start), 'attributes': {}});
        }
        spans.add({
          'text': im.group(1)!,
          'attributes': {'italic': true}
        });
        i += im.end;
      } else {
        spans.add({'text': text.substring(i), 'attributes': {}});
        break;
      }
    }
    return spans;
  }

  static String _smartExcerpt(String text, {int segmentLength = 1500}) {
    if (text.length <= segmentLength * 2) return text;
    final start = text.substring(0, segmentLength);
    final end = text.substring(text.length - segmentLength);
    return "\$start\n\n...\n\n\$end";
  }
}
