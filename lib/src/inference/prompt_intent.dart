import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

enum PromptIntent {
  greeting,
  quickQuestion,
  recipe,
  howTo,
  writing,
  translation,
  comparison,
  coding,
  analysis,
  creative,
  highStakes,
}

enum PromptLanguage { english, italian, spanish, french, german, unknown }

@immutable
class PromptAnalysis {
  const PromptAnalysis({
    required this.intent,
    required this.language,
    this.advanced = false,
  });

  final PromptIntent intent;
  final PromptLanguage language;
  final bool advanced;
}

/// Deterministic, multilingual policy used before any model is loaded.
///
/// Terms are grouped by language and intent so adding a language does not
/// require extending a single routing conditional.
class PromptIntentClassifier {
  const PromptIntentClassifier();

  static const _signals = <PromptLanguage, Map<PromptIntent, List<String>>>{
    PromptLanguage.english: {
      PromptIntent.greeting: [
        'hello',
        'hi',
        'hey',
        'how are you',
        'good morning',
        'good evening',
      ],
      PromptIntent.recipe: ['recipe', 'cook', 'bake', 'ingredients'],
      PromptIntent.howTo: ['how to', 'how do i', 'steps to', 'instructions'],
      PromptIntent.writing: ['write', 'draft', 'compose', 'message', 'email'],
      PromptIntent.translation: ['translate', 'translation', 'into english'],
      PromptIntent.comparison: ['compare', 'comparison', 'versus', ' vs '],
      PromptIntent.coding: [
        'code',
        'debug',
        'function',
        'class ',
        'api',
        'python',
        'javascript',
        'dart',
        'swift',
      ],
      PromptIntent.analysis: [
        'analyze',
        'analyse',
        'explain',
        'reason',
        'evaluate',
        'summarize',
      ],
      PromptIntent.creative: ['story', 'poem', 'brainstorm', 'creative'],
      PromptIntent.highStakes: [
        'medical',
        'legal',
        'financial advice',
        'symptoms',
        'diagnosis',
      ],
    },
    PromptLanguage.italian: {
      PromptIntent.greeting: [
        'ciao',
        'come stai',
        'buongiorno',
        'buonasera',
        'salve',
      ],
      PromptIntent.recipe: [
        'ricetta',
        'cucinare',
        'cuocere',
        'torta',
        'pizza',
        'ingredienti',
      ],
      PromptIntent.howTo: [
        'come fare',
        'come si fa',
        'come cambiare',
        'istruzioni',
        'passaggi',
      ],
      PromptIntent.writing: [
        'scrivi',
        'redigi',
        'componi',
        'messaggio',
        'email',
      ],
      PromptIntent.translation: ['traduci', 'traduzione', 'in italiano'],
      PromptIntent.comparison: [
        'confronta',
        'confronto',
        'rispetto a',
        'contro',
      ],
      PromptIntent.coding: [
        'codice',
        'programma',
        'funzione',
        'classe ',
        'debug',
        'sviluppa',
      ],
      PromptIntent.analysis: [
        'analizza',
        'spiega',
        'valuta',
        'riassumi',
        'ragiona',
      ],
      PromptIntent.creative: ['storia', 'poesia', 'idee creative', 'invent'],
      PromptIntent.highStakes: [
        'medico',
        'legale',
        'finanziario',
        'sintomi',
        'diagnosi',
      ],
    },
    PromptLanguage.spanish: {
      PromptIntent.greeting: [
        'hola',
        'cómo estás',
        'como estas',
        'buenos días',
        'buenas tardes',
      ],
      PromptIntent.recipe: [
        'receta',
        'cocinar',
        'hornear',
        'pastel',
        'ingredientes',
      ],
      PromptIntent.howTo: [
        'cómo hacer',
        'como hacer',
        'cómo cambiar',
        'instrucciones',
        'pasos',
      ],
      PromptIntent.writing: ['escribe', 'redacta', 'mensaje', 'correo'],
      PromptIntent.translation: ['traduce', 'traducción', 'al español'],
      PromptIntent.comparison: ['compara', 'comparación', 'frente a'],
      PromptIntent.coding: [
        'código',
        'programa',
        'función',
        'clase ',
        'depura',
      ],
      PromptIntent.analysis: ['analiza', 'explica', 'evalúa', 'resume'],
      PromptIntent.creative: ['historia', 'poema', 'creativo'],
      PromptIntent.highStakes: [
        'médico',
        'legal',
        'financiero',
        'síntomas',
        'diagnóstico',
      ],
    },
    PromptLanguage.french: {
      PromptIntent.greeting: ['bonjour', 'salut', 'bonsoir', 'comment ça va'],
      PromptIntent.recipe: [
        'recette',
        'cuisiner',
        'cuire',
        'gâteau',
        'ingrédients',
      ],
      PromptIntent.howTo: [
        'comment faire',
        'comment changer',
        'instructions',
        'étapes',
      ],
      PromptIntent.writing: ['écris', 'rédige', 'message', 'courriel'],
      PromptIntent.translation: ['traduis', 'traduction', 'en français'],
      PromptIntent.comparison: ['compare', 'comparaison', 'par rapport à'],
      PromptIntent.coding: [
        'code',
        'programme',
        'fonction',
        'classe ',
        'débog',
      ],
      PromptIntent.analysis: ['analyse', 'explique', 'évalue', 'résume'],
      PromptIntent.creative: ['histoire', 'poème', 'créatif'],
      PromptIntent.highStakes: [
        'médical',
        'juridique',
        'financier',
        'symptômes',
        'diagnostic',
      ],
    },
    PromptLanguage.german: {
      PromptIntent.greeting: [
        'hallo',
        'wie geht es dir',
        'wie gehts',
        'guten morgen',
        'guten abend',
        'hi',
      ],
      PromptIntent.recipe: [
        'rezept',
        'kochen',
        'backen',
        'kuchen',
        'zutaten',
        'zubereiten',
      ],
      PromptIntent.howTo: [
        'wie mache ich',
        'wie kann ich',
        'anleitung',
        'schritte',
      ],
      PromptIntent.writing: ['schreibe', 'verfasse', 'nachricht', 'e-mail'],
      PromptIntent.translation: ['übersetze', 'übersetzung', 'auf deutsch'],
      PromptIntent.comparison: ['vergleiche', 'vergleich', 'gegenüber'],
      PromptIntent.coding: ['code', 'programm', 'funktion', 'klasse ', 'debug'],
      PromptIntent.analysis: [
        'analysiere',
        'erkläre',
        'bewerte',
        'fasse zusammen',
      ],
      PromptIntent.creative: ['geschichte', 'gedicht', 'kreativ'],
      PromptIntent.highStakes: [
        'medizinisch',
        'rechtlich',
        'finanziell',
        'symptome',
        'diagnose',
      ],
    },
  };

