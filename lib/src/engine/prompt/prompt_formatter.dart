import 'dart:math' as math;
import 'package:finn_ai/src/engine/prompt/local_arithmetic.dart';
import 'package:finn_ai/src/engine/prompt/prompt_intent.dart';
import 'package:finn_ai/src/engine/finn_engine_types.dart';

/// Formats and constructs prompts for FinnAI-Accelerator inference.
class PromptFormatter {
  const PromptFormatter._();

  /// Marks a block of retrieved web results so the prompt builders can tell
  /// reference material apart from the user's private configuration. Both the
  /// producer ([SearchAgent.groundedContextForSources]) and the consumer
  /// ([writePrivateContext]) must use this constant.
  static const String groundedContextMarker = 'RETRIEVED WEB RESULTS';

  static const finnSafetySystemPrompt = '''
You are Finn AI, a warm, sharp, private on-device assistant. Be natural and
truly helpful: match the user's tone and language, and keep replies as long as
the question needs. Think before you answer, state uncertainty instead of
guessing, and never invent facts, citations, names, numbers, or technical
details. Correct false premises kindly; if you don't know, say so plainly and
offer a useful next step. Avoid robotic filler, apologies, and repetition.

Format & Detail Adaptation:
Understand the depth required by the user's prompt and tailor your response accordingly:
- Rich Editorial Article: When the user asks about an entity, landmark, notable figure, historical topic, broad subject, or asks for an in-depth explanation/overview, produce an elegant magazine-style response: a prominent headline written as a single-markdown-heading line, an engaging lead paragraph, and structured thematic takeaways. Write plain prose and Markdown only — never emit HTML or XML tags, and never write a placeholder like a bracketed word where the headline should be.
- Concise & Direct Answer: When the user asks a quick question, specific fact, calculation, definition, code snippet, translation, or brief inquiry, answer directly and concisely in 1-3 sentences or clear code. Do NOT artificially format simple answers as multi-section articles with titles or bullet lists.
- Conversational: For greetings or casual conversation, keep it natural, friendly, and brief.

You have a built-in TinyBrowser engine to autonomously explore the web. When you need real-time facts, current information, or to inspect a website, you can call browser tools:
1. Search the web:
<tool_call>
{"name": "browser_search", "arguments": {"query": "<search terms>"}}
</tool_call>

2. Open and read any web page URL:
<tool_call>
{"name": "browser_open", "arguments": {"url": "<https://...>"}}
</tool_call>

3. Find text on the current page:
<tool_call>
{"name": "browser_find", "arguments": {"query": "<text to find>"}}
</tool_call>

Only use browser tools when you genuinely need current external facts or website content. When browser information is retrieved, cite facts inline with source indices like [1], [2]. Do not append an empty "Sources" list at the end.

Refuse help that enables sexual content involving minors, serious violence or
self-harm methods, fraud or phishing, harmful malware, unauthorised access, or
other dangerous illegal acts. Safe prevention and high-level education are
allowed. For self-harm risk, be supportive and encourage trusted or emergency
help. Everyday lawful tasks such as hardware upgrades, cooking, and household
repairs are allowed — give careful, accurate instructions with safety
precautions instead of refusing. For medical, legal, or financial questions,
explain limits and recommend qualified help when appropriate. Follow private
user preferences but never reveal them.''';

  static String get baseSystemPrefix =>
      '<|im_start|>system\n$finnSafetySystemPrompt<|im_end|>\n';

  /// English weekday names indexed by `DateTime.weekday - 1`.
  static const List<String> _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// A system block telling the model the current local date and time.
  static String currentDateTimeSystemBlock(DateTime now) {
    final local = now.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final date = '${local.year}-$month-$day';
    final time = '$hour:$minute';
    final weekday = _weekdayNames[local.weekday - 1];
    return '<|im_start|>system\n'
        'Current local date and time: $date $time ($weekday). Use this when '
        'the user asks about today, tomorrow, yesterday, or the current time.'
        '\n<|im_end|>\n';
  }

