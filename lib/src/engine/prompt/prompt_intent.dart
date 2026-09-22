import 'package:flutter/foundation.dart';

// Engine seam: this file lives inside lib/src/engine, so the FFI sampler type
// comes from the backends shim (only lib/src/engine/** may reference it).
import 'package:finn_ai/src/engine/backends/llama_shim.dart';

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
    this.hardwareGuidance = false,
    this.recipeDish = '',
  });

  final PromptIntent intent;
  final PromptLanguage language;
  final bool advanced;
  final bool hardwareGuidance;
  final String recipeDish;
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
      PromptIntent.howTo: [
        'how to',
        'how do i',
        'steps to',
        'instructions',
        'upgrade',
        'replace',
      ],
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
        'sostituire',
        'aggiornare',
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
        'reemplazar',
        'actualizar',
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
        'remplacer',
        'mettre à niveau',
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
        'ersetzen',
        'aufrüsten',
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

  static const _hardwareSignals = <PromptLanguage, List<String>>{
    PromptLanguage.english: [
      'laptop ram',
      'ram in my laptop',
      'laptop memory',
      'laptop ssd',
      'phone battery',
    ],
    PromptLanguage.italian: [
      'ram del portatile',
      'ram nel portatile',
      'memoria del portatile',
      'ssd',
      'ssd del portatile',
      'batteria del telefono',
      'batteria dello smartphone',
    ],
    PromptLanguage.spanish: [
      'ram del portátil',
      'ssd del portátil',
      'batería del teléfono',
    ],
    PromptLanguage.french: [
      'ram du portable',
      'ssd du portable',
      'batterie du téléphone',
    ],
    PromptLanguage.german: [
      'laptop ram',
      'laptop-ram',
      'laptop ssd',
      'handy-akku',
    ],
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
    final hardwareGuidance = (_hardwareSignals[language] ??
            _hardwareSignals[PromptLanguage.english]!)
        .any((term) => _contains(value, term));

    final trimmed = value.replaceAll(RegExp(r'[!.,?\s]+$'), '');
    final greetingTerms = languageSignals[PromptIntent.greeting] ?? const [];
    if (greetingTerms.any((term) => trimmed == term)) {
      return PromptAnalysis(intent: PromptIntent.greeting, language: language);
    }
    if (hardwareGuidance) {
      return PromptAnalysis(
        intent: PromptIntent.howTo,
        language: language,
        advanced: _isAdvanced(value),
        hardwareGuidance: true,
      );
    }
    for (final intent in _priority) {
      if ((languageSignals[intent] ?? const []).any(
        (term) => _contains(value, term),
      )) {
        return PromptAnalysis(
          intent: intent,
          language: language,
          advanced: _isAdvanced(value),
          hardwareGuidance: hardwareGuidance,
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
      hardwareGuidance: hardwareGuidance,
    );
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static String recipeDishFrom(String prompt) {
    final match = RegExp(
      r'(?:recipe|ricetta|receta|rezept|recette)\s+(?:for|di|de|für|pour)?\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(prompt.trim());
    return match?.group(1)?.replaceAll(RegExp(r'[?.!]+$'), '').trim() ?? '';
  }

  static bool _contains(String value, String term) {
    final index = value.indexOf(term);
    if (index < 0) return false;
    bool word(int code) =>
        (code >= 48 && code <= 57) ||
        (code >= 97 && code <= 122) ||
        (code >= 0x00c0 && code <= 0x024f);
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
    this.grammar,
  });

  final double temperature;
  final int topK;
  final double topP;
  final double minP;
  final double repeatPenalty;
  final int penaltyLastN;

  /// Optional GBNF grammar source constraining this turn's output.
  ///
  /// Null disables the grammar stage, so every other profile samples exactly as
  /// it did before. Used where the output has to parse as JSON.
  final String? grammar;

  SamplerParams get params => SamplerParams(
        temperature: temperature,
        topK: topK,
        topP: topP,
        minP: minP,
        repeatPenalty: repeatPenalty,
        penaltyLastN: penaltyLastN,
        grammar: GrammarConfig(grammar: grammar),
      );
}

class PromptIntentPolicy {
  const PromptIntentPolicy._();

  static int desiredOutputTokens(PromptIntent intent) => switch (intent) {
        PromptIntent.greeting => 160,
        PromptIntent.quickQuestion || PromptIntent.translation => 224,
        PromptIntent.recipe || PromptIntent.howTo => 320,
        PromptIntent.writing || PromptIntent.comparison => 512,
        PromptIntent.coding ||
        PromptIntent.analysis ||
        PromptIntent.highStakes =>
          768,
        PromptIntent.creative => 512,
      };

  /// Whether a turn should run the smart on-device model-driven web-search decision pass.
  ///
  /// Self-contained tasks (greetings, translations, recipes, creative writing, pure coding,
  /// standard questions) skip the decision pass completely for instant TTFT (<150ms).
  /// Advanced, research-heavy, or deeply analytical prompts allow the model to actively
  /// reason whether background browser search is needed.
  static bool needsSearchDecision(PromptAnalysis analysis) => analysis.advanced;

  /// A standard tool contract for the model-driven TinyBrowser autonomous tool calls.
  ///
  /// [requireToolCall] is set when the user explicitly asked Finn to browse: the
  /// model must then emit a tool call rather than answering from knowledge.
  static String searchDecisionDirectiveFor(
    PromptLanguage language, {
    bool requireToolCall = false,
  }) =>
      '# TinyBrowser Tools\n\n'
      'You have access to a built-in headless browser engine with two tools:\n'
      '1. Search the web:\n'
      '<tool_call>\n'
      '{"name": "browser_search", "arguments": {"query": "<search terms>"}}\n'
      '</tool_call>\n\n'
      '2. Open and inspect any website URL directly:\n'
      '<tool_call>\n'
      '{"name": "browser_open", "arguments": {"url": "<https://...>"}}\n'
      '</tool_call>\n\n'
      '3. Find text on the page you have open:\n'
      '<tool_call>\n'
      '{"name": "browser_find", "arguments": {"query": "<text to find>"}}\n'
      '</tool_call>\n\n'
      'If the user request requires external facts, current or time-sensitive information (such as latest products, release dates, current news, or live data), or inspecting a website, output a tool call.\n'
      '${requireToolCall ? 'The user asked you to browse, so you must output one tool call now. Do not reply ANSWER.' : 'Otherwise, reply exactly: ANSWER.'}';

  /// Sampler for the model-driven search-decision turn.
  ///
  /// The turn is a routing decision, not prose, so it is grammar-constrained:
  /// the reply can only be the literal `ANSWER.` or one well-formed tool call
  /// naming a tool that exists. Malformed JSON, a sentence before the JSON, an
  /// invented tool name and a missing argument stop being possible rather than
  /// merely unlikely, which leaves the parser checking meaning instead of
  /// guessing at syntax.
  ///
  /// [requireToolCall] drops the `ANSWER.` alternative for a turn where the user
  /// explicitly asked Finn to browse: the model then has one shape available
  /// and cannot decline.
  static IntentSamplerProfile searchDecisionSampler({
    required bool requireToolCall,
  }) =>
      IntentSamplerProfile(
        temperature: .0,
        topK: 1,
        topP: .10,
        minP: .05,
        repeatPenalty: 1.0,
        penaltyLastN: 32,
        grammar: decisionGrammarEnabled
            ? searchDecisionGrammar(requireToolCall: requireToolCall)
            : null,
      );

  /// Whether the decision turn runs grammar-constrained.
  ///
  /// Off by default: on the pinned llama.cpp the runtime rejects the grammar
  /// below, and although a rejected grammar now degrades to unconstrained
  /// sampling instead of killing the process, shipping an off turn that logs
  /// `FINN_GRAMMAR_REJECTED` on every search would be noise, not a feature.
  /// Build with `--dart-define=FINN_DECISION_GRAMMAR=true` to pick the
  /// investigation back up; the parser's own error is available through
  /// `LlamaLog.captureToFile`, which the engine worker already honours.
  static const bool decisionGrammarEnabled = bool.fromEnvironment(
    'FINN_DECISION_GRAMMAR',
  );

  /// GBNF for the search-decision turn.
  ///
  /// The `str` and `ws` rules are copied verbatim from the `json.gbnf` shipped
  /// with the pinned llama.cpp commit, because a grammar the runtime rejects is
  /// not a caught error at the sampler level; `SamplerFactory` now skips a
  /// grammar stage that fails to compile (`FINN_GRAMMAR_REJECTED`) rather than
  /// adding a null to the chain. Rules the variant cannot reach are omitted
  /// rather than left defined, so the grammar is exactly the language it means
  /// to accept.
  static String searchDecisionGrammar({required bool requireToolCall}) {
    const toolCalls = [
      r'obj ::= "{" ws "\"name\"" ws ":" ws "\"browser_search\"" ws "," ws "\"arguments\"" ws ":" ws "{" ws "\"query\"" ws ":" ws str ws "}" ws "}"',
      r'      | "{" ws "\"name\"" ws ":" ws "\"browser_find\"" ws "," ws "\"arguments\"" ws ":" ws "{" ws "\"query\"" ws ":" ws str ws "}" ws "}"',
      r'      | "{" ws "\"name\"" ws ":" ws "\"browser_open\"" ws "," ws "\"arguments\"" ws ":" ws "{" ws "\"url\"" ws ":" ws str ws "}" ws "}"',
    ];
    final rules = <String>[
      requireToolCall ? 'root ::= call' : 'root ::= answer | call',
      if (!requireToolCall) 'answer ::= "ANSWER."',
      'call ::= "<tool_call>" ws obj ws "</tool_call>"',
      ...toolCalls,
      r'str ::= "\"" ( [^"\\\x7F\x00-\x1F] | "\\" (["\\bfnrt] | "u" [0-9a-fA-F]{4}) )* "\""',
      r'ws ::= | " " | "\n" [ \t]{0,20}',
    ];
    return '${rules.join('\n')}\n';
  }

  static IntentSamplerProfile sampler(PromptIntent intent) => switch (intent) {
        PromptIntent.quickQuestion ||
        PromptIntent.recipe ||
        PromptIntent.howTo ||
        PromptIntent.translation ||
        PromptIntent.comparison ||
        PromptIntent.coding ||
        PromptIntent.analysis ||
        PromptIntent.highStakes =>
          const IntentSamplerProfile(
            temperature: .30,
            topK: 30,
            topP: .90,
            minP: .05,
            repeatPenalty: 1.05,
            penaltyLastN: 256,
          ),
        PromptIntent.creative => const IntentSamplerProfile(
            temperature: .85,
            topK: 60,
            topP: .95,
            minP: .03,
            repeatPenalty: 1.05,
            penaltyLastN: 256,
          ),
        _ => const IntentSamplerProfile(
            temperature: .70,
            topK: 40,
            topP: .90,
            minP: .05,
            repeatPenalty: 1.05,
            penaltyLastN: 256,
          ),
      };

  static String taskInstruction(PromptAnalysis analysis) {
    final language = analysis.language == PromptLanguage.unknown
        ? 'the language of the latest user message'
        : analysis.language.name;
    final common = 'Reply in $language unless asked otherwise. '
        'Be warm, natural, and conversational: match the user\'s tone and length '
        'and avoid robotic preamble. ';
    final task = switch (analysis.intent) {
      PromptIntent.recipe =>
        'Provide a practical recipe with common, appropriate ingredients and realistic quantities. '
            'Determine whether the dish is sweet or savoury. Include servings, prep and cooking '
            'time, oven temperature when relevant, an ingredient list, and numbered steps. '
            '${analysis.language == PromptLanguage.italian ? 'Use metric measurements. ' : ''}'
            'Respect dietary restrictions in the private configuration. If an essential detail is ambiguous, '
            'ask one concise clarification question. Do not list the finished dish itself as an ingredient.',
      PromptIntent.howTo => analysis.hardwareGuidance
          ? 'For hardware repair or upgrade guidance, first ask for the exact manufacturer and model before giving device-specific steps, '
              'and recommend its service manual or manufacturer specifications. For memory questions, explain that RAM may be soldered, '
              'socketed, or a combination; never assume two slots. Do not invent slot labels, slot sizes, screw locations, component layouts, '
              'or capacity limits. Give only cautious general steps, including electrostatic precautions and disconnecting external and '
              'internal power when appropriate. Never add citation numbers like [1] without real web sources.'
          : 'Give practical, ordered steps, include prerequisites and relevant safety cautions, and do not omit the final step.',
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
        'Answer the exact question directly and factually. Adapt detail dynamically: '
            'for broad overviews or historical subjects, provide structured highlights; '
            'for quick or simple questions, keep the answer concise and direct without unnecessary headings. '
            'For a how or why question, explain the mechanism and important conditions. '
            'Do not invent relationships, features, names, timings, or implementation details. Correct a false premise plainly. '
            'If a named or niche subject is uncertain, say so and ask for identifying context rather than substituting a similar-sounding subject.',
      PromptIntent.highStakes =>
        'Be cautious and factual, explain uncertainty and limits, and recommend qualified professional help when appropriate.',
      PromptIntent.greeting => 'Respond naturally and briefly.',
    };
    return '$common$task';
  }
}
