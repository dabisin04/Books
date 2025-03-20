import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

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

  static Future<String> getBookSuggestion({
    required String title,
    required String primaryGenre,
    List<String>? additionalGenres,
    required String userPrompt,
    required String currentContent,
  }) async {
    String genreInfo = "Género principal: $primaryGenre";
    if (additionalGenres != null && additionalGenres.isNotEmpty) {
      genreInfo += ", Géneros adicionales: ${additionalGenres.join(", ")}";
    }

    String finalPrompt;
    if (userPrompt.isNotEmpty) {
      finalPrompt =
          "El libro se titula \"$title\". $genreInfo. Sin saludos ni encabezados, $userPrompt. Utiliza el siguiente contenido:\n\n$currentContent";
    } else if (currentContent.isNotEmpty) {
      finalPrompt =
          "El libro se titula \"$title\". $genreInfo. Sin saludos ni encabezados, continúa la narrativa del libro de forma concisa y sin formatos innecesarios. Contenido actual:\n\n$currentContent";
    } else {
      finalPrompt =
          "El libro se titula \"$title\". $genreInfo. Genera una introducción creativa, inspiradora y original para un libro, sin saludos ni encabezados.";
    }

    return getSuggestion(finalPrompt);
  }
}
