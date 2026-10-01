part of '../finn_accelerator.dart';

extension FinnAcceleratorPrompts on FinnAccelerator {
  String _renderPrompt(
    _ConversationSession entry,
    String prompt,
    List<LocalChatTurn> history, {
    String systemContext = '',
    String groundedContext = '',
    PromptAnalysis? analysis,
    bool includeTaskInstruction = true,
    required bool primeEmptyThinking,
    bool includeMediaMarker = false,
    int? mediaCount,
    String? attachedDocContext,
  }) {
    return _renderPromptText(
      primed: entry.primed,
      prompt: prompt,
      history: history,
      systemContext: systemContext,
      groundedContext: groundedContext,
      analysis: analysis,
      includeTaskInstruction: includeTaskInstruction,
      basePrefixReady: entry.basePrefixReady,
      primeEmptyThinking: primeEmptyThinking,
      includeMediaMarker: includeMediaMarker,
      mediaCount: mediaCount,
      attachedDocContext: attachedDocContext,
    );
  }

  String _renderPromptText({
    required bool primed,
    required String prompt,
    required List<LocalChatTurn> history,
    String systemContext = '',
    String groundedContext = '',
    PromptAnalysis? analysis,
    bool includeTaskInstruction = true,
    bool basePrefixReady = false,
    bool primeEmptyThinking = true,
    bool includeMediaMarker = false,
    int? mediaCount,
    String? attachedDocContext,
  }) {
    // Single source of truth for prompt rendering lives in [PromptFormatter];
    // the runtime only contributes its planned context size so history
    // trimming matches the context the engine will actually run with.
    return PromptFormatter.renderPromptText(
      primed: primed,
      prompt: prompt,
      history: history,
      contextTokens: _plan?.contextSize ?? 2048,
      systemContext: systemContext,
      groundedContext: groundedContext,
      analysis: analysis,
      includeTaskInstruction: includeTaskInstruction,
      basePrefixReady: basePrefixReady,
      primeEmptyThinking: primeEmptyThinking,
      includeMediaMarker: includeMediaMarker,
      mediaCount: mediaCount,
      attachedDocContext: attachedDocContext,
    );
  }

  @visibleForTesting
  String renderPromptForTest({
    required String prompt,
    List<LocalChatTurn> history = const [],
    String systemContext = '',
    String groundedContext = '',
    bool includeTaskInstruction = true,
    bool primed = false,
    bool basePrefixReady = false,
    bool primeEmptyThinking = true,
  }) {
    return _renderPromptText(
      primed: primed,
      prompt: prompt,
      history: history,
      systemContext: systemContext,
      groundedContext: groundedContext,
      analysis: const PromptIntentClassifier().classify(prompt),
      includeTaskInstruction: includeTaskInstruction,
      basePrefixReady: basePrefixReady,
      primeEmptyThinking: primeEmptyThinking,
    );
  }

  @visibleForTesting
  Map<String, int> promptTokenBreakdownForTest({
    required String prompt,
    List<LocalChatTurn> history = const [],
    String systemContext = '',
    bool primed = false,
    bool includeTaskInstruction = true,
    bool basePrefixReady = false,
    bool primeEmptyThinking = true,
  }) {
    int tokens(String value) => (value.length / 3.2).ceil();
    final analysis = const PromptIntentClassifier().classify(prompt);
    final priorRecipe = history.any(
      (turn) =>
          turn.role == 'assistant' &&
          PromptFormatter.isRecipeAnswer(turn.content),
    );
    final isRecipeFollowUp = analysis.intent == PromptIntent.recipe &&
        priorRecipe &&
        PromptFormatter.freshRecipeRequest.hasMatch(prompt);
    final rebuildContext = primed && isRecipeFollowUp;
    final task = (includeTaskInstruction || rebuildContext)
        ? PromptIntentPolicy.taskInstruction(analysis)
        : '';
    final replayHistory = isRecipeFollowUp
        ? PromptFormatter.historyWithoutRecipes(history)
        : history;
    final recent = (primed && !rebuildContext)
        ? const <LocalChatTurn>[]
        : _recentHistory(prompt, replayHistory, systemContext: systemContext);
    final base =
        primed || basePrefixReady ? '' : FinnAccelerator.finnSafetySystemPrompt;
    final privateText = primed ? '' : systemContext.trim();
    final historyText = recent.map((turn) => turn.content).join('\n');
    final rendered = _renderPromptText(
      primed: primed,
      prompt: prompt,
      history: history,
      systemContext: systemContext,
      analysis: analysis,
      includeTaskInstruction: includeTaskInstruction,
      basePrefixReady: basePrefixReady,
      primeEmptyThinking: primeEmptyThinking,
    );
    final baseTokens = tokens(base);
    final taskTokens = tokens(task);
    final privateTokens = tokens(privateText);
    final historyTokens = tokens(historyText);
    final promptTokens = tokens(prompt);
    final totalTokens = tokens(rendered);
    return <String, int>{
      'base_system': baseTokens,
      'task_instruction': taskTokens,
      'private_context': privateTokens,
      'history': historyTokens,
      'user_prompt': promptTokens,
      'template_wrappers': math.max(
        0,
        totalTokens -
            baseTokens -
            taskTokens -
            privateTokens -
            historyTokens -
            promptTokens,
      ),
      'total': totalTokens,
    };
  }

  List<LocalChatTurn> _recentHistory(
    String prompt,
    List<LocalChatTurn> history, {
    String systemContext = '',
  }) {
    return PromptFormatter.recentHistory(
      prompt,
      history,
      contextTokens: _plan?.contextSize ?? 2048,
      systemContext: systemContext,
    );
  }

  int _outputBudget(PromptAnalysis analysis) {
    // The intent budget is the *ceiling*, and the context window only caps it
    // from above. It used to be `max(desired, contextSize - 96)`, which made
    // the context bound always win: on a 4096-token context every turn was
    // allowed 4000 output tokens regardless of what was asked. The device eval
    // caught a real runaway on exactly that - one case emitted 4000 tokens and
    // took 230 seconds, nearly four times the rest of the suite put together,
    // and it was a question whose whole answer was one word.
    //
    // Generous relative to the intent (roughly 3x for a quick answer) so a
    // long-form answer is never truncated mid-thought, but a runaway now
    // stops instead of running to the end of the context.
    final contextSize = _plan?.contextSize ?? 2048;
    final desired = PromptIntentPolicy.desiredOutputTokens(analysis.intent);
    final budget = math.min(desired * 3, contextSize - 96);
    return analysis.spoken
        ? math.min(budget, PromptIntentPolicy.spokenOutputTokens)
        : budget;
  }

  @visibleForTesting
  int outputBudgetForTest(
    String prompt, {
    int? deviceCeiling,
    bool supported = true,
  }) {
    // Mirrors _outputBudget.
    final analysis = const PromptIntentClassifier().classify(prompt);
    final contextSize = deviceCeiling ?? _plan?.contextSize ?? 2048;
    final desired = PromptIntentPolicy.desiredOutputTokens(analysis.intent);
    return math.min(desired * 3, contextSize - 96);
  }
}
