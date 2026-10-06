part of '../finn_accelerator.dart';

extension FinnAcceleratorReplies on FinnAccelerator {
  Stream<String> generateReply(
    String prompt, {
    required String conversationId,
    List<LocalChatTurn> history = const [],
    String systemContext = '',
    String groundedContext = '',
    List<WebSource> sources = const [],
    PromptAnalysis? promptAnalysis,
    TtftTrace? trace,
    IntentSamplerProfile? samplerProfile,
    int? maxOutputTokens,
    bool agentPrompt = false,
    String agentStart = '',
  }) async* {
    if (_replyInFlight) {
      throw StateError('Finn is already generating a response.');
    }
    _replyInFlight = true;
    _lastSources = sources;
    try {
      yield* _generateReplyUnlocked(
        prompt,
        conversationId: conversationId,
        history: history,
        systemContext: systemContext,
        groundedContext: groundedContext,
        sources: sources,
        promptAnalysis: promptAnalysis,
        trace: trace,
        samplerProfile: samplerProfile,
        maxOutputTokens: maxOutputTokens,
        agentPrompt: agentPrompt,
        agentStart: agentStart,
      );
    } finally {
      _replyInFlight = false;
      // Hand the engine to the oldest queued caller (no-op when none waits).
      replyGate.signalNext();
    }
  }

  Stream<String> generateReplyQueued(
    String prompt, {
    required String conversationId,
    List<LocalChatTurn> history = const [],
    String systemContext = '',
    String groundedContext = '',
    List<WebSource> sources = const [],
    PromptAnalysis? promptAnalysis,
    TtftTrace? trace,
    IntentSamplerProfile? samplerProfile,
    int? maxOutputTokens,
    bool agentPrompt = false,
    String agentStart = '',
  }) async* {
    if (_replyInFlight) {
      final turn = replyGate.waitTurn();
      try {
        await turn;
      } finally {
        // If this stream was cancelled while waiting, give the reservation
        // back so capacity is not consumed by a dead waiter. A no-op when
        // the turn was already granted.
        replyGate.abandon(turn);
      }
    }
    yield* generateReply(
      prompt,
      conversationId: conversationId,
      history: history,
      systemContext: systemContext,
      groundedContext: groundedContext,
      promptAnalysis: promptAnalysis,
      trace: trace,
      samplerProfile: samplerProfile,
      maxOutputTokens: maxOutputTokens,
      agentPrompt: agentPrompt,
      agentStart: agentStart,
    );
  }

  Stream<String> generateEvaluationReply(
    String prompt, {
    required String path,
    required String modelLabel,
    required FinnModelTier tier,
    required String conversationId,
    List<LocalChatTurn> history = const [],
    TtftTrace? trace,
  }) async* {
    if (_replyInFlight) {
      throw StateError('Finn is already generating a response.');
    }
    _replyInFlight = true;
    final model = FinnModelSpec(
      tier: tier,
      name: modelLabel,
      parameterLabel: modelLabel,
      fileName: path,
      downloadUrl: '',
      expectedBytes: 0,
      sha256Digest: '',
    );
    if (model.sha256Digest.isEmpty && !FinnAccelerator.debugSkipSha256) {
      final message =
          'Evaluation model "$modelLabel" has no SHA-256 digest; refusing to '
          'load unverified weights.';
      if (kReleaseMode) {
        throw StateError(message);
      }
      debugPrint('FINN_EVAL_WARNING $message');
    }
    try {
      _lastGeneratingModel = model;
      yield* _cleanModelStream(
        _generateForModel(
          model,
          prompt,
          conversationId: conversationId,
          history: history,
          analysis: const PromptIntentClassifier().classify(prompt),
          modelPath: path,
          trace: trace,
          // The evaluation harness measures the raw model answer; it must not
          // trigger the model-driven web-search decision pass.
        ),
      );
    } finally {
      _replyInFlight = false;
    }
  }

