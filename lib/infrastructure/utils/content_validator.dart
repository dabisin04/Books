import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart' as delta;

class ParagraphIssue {
  final String paragraph;
  final List<String> reasons;

  ParagraphIssue({required this.paragraph, required this.reasons});
}

class ValidationResult {
  final bool isValid;
  final List<String> messages;
  final List<ParagraphIssue> problematicParagraphs;

  ValidationResult({
    required this.isValid,
    required this.messages,
    required this.problematicParagraphs,
  });
}

class ContentValidator {
  static final List<String> bannedWords = [
    "haz clic aquí",
    "gana dinero rápido",
    "esto no es un engaño",
    "descubre el secreto",
    "te sorprenderá",
    "sigue leyendo",
    "mira esto",
    "esto cambiará tu vida",
    "no podrás creerlo",
    "nadie te lo dice",
    "revelado",
    "compra ahora",
    "oferta exclusiva",
    "solo por hoy",
    "mejor precio garantizado",
    "enlace en la bio",
    "aprovecha ya",
    "promoción limitada",
    "regístrate gratis",
    "haz tu pedido",
    "impactante",
    "alarmante",
    "sin palabras",
    "gratis",
    "sorteo",
    "sin costo",
    "increíble oferta",
    "exclusivo",
  ];

  static final List<String> clickbaitWords = [
    "haz clic aquí",
    "descubre el secreto",
    "mira esto",
    "te sorprenderá",
    "sigue leyendo"
  ];

  static final List<String> promotionalWords = [
    "gana dinero rápido",
    "oferta exclusiva",
    "solo por hoy",
    "mejor precio garantizado",
    "enlace en la bio",
    "aprovecha ya",
    "promoción limitada",
    "regístrate gratis",
    "haz tu pedido",
    "gratis",
    "sorteo",
    "sin costo",
    "increíble oferta",
    "exclusivo",
    "compra ahora"
  ];

  static final List<String> contextIndicators = [
    "como ejemplo",
    "según estudios",
    "se discute",
    "crítica a",
    "en este ensayo",
    "este artículo explora",
    "análisis de",
    "desde una perspectiva",
    "se analiza",
    "estudios revelan",
    "se argumenta que",
    "en este estudio",
    "según expertos",
    "basado en datos",
    "según investigaciones",
    "resulta demostrado",
    "de acuerdo a la investigación",
    "según el análisis",
    "en el contexto de",
    "como parte del análisis",
    "dentro del marco",
    "por ejemplo",
    "como se muestra en",
  ];

  static String extractPlainText(Map<String, dynamic> content) {
    try {
      final deltaObj = delta.Delta.fromJson(content['ops']);
      final doc = quill.Document.fromDelta(deltaObj);
      return doc.toPlainText().trim();
    } catch (_) {
      return '';
    }
  }

  static bool _containsHtml(String text) {
    return RegExp(r"<[^>]+>").hasMatch(text);
  }

  static double _averageWordsPerSentence(String text) {
    final sentences = text
        .split(RegExp(r'[.!?]+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (sentences.isEmpty) return 0;
    final totalWords = sentences
        .map((s) =>
            s.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length)
        .reduce((a, b) => a + b);
    return totalWords / sentences.length;
  }

  static double _averageWordLength(String text) {
    final words =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 0;
    final totalLength = words.map((w) => w.length).reduce((a, b) => a + b);
    return totalLength / words.length;
  }

  static double _scoreParagraph(String para) {
    double score = 0;
    final lowerPara = para.toLowerCase();
    final words =
        para.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final totalWords = words.length;

    int bannedCount = 0;
    for (final banned in bannedWords) {
      if (lowerPara.contains(banned)) {
        bannedCount++;
      }
    }

    int contextCount = 0;
    for (final indicator in contextIndicators) {
      if (lowerPara.contains(indicator)) {
        contextCount++;
      }
    }

    final effectiveBanned = bannedCount.clamp(0, 3);
    score += effectiveBanned;

    score -= contextCount * 1.0;

    if (totalWords > 0) {
      final density = bannedCount / totalWords;
      if (density < 0.05) {
        score *= 0.5;
      }
    }

    final pattern = "['\"](${bannedWords.map(RegExp.escape).join('|')})['\"]";
    final quotedBanned = RegExp(pattern).allMatches(lowerPara).length;
    score -= quotedBanned * 0.5;

    return score;
  }

  static List<String> _evaluateParagraphReasons(String para) {
    final lowerPara = para.toLowerCase();
    List<String> foundClickbait = [];
    List<String> foundPromotional = [];

    for (final word in clickbaitWords) {
      if (lowerPara.contains(word)) {
        foundClickbait.add(word);
      }
    }
    for (final word in promotionalWords) {
      if (lowerPara.contains(word)) {
        foundPromotional.add(word);
      }
    }
    final List<String> reasons = [];
    if (foundClickbait.isNotEmpty) {
      reasons.add(
          "Contiene contenido inadecuado (clickbait): ${foundClickbait.join(', ')}");
    }
    if (foundPromotional.isNotEmpty) {
      reasons.add(
          "Contiene contenido inadecuado (promocional): ${foundPromotional.join(', ')}");
    }
    if (reasons.isEmpty && lowerPara.isNotEmpty) {
      reasons.add("Contiene contenido inadecuado.");
    }
    return reasons;
  }

  static ValidationResult validate(Map<String, dynamic> content) {
    final text = extractPlainText(content);
    final List<String> issues = [];

    if (text.length < 300) {
      issues.add("El contenido es demasiado corto (mínimo 300 caracteres).");
    }
    if (_containsHtml(text)) {
      issues.add("El contenido contiene código HTML embebido.");
    }
    final avgWords = _averageWordsPerSentence(text);
    if (avgWords < 5) {
      issues.add(
          "Las oraciones son muy cortas, lo que podría afectar la claridad.");
    }
    final avgWordLength = _averageWordLength(text);
    if (avgWordLength < 3.5) {
      issues.add("El contenido puede no ser lo suficientemente descriptivo.");
    }

    final paragraphs = text.split(RegExp(r'\n{2,}'));
    final List<ParagraphIssue> paragraphIssues = [];
    const threshold = 2.0; // Umbral aumentado para mayor flexibilidad

    for (final para in paragraphs) {
      final score = _scoreParagraph(para);
      if (score > threshold) {
        final reasons = _evaluateParagraphReasons(para);
        paragraphIssues.add(ParagraphIssue(paragraph: para, reasons: reasons));
      }
    }

    if (issues.isEmpty && paragraphIssues.isNotEmpty) {
      issues.add("Este contenido no es permitido en la aplicación.");
    }

    final isValid = issues.isEmpty && paragraphIssues.isEmpty;
    return ValidationResult(
      isValid: isValid,
      messages: issues,
      problematicParagraphs: paragraphIssues,
    );
  }
}