  static const _priority = [
    PromptIntent.highStakes,
    PromptIntent.translation,
    PromptIntent.recipe,
    PromptIntent.coding,
    PromptIntent.comparison,
    PromptIntent.writing,
    PromptIntent.howTo,
    PromptIntent.analysis,
    PromptIntent.creative,
  ];

  PromptAnalysis classify(String prompt) {
    final value = _normalize(prompt);
    final scores = <PromptLanguage, int>{};
    for (final entry in _signals.entries) {
      scores[entry.key] = entry.value.values
          .expand((terms) => terms)
          .where((term) => _contains(value, term))
          .length;
    }
    final language = scores.entries
        .fold(
          const MapEntry(PromptLanguage.unknown, 0),
          (best, entry) => entry.value > best.value ? entry : best,
        )
        .key;
    final languageSignals =
        _signals[language] ?? _signals[PromptLanguage.english]!;

    final trimmed = value.replaceAll(RegExp(r'[!.,?\s]+$'), '');
    final greetingTerms = languageSignals[PromptIntent.greeting] ?? const [];
    if (greetingTerms.any((term) => trimmed == term)) {
      return PromptAnalysis(intent: PromptIntent.greeting, language: language);
    }
    for (final intent in _priority) {
      if ((languageSignals[intent] ?? const []).any(
        (term) => _contains(value, term),
      )) {
        return PromptAnalysis(
          intent: intent,
          language: language,
          advanced: _isAdvanced(value),
        );
      }
    }
    if (value.split(' ').length <= 6 &&
        greetingTerms.any((term) => _contains(value, term))) {
      return PromptAnalysis(intent: PromptIntent.greeting, language: language);
    }
    return PromptAnalysis(
      intent: PromptIntent.quickQuestion,
      language: language,
      advanced: _isAdvanced(value),
    );
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static bool _contains(String value, String term) {
    final index = value.indexOf(term);
    if (index < 0) return false;
    bool word(int code) =>
        (code >= 48 && code <= 57) ||
        (code >= 97 && code <= 122) ||
        code >= 0x00c0;
    final before = index == 0 || !word(value.codeUnitAt(index - 1));
    final end = index + term.length;
    final after = end == value.length || !word(value.codeUnitAt(end));
    return before && after;
  }

  static bool _isAdvanced(String value) =>
      value.length > 900 ||
      const [
        'advanced',
        'rigorous proof',
        'deep reasoning',
        'security audit',
        'system architecture',
        'complex code',
        'dimostrazione rigorosa',
        'ragionamento profondo',
        'audit di sicurezza',
        'arquitectura del sistema',
        'preuve rigoureuse',
        'systemarchitektur',
      ].any(value.contains);
}

@immutable
class IntentSamplerProfile {
  const IntentSamplerProfile({
    required this.temperature,
    required this.topK,
    required this.topP,
    required this.minP,
    required this.repeatPenalty,
    required this.penaltyLastN,
  });