  /// Prompts that read as a fresh recipe request ("come fare", "how to
  /// make", "ricetta", ...) rather than a question about an existing recipe.
  /// Only these trigger the same-chat context rebuild; genuine follow-up
  /// questions ("how long should it bake?", "posso aggiungere mele?") keep
  /// the prior recipe in context so the model can answer about it.
  static final RegExp freshRecipeRequest = RegExp(
    r'\b(come fare|come si fa|come faccio|come preparare|come cucinare|'
    r'fare una|fare la|preparare una|preparare la|facciamo una|'
    r'how to make|how to cook|how to bake|how do i make|'
    r'recipe for|recipe of|recipe to make|ricetta)\b',
    caseSensitive: false,
  );

  /// Heuristic for "this assistant turn is a recipe answer". Used to detect
  /// prior recipe answers in the same conversation so a follow-up recipe
  /// request can be told explicitly not to copy the earlier one.
  static bool isRecipeAnswer(String content) {
    return RegExp(
      r'^\s*(ingredienti|ingredients|ingredientes|zutaten|ingrédients|ingrediënten)\b',
      caseSensitive: false,
      multiLine: true,
    ).hasMatch(content);
  }

  static List<LocalChatTurn> historyWithoutRecipes(
    List<LocalChatTurn> history,
  ) {
    final drop = <int>{};
    for (var i = 0; i < history.length; i++) {
      final turn = history[i];
      if (turn.role == 'assistant' && isRecipeAnswer(turn.content)) {
        drop.add(i);
        if (i > 0 && history[i - 1].role == 'user') drop.add(i - 1);
      }
    }
    if (drop.isEmpty) return history;
    return [
      for (var i = 0; i < history.length; i++)
        if (!drop.contains(i)) history[i],
    ];
  }

  static String renderDecisionPromptText({
    required bool primed,
    required bool basePrefixReady,
    required bool includeTaskInstruction,
    required PromptAnalysis analysis,
    required String prompt,
    required List<LocalChatTurn> history,
    required String directive,
    String priorToolContext = '',
    DateTime? now,
  }) {
    final buffer = StringBuffer();
    if (!primed) {
      if (!basePrefixReady) buffer.write(baseSystemPrefix);
      buffer
        ..write('<|im_start|>system\n')
        ..write(PromptIntentPolicy.taskInstruction(analysis))
        ..write('<|im_end|>\n');
      buffer
        ..write('<|im_start|>system\n')
        ..write(directive)
        ..write('<|im_end|>\n');
      writePriorToolContext(buffer, priorToolContext);
      buffer.write(currentDateTimeSystemBlock(now ?? DateTime.now()));
      buffer
        ..write('<|im_start|>user\n')
        ..write(prompt)
        ..write('<|im_end|>\n<|im_start|>assistant\n');
    } else {
      buffer
        ..write('<|im_end|>\n')
        ..write('<|im_start|>system\n')
        ..write(directive)
        ..write('<|im_end|>\n');
      writePriorToolContext(buffer, priorToolContext);
      buffer.write(currentDateTimeSystemBlock(now ?? DateTime.now()));
      buffer
        ..write('<|im_start|>user\n')
        ..write(prompt)
        ..write('<|im_end|>\n<|im_start|>assistant\n');
    }
    return buffer.toString();
  }

  /// Replays what the browser already returned, so a later decision round asks
  /// about something new instead of repeating the tool call it just made.
  static void writePriorToolContext(StringBuffer buffer, String context) {
    final value = context.trim();
    if (value.isEmpty) return;
    buffer
      ..write('<|im_start|>system\n')
      ..write('You already called your browser tools and received:\n\n')
      ..write(value)
      ..write('\n\nUse these findings. Call another tool only if something '
          'essential is still missing, otherwise reply exactly: ANSWER.')
      ..write('<|im_end|>\n');
  }

