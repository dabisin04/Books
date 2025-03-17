import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";

  // Obtiene sugerencias usando la librería google_generative_ai
  static Future<String> getSuggestion(String prompt) async {
    if (_apiKey.isEmpty) {
      throw Exception("API Key de Gemini no encontrada en .env");
    }

    // Crea el modelo con la configuración deseada
    final model = GenerativeModel(
      model: 'gemini-2.0-flash', // O el modelo que corresponda
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 8192,
        responseMimeType: 'text/plain',
      ),
    );

    // Inicia un chat sin historial
    final chat = model.startChat(history: []);

    // Prepara el contenido a partir del prompt
    final content = Content.text(prompt);

    try {
      // Envía el mensaje y obtiene la respuesta
      final response = await chat.sendMessage(content);
      // Imprime la respuesta para depuración
      print("Respuesta de Gemini: ${response.text}");
      return response.text ?? "Sin respuesta";
    } catch (e) {
      print("Error en la API de Gemini: $e");
      throw Exception("Error en la API de Gemini: $e");
    }
  }
}