  final double temperature;
  final int topK;
  final double topP;
  final double minP;
  final double repeatPenalty;
  final int penaltyLastN;

  SamplerParams get params => SamplerParams(
    temperature: temperature,
    topK: topK,
    topP: topP,
    minP: minP,
    repeatPenalty: repeatPenalty,
    penaltyLastN: penaltyLastN,
  );
}

class PromptIntentPolicy {
  const PromptIntentPolicy._();

  static int desiredOutputTokens(PromptIntent intent) => switch (intent) {
    PromptIntent.greeting => 96,
    PromptIntent.quickQuestion || PromptIntent.translation => 224,
    PromptIntent.recipe || PromptIntent.howTo => 320,
    PromptIntent.writing || PromptIntent.comparison => 512,
    PromptIntent.coding ||
    PromptIntent.analysis ||
    PromptIntent.highStakes => 768,
    PromptIntent.creative => 512,
  };

  static IntentSamplerProfile sampler(PromptIntent intent) => switch (intent) {
    PromptIntent.recipe ||
    PromptIntent.howTo ||
    PromptIntent.translation ||
    PromptIntent.comparison ||
    PromptIntent.coding ||
    PromptIntent.analysis ||
    PromptIntent.highStakes => const IntentSamplerProfile(
      temperature: .30,
      topK: 20,
      topP: .85,
      minP: .02,
      repeatPenalty: 1.05,
      penaltyLastN: 128,
    ),
    PromptIntent.creative => const IntentSamplerProfile(
      temperature: .70,
      topK: 40,
      topP: .95,
      minP: .02,
      repeatPenalty: 1.05,
      penaltyLastN: 128,
    ),
    _ => const IntentSamplerProfile(
      temperature: .50,
      topK: 20,
      topP: .90,
      minP: .02,
      repeatPenalty: 1.03,
      penaltyLastN: 128,
    ),
  };

  static String taskInstruction(PromptAnalysis analysis) {
    final language = analysis.language == PromptLanguage.unknown
        ? 'the language of the latest user message'
        : analysis.language.name;
    final common =
        'Reply in $language unless the user explicitly requests another language. ';
    final task = switch (analysis.intent) {
      PromptIntent.recipe =>
        'Provide a practical recipe using common, appropriate ingredients and realistic quantities. '
            'Determine whether the dish is sweet or savoury. Include servings, preparation time, cooking '
            'time, oven temperature when relevant, an ingredient list, and numbered instructions. '
            '${analysis.language == PromptLanguage.italian ? 'Use metric measurements. ' : ''}'
            'Respect dietary restrictions in the private configuration. If an essential detail is ambiguous, '
            'ask one concise clarification question. Do not introduce unrelated ingredients or list the '
            'finished dish itself as an ingredient.',
      PromptIntent.howTo =>
        'Give practical, ordered steps, include prerequisites and relevant safety cautions, and do not omit the final step.',
      PromptIntent.translation =>
        'Translate faithfully into the requested language. Preserve meaning, tone, names, and formatting; add no commentary unless asked.',
      PromptIntent.comparison =>
        'Compare the same important criteria for each option, state material trade-offs, and end with a conditional recommendation.',
      PromptIntent.coding =>
        'Provide correct, runnable code when appropriate, state assumptions briefly, and include only the explanation needed to use or verify it.',
      PromptIntent.analysis =>
        'Reason carefully, distinguish facts from assumptions, and give a concise, well-supported conclusion.',
      PromptIntent.writing =>
        'Produce polished text for the requested audience, purpose, tone, and format without unnecessary preamble.',
      PromptIntent.creative =>
        'Follow the requested genre, voice, constraints, and length while keeping the result coherent and original.',
      PromptIntent.quickQuestion =>
        'Answer the question directly and factually. Admit uncertainty rather than inventing details.',
      PromptIntent.highStakes =>
        'Be cautious and factual, explain uncertainty and limits, and recommend qualified professional help when appropriate.',
      PromptIntent.greeting => 'Respond naturally and briefly.',
    };
    return '$common$task';
  }
}