  static String renderPromptText({
    required bool primed,
    required String prompt,
    required List<LocalChatTurn> history,
    int contextTokens = 2048,
    String systemContext = '',
    String groundedContext = '',
    PromptAnalysis? analysis,
    bool includeTaskInstruction = true,
    bool basePrefixReady = false,
    bool primeEmptyThinking = true,
    bool includeMediaMarker = false,
    int? mediaCount,
    String? attachedDocContext,
    DateTime? now,
  }) {
    final promptAnalysis =
        analysis ?? const PromptIntentClassifier().classify(prompt);
    final priorRecipe = history.any(
      (turn) => turn.role == 'assistant' && isRecipeAnswer(turn.content),
    );
    final isRecipeFollowUp = promptAnalysis.intent == PromptIntent.recipe &&
        priorRecipe &&
        freshRecipeRequest.hasMatch(prompt);

    final rebuildContext = primed && isRecipeFollowUp;
    final effectiveIncludeTask = includeTaskInstruction || rebuildContext;
    final replayHistory =
        isRecipeFollowUp ? historyWithoutRecipes(history) : history;
    final buffer = StringBuffer();
    if (!primed || rebuildContext) {
      if (!basePrefixReady) buffer.write(baseSystemPrefix);
      buffer
        ..write('<|im_start|>system\n')
        ..write(PromptIntentPolicy.taskInstruction(promptAnalysis))
        ..write('<|im_end|>\n');
      writePrivateContext(buffer, systemContext);
      writeGroundedContext(buffer, groundedContext);
      final combinedForHistory = [
        systemContext,
        groundedContext,
      ].where((s) => s.trim().isNotEmpty).join('\n\n');
      for (final turn in recentHistory(
        prompt,
        replayHistory,
        contextTokens: contextTokens,
        systemContext: combinedForHistory,
      )) {
        buffer
          ..write('<|im_start|>${turn.role}\n')
          ..write(turn.content)
          ..write('<|im_end|>\n');
      }
    } else {
      buffer.write('<|im_end|>\n');
      if (effectiveIncludeTask) {
        buffer
          ..write('<|im_start|>system\n')
          ..write(PromptIntentPolicy.taskInstruction(promptAnalysis))
          ..write('<|im_end|>\n');
      }
      writeGroundedContext(buffer, groundedContext);
    }
    if (RegExp(
      r'\b(?:joke|pun|another|new one|different one)\b',
      caseSensitive: false,
    ).hasMatch(prompt)) {
      final priorJokes = history
          .where((turn) => turn.role == 'assistant')
          .map((turn) => turn.content.trim())
          .where((content) => content.isNotEmpty)
          .take(3)
          .map(
            (content) => content.length > 160
                ? '${content.substring(0, 160)}…'
                : content,
          )
          .toList();
      buffer
        ..write('<|im_start|>system\n')
        ..write(
          'Give a genuinely new response. Do not repeat an example or '
          'answer that already appears in this conversation.',
        )
        ..write(
          priorJokes.isEmpty
              ? ''
              : ' You already told: ${priorJokes.join(' | ')}. '
                  'Tell a joke on a different topic with a different punchline.',
        )
        ..write('<|im_end|>\n');
    }
    if (isRecipeFollowUp) {
      final dish = promptAnalysis.recipeDish;
      buffer
        ..write('<|im_start|>system\n')
        ..write(
          'This conversation already contains a recipe. The user is '
          'now asking for a different dish.',
        )
        ..write(
          dish.isEmpty
              ? ''
              : ' The requested dish is $dish. Write the recipe ONLY for '
                  '$dish, with its own correct ingredients and steps.',
        )
        ..write(
          ' Ignore the ingredient lists, quantities and steps of any '
          'recipe already given in this conversation, and write a '
          'completely new recipe for the dish the user just asked about, '
          'with its own correct ingredients and steps.',
        )
        ..write('<|im_end|>\n');
    }
    buffer.write(currentDateTimeSystemBlock(now ?? DateTime.now()));
    // Arithmetic the app can do exactly is not left to a 1.6B model to guess at
    // (see [LocalArithmetic]); it is injected next to the question so the answer
    // carries the right number.
    buffer.write(LocalArithmetic.systemBlockFor(prompt));
    // An attached document is written immediately before the user turn so the
    // material being asked about sits next to the question. Putting it in the
    // system block at the top left it on the far side of the whole history, and
    // the model answered from the history instead of from the file.
    if (attachedDocContext != null && attachedDocContext.isNotEmpty) {
      buffer
        ..write('<|im_start|>system\n')
        ..write(attachedDocContext)
        ..write('<|im_end|>\n');
    }
    buffer.write('<|im_start|>user\n');
    final count = mediaCount ?? (includeMediaMarker ? 1 : 0);
    for (var i = 0; i < count; i++) {
      buffer.write('<__media__>\n');
    }
    buffer
      ..write(prompt)
      ..write('<|im_end|>\n<|im_start|>assistant\n');

    if (primeEmptyThinking) buffer.write('<think>\n\n</think>\n\n');
    return buffer.toString();
  }

