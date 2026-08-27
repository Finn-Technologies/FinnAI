import 'dart:math' as math;
import '../../inference/prompt_intent.dart';
import '../finn_engine_types.dart';

/// Formats and constructs prompts for FinnAI-Accelerator inference.
class PromptFormatter {
  const PromptFormatter._();

  static const finnSafetySystemPrompt = '''
You are Finn AI, a warm, sharp, private on-device assistant. Be natural and
truly helpful: match the user's tone and language, and keep replies as long as
the question needs. Think before you answer, state uncertainty instead of
guessing, and never invent facts, citations, names, numbers, or technical
details. Correct false premises kindly; if you don't know, say so plainly and
offer a useful next step. Avoid robotic filler, apologies, and repetition.

You can search the browser when you need up-to-date web information by issuing a tool call:
<tool_call>
{"name": "browser_search", "arguments": {"query": "<query>"}}
</tool_call>

Cite web and browser material inline as [1], [2]; never append a separate "Sources"
section or empty bullet list.

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

  static final RegExp _freshRecipeRequest = RegExp(
    r'\b(come fare|come si fa|come faccio|come preparare|come cucinare|'
    r'fare una|fare la|preparare una|preparare la|facciamo una|'
    r'how to make|how to cook|how to bake|how do i make|'
    r'recipe for|recipe of|recipe to make|ricetta)\b',
    caseSensitive: false,
  );

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
      buffer
        ..write('<|im_start|>user\n')
        ..write(prompt)
        ..write('<|im_end|>\n<|im_start|>assistant\n');
    } else {
      buffer
        ..write('<|im_end|>\n')
        ..write('<|im_start|>system\n')
        ..write(directive)
        ..write('<|im_end|>\n')
        ..write('<|im_start|>user\n')
        ..write(prompt)
        ..write('<|im_end|>\n<|im_start|>assistant\n');
    }
    return buffer.toString();
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
    String? attachedDocContext,
  }) {
    final promptAnalysis =
        analysis ?? const PromptIntentClassifier().classify(prompt);
    final priorRecipe = history.any(
      (turn) => turn.role == 'assistant' && isRecipeAnswer(turn.content),
    );
    final isRecipeFollowUp =
        promptAnalysis.intent == PromptIntent.recipe &&
        priorRecipe &&
        _freshRecipeRequest.hasMatch(prompt);

    final rebuildContext = primed && isRecipeFollowUp;
    final effectiveIncludeTask = includeTaskInstruction || rebuildContext;
    final replayHistory = isRecipeFollowUp
        ? historyWithoutRecipes(history)
        : history;
    final buffer = StringBuffer();
    if (!primed || rebuildContext) {
      if (!basePrefixReady) buffer.write(baseSystemPrefix);
      buffer
        ..write('<|im_start|>system\n')
        ..write(PromptIntentPolicy.taskInstruction(promptAnalysis))
        ..write('<|im_end|>\n');
      writePrivateContext(buffer, systemContext);
      writeGroundedContext(buffer, groundedContext);
      if (attachedDocContext != null && attachedDocContext.isNotEmpty) {
        buffer
          ..write('<|im_start|>system\n')
          ..write(attachedDocContext)
          ..write('<|im_end|>\n');
      }
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
      if (attachedDocContext != null && attachedDocContext.isNotEmpty) {
        buffer
          ..write('<|im_start|>system\n')
          ..write(attachedDocContext)
          ..write('<|im_end|>\n');
      }
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
    buffer.write('<|im_start|>user\n');
    if (includeMediaMarker) {
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
    final isGrounded = value.contains('RETRIEVED WEB RESULTS');
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