  Stream<String> _generateReplyUnlocked(
    String prompt, {
    required String conversationId,
    required List<LocalChatTurn> history,
    required String systemContext,
    String groundedContext = '',
    List<WebSource> sources = const [],
    PromptAnalysis? promptAnalysis,
    TtftTrace? trace,
    IntentSamplerProfile? samplerProfile,
    int? maxOutputTokens,
    bool agentPrompt = false,
    String agentStart = '',
  }) async* {
    final analysis =
        promptAnalysis ?? const PromptIntentClassifier().classify(prompt);
    trace?.mark(TtftPhase.intentClassified);
    trace
      ?..modelTier = selected.name
      ..mark(TtftPhase.routeSelected);
    if (Platform.isAndroid) {
      // Cached per-turn refresh: avoids a platform-channel round trip plus
      // /proc/meminfo reads on every message (see _profileForTurn).
      final freshProfile = await _profileForTurn();
      if (_runtimes.isEmpty) _plan = DeviceProfiler.plan(freshProfile);
    }
    final model = selected;
    _lastGeneratingModel = model;
    if (agentPrompt) {
      // The agent reads its own protocol out of the raw reply (and strips
      // reasoning tags itself); the chat filters would eat a JSON file that
      // happens to look like a tool call.
      yield* _generateForModel(
        model,
        prompt,
        conversationId: conversationId,
        history: history,
        systemContext: systemContext,
        analysis: analysis,
        trace: trace,
        samplerProfile: samplerProfile,
        maxOutputTokens: maxOutputTokens,
        agentPrompt: true,
        agentStart: agentStart,
      );
      return;
    }
    yield* _cleanModelStream(
      _generateForModel(
        model,
        prompt,
        conversationId: conversationId,
        history: history,
        systemContext: systemContext,
        groundedContext: groundedContext,
        sources: sources,
        analysis: analysis,
        trace: trace,
        samplerProfile: samplerProfile,
        maxOutputTokens: maxOutputTokens,
      ),
      trace: trace,
    );
  }

  Stream<String> _cleanModelStream(
    Stream<String> source, {
    TtftTrace? trace,
  }) async* {
    final prefix = StringBuffer();
    var decided = false;
    var hidingThought = false;
    // Tool-call JSON that arrives without its <tool_call> wrapper is not prose
    // and must never reach the user; see [BareToolCallFilter].
    final toolCalls = BareToolCallFilter();
    // Tool tags themselves are dropped here so a tag that the model streams in
    // pieces cannot leak a fragment; see [ToolTagFilter].
    final toolTags = ToolTagFilter();

    String visible(String text) => toolCalls.add(toolTags.add(text));

    await for (final token in source) {
      if (decided) {
        final sanitized = visible(token);
        if (sanitized.isNotEmpty) {
          trace?.mark(TtftPhase.sanitizedToken);
          yield sanitized;
        }
        continue;
      }
      prefix.write(token);
      final buffered = prefix.toString();
      final trimmed = buffered.trimLeft();
      if (!hidingThought) {
        if ('<think>'.startsWith(trimmed)) continue;
        if (trimmed.startsWith('<think>')) {
          hidingThought = true;
        } else {
          decided = true;
          final sanitized = visible(trimmed);
          if (sanitized.isNotEmpty) {
            trace?.mark(TtftPhase.sanitizedToken);
            yield sanitized;
          }
          continue;
        }
      }
      final close = buffered.indexOf('</think>');
      if (close < 0) continue;
      final afterThought =
          buffered.substring(close + '</think>'.length).trimLeft();
      decided = true;
      final sanitized = visible(afterThought);
      if (sanitized.isNotEmpty) {
        trace?.mark(TtftPhase.sanitizedToken);
        yield sanitized;
      }
    }
    // An unterminated reasoning block is intentionally not surfaced.
    if (!decided && !hidingThought && prefix.isNotEmpty) {
      final sanitized = visible(prefix.toString());
      if (sanitized.isNotEmpty) {
        trace?.mark(TtftPhase.sanitizedToken);
        yield sanitized;
      }
    }
    // Close the filters in feed order: text passes through the tag filter and
    // then the bare-call filter, so anything the tag filter releases still has
    // to clear the call filter before it can be shown.
    final tail = toolCalls.add(toolTags.flush()) + toolCalls.flush();
    if (tail.isNotEmpty) {
      trace?.mark(TtftPhase.sanitizedToken);
      yield tail;
    }
  }
}