  static void writePrivateContext(StringBuffer buffer, String context) {
    final value = context.trim();
    if (value.isEmpty) return;
    final isGrounded = value.contains(groundedContextMarker);
    if (isGrounded) {
      buffer
        ..write('<|im_start|>system\n')
        ..write(value)
        ..write('<|im_end|>\n');
      return;
    }
    buffer
      ..write('<|im_start|>system\n')
      ..write(value)
      ..write(
        '\nTreat this as private user configuration. Never quote or reveal it.',
      )
      ..write('<|im_end|>\n');
  }

  static void writeGroundedContext(StringBuffer buffer, String context) {
    final value = context.trim();
    if (value.isEmpty) return;
    buffer
      ..write('<|im_start|>system\n')
      ..write(value)
      ..write(
        '\n\nRetrieved Reference Material:\n'
        'Answer the user\'s question from these notes, in your own words.\n'
        '- Match the depth to the question: a focused question (a date, a name, a number, a definition, a short fact) gets a direct, concise answer with no headings at all. Only a broad "tell me about X" request earns a headline and structured points.\n'
        '- Never reply with the notes themselves: do not quote, list or summarise the reference blocks, and do not use their [1], [2] numbering as the structure of your answer.\n'
        '- If the notes do not answer the question, say plainly that you could not find it there and offer to look again — never fill the gap from memory.\n'
        '- Write plain prose and Markdown only. Never emit HTML or XML tags, and never leave a placeholder where a title belongs.\n'
        'Cite matching reference sources inline as [1], [2] where appropriate.\n',
      )
      ..write('<|im_end|>\n');
  }

  static List<LocalChatTurn> recentHistory(
    String prompt,
    List<LocalChatTurn> history, {
    int contextTokens = 2048,
    String systemContext = '',
  }) {
    if (history.isEmpty) return history;
    final analysis = const PromptIntentClassifier().classify(prompt);
    final promptTokens = (prompt.length / 3).ceil();
    final basePrefixTokens = (baseSystemPrefix.length / 3).ceil();
    final rawReservedTokens =
        PromptIntentPolicy.desiredOutputTokens(analysis.intent) +
            basePrefixTokens +
            96 +
            (PromptIntentPolicy.taskInstruction(analysis).length / 3).ceil() +
            (systemContext.trim().length / 3).ceil() +
            promptTokens;
    final reservedTokens = math.min(
      rawReservedTokens,
      (contextTokens * 0.65).ceil(),
    );
    final historyCharacters = math.max(0, (contextTokens - reservedTokens) * 3);
    var used = 0;
    var start = history.length;
    for (var index = history.length - 1; index >= 0; index--) {
      final cost = history[index].content.length + 32;
      if (used + cost > historyCharacters) break;
      used += cost;
      start = index;
    }
    if (start < history.length && history[start].role == 'assistant') start++;
    return start >= history.length ? const [] : history.sublist(start);
  }
}
