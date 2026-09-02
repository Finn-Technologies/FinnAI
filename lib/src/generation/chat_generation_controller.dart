import 'dart:async';

import 'package:flutter/foundation.dart';
import '../conversations/conversation_store.dart';
import '../inference/finn_inference.dart';
import '../inference/prompt_intent.dart';
import '../inference/ttft_metrics.dart';
import '../search/web_search_service.dart';

enum ChatGenerationState { preparing, generating, stopping, complete, error }

@immutable
class ChatGenerationJob {
  const ChatGenerationJob({
    required this.generationId,
    required this.conversationId,
    required this.assistantMessageId,
    required this.originalPrompt,
    required this.modelName,
    required this.state,
    required this.responseText,
    required this.startedAt,
    required this.cancellationRequested,
    required this.continuationCount,
    required this.epoch,
    this.finishReason,
    this.errorMessage,
    this.sources = const [],
  });

  final String generationId;
  final String conversationId;
  final String assistantMessageId;
  final String originalPrompt;
  final String modelName;
  final ChatGenerationState state;
  final String responseText;
  final GenerationFinishReason? finishReason;
  final DateTime startedAt;
  final bool cancellationRequested;
  final int continuationCount;
  final int epoch;
  final List<WebSource> sources;
  final String? errorMessage;

  bool get busy =>
      state == ChatGenerationState.preparing ||
      state == ChatGenerationState.generating ||
      state == ChatGenerationState.stopping;

  ChatGenerationJob copyWith({
    String? modelName,
    ChatGenerationState? state,
    String? responseText,
    GenerationFinishReason? finishReason,
    bool? cancellationRequested,
    String? errorMessage,
    List<WebSource>? sources,
  }) => ChatGenerationJob(
    generationId: generationId,
    conversationId: conversationId,
    assistantMessageId: assistantMessageId,
    originalPrompt: originalPrompt,
    modelName: modelName ?? this.modelName,
    state: state ?? this.state,
    responseText: responseText ?? this.responseText,
    finishReason: finishReason ?? this.finishReason,
    startedAt: startedAt,
    cancellationRequested: cancellationRequested ?? this.cancellationRequested,
    continuationCount: continuationCount,
    epoch: epoch,
    sources: sources ?? this.sources,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

@immutable
class CancellationMetrics {
  const CancellationMetrics({
    required this.nativeAcknowledgement,
    required this.composerUnblocked,
    required this.lateTokenCount,
    required this.engineResetRequired,
  });

  final Duration nativeAcknowledgement;
  final Duration composerUnblocked;
  final int lateTokenCount;
  final bool engineResetRequired;
}

abstract interface class ChatInferenceRuntime implements Listenable {
  InferencePhase get phase;
  String get status;
  String get selectedModelName;
  String get lastGeneratingModelName;
  GenerationReport? get lastGenerationReport;

  Stream<String> generateReply(
    String prompt, {
    required String conversationId,
    required List<LocalChatTurn> history,
    required String systemContext,
    PromptAnalysis? promptAnalysis,
    TtftTrace? trace,
  });

  Future<void> stopGeneration();
  Future<void> resetAfterCancellationTimeout();
}

class FinnChatInferenceRuntime implements ChatInferenceRuntime {
  FinnChatInferenceRuntime(this.inference);

  final FinnInference inference;

  @override
  InferencePhase get phase => switch (inference.phase) {
    InferencePhase.idle => InferencePhase.idle,
    InferencePhase.downloading => InferencePhase.downloading,
    InferencePhase.loading => InferencePhase.loading,
    InferencePhase.generating => InferencePhase.generating,
    InferencePhase.error => InferencePhase.error,
  };
  @override
  String get status => inference.status;
  @override
  String get selectedModelName => inference.selected.name;
  @override
  String get lastGeneratingModelName => inference.lastGeneratingModel.name;
  @override
  GenerationReport? get lastGenerationReport => inference.lastGenerationReport;
  List<WebSource> get lastSources => inference.lastSources;
  int get tokenPaintIntervalMs => inference.plan?.tokenPaintIntervalMs ?? 50;

  @override
  void addListener(VoidCallback listener) => inference.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      inference.removeListener(listener);

  @override
  Stream<String> generateReply(
    String prompt, {
    required String conversationId,
    required List<LocalChatTurn> history,
    required String systemContext,
    PromptAnalysis? promptAnalysis,
    TtftTrace? trace,
  }) => generateReplyWithContext(
    prompt,
    conversationId: conversationId,
    history: history,
    systemContext: systemContext,
    promptAnalysis: promptAnalysis,
    trace: trace,
  );

  Stream<String> generateReplyWithContext(
    String prompt, {
    required String conversationId,
    required List<LocalChatTurn> history,
    required String systemContext,
    String groundedContext = '',
    PromptAnalysis? promptAnalysis,
    TtftTrace? trace,
    bool enableSearchDecision = true,
  }) => inference.generateReply(
    prompt,
    conversationId: conversationId,
    history: history,
    systemContext: systemContext,
    groundedContext: groundedContext,
    promptAnalysis: promptAnalysis,
    trace: trace,
    enableSearchDecision: enableSearchDecision,
  );

  @override
  Future<void> stopGeneration() => inference.stopGeneration();

  @override
  Future<void> resetAfterCancellationTimeout() =>
      inference.resetAfterCancellationTimeout();
}

/// Owns the single native chat generation independently of visible navigation.
class ChatGenerationController extends ChangeNotifier {
  ChatGenerationController({
    required this.conversations,
    required this.runtime,
    this.persistenceInterval = const Duration(milliseconds: 1500),
    this.cancellationTimeout = const Duration(seconds: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    runtime.addListener(_runtimeChanged);
  }

  static final instance = ChatGenerationController(
    conversations: ConversationStore.instance,
    runtime: FinnChatInferenceRuntime(FinnInference.instance),
  );

  final ConversationStore conversations;
  final ChatInferenceRuntime runtime;
  final DateTime Function() _clock;
  final Duration persistenceInterval;
  final Duration cancellationTimeout;

  ChatGenerationJob? _job;
  ChatGenerationJob? get job => _job;
  ChatGenerationJob? get activeJob => _job?.busy == true ? _job : null;
  bool get busy => activeJob != null;
  StreamSubscription<String>? _subscription;
  Timer? _persistenceTimer;
  Timer? _notifyTimer;
  Future<void>? _stopFuture;
  /// Incremental token accumulator for the running job. Appending tokens to
  /// a StringBuffer avoids the O(n^2) re-allocation of string concatenation
  /// on every token; the job still exposes the same final [ChatGenerationJob.responseText].
  StringBuffer? _responseText;
  var _epoch = 0;
  var _idSequence = 0;
  var _lateTokenCount = 0;
  var _disposed = false;
  CancellationMetrics? _lastCancellationMetrics;
  CancellationMetrics? get lastCancellationMetrics => _lastCancellationMetrics;
  TtftTrace? _activeTrace;
  TtftTrace? get activeTrace => _activeTrace;
  TtftTrace? get lastTtftTrace => _activeTrace;

  TtftTrace createTtftTrace(String conversationId) =>
      TtftTrace(generationId: _nextId(), conversationId: conversationId);

  String get progressLabel {
    final current = activeJob;
    if (current == null) return 'Ready';
    if (current.state == ChatGenerationState.stopping) return 'Stopping';
    if (runtime.phase == InferencePhase.downloading ||
        runtime.phase == InferencePhase.loading) {
      return 'Preparing locally';
    }
    if (current.state == ChatGenerationState.preparing) {
      return 'Understanding your request';
    }
    return 'Finn is typing…';
  }

  Future<ChatGenerationJob?> start({
    required String conversationId,
    required String prompt,
    required List<LocalChatTurn> history,
    required String systemContext,
    String? imagePath,
    String groundedContext = '',
    String responseSuffix = '',
    List<WebSource> sources = const [],
    TtftTrace? trace,
  }) async {
    if (busy) return null;
    final timing = trace ?? createTtftTrace(conversationId);
    final generationId = timing.generationId;
    final analysis = const PromptIntentClassifier().classify(prompt);
    timing.mark(TtftPhase.intentClassified);
    final assistant = conversations.beginExchangeInConversation(
      conversationId,
      prompt,
      imagePath: imagePath,
      modelTier: runtime.selectedModelName,
      generationId: generationId,
    );
    // Avoid duplicating the image turn when history already ends with the same prompt+image (bytes path).
    final hasImageInHistory = history.isNotEmpty &&
        history.last.imagePath == imagePath &&
        history.last.content == prompt;
    final effectiveHistory = hasImageInHistory
        ? history
        : [
            ...history,
            if (imagePath != null)
              LocalChatTurn(role: 'user', content: prompt, imagePath: imagePath),
          ];
    return _listen(
      generationId: generationId,
      conversationId: conversationId,
      assistant: assistant,
      originalPrompt: prompt,
      runtimePrompt: prompt,
      history: imagePath != null ? effectiveHistory : history,
      systemContext: systemContext,
      groundedContext: groundedContext,
      responseSuffix: responseSuffix,
      sources: sources,
      analysis: analysis,
      initialText: '',
      continuationCount: 0,
      trace: timing,
    );
  }

  Future<ChatGenerationJob?> continueResponse({
    required String conversationId,
    required String assistantMessageId,
    required String originalPrompt,
    required List<LocalChatTurn> history,
    required String systemContext,
    String groundedContext = '',
    String responseSuffix = '',
    List<WebSource> sources = const [],
  }) async {
    if (busy) return null;
    final generationId = _nextId();
    final timing = TtftTrace(
      generationId: generationId,
      conversationId: conversationId,
    );
    final analysis = const PromptIntentClassifier().classify(originalPrompt);
    timing.mark(TtftPhase.intentClassified);
    final assistant = conversations.beginContinuation(
      conversationId: conversationId,
      messageId: assistantMessageId,
      generationId: generationId,
    );
    if (assistant == null) return null;
    return _listen(
      generationId: generationId,
      conversationId: conversationId,
      assistant: assistant,
      originalPrompt: originalPrompt,
      runtimePrompt: FinnInference.continuationPrompt,
      history: history,
      systemContext: systemContext,
      groundedContext: groundedContext,
      responseSuffix: responseSuffix,
      sources: sources,
      analysis: analysis,
      initialText: assistant.text,
      continuationCount: assistant.continuationCount,
      trace: timing,
      // Continuations reuse the original turn's search decision + sources
      // (computed in the UI); the continuation prompt itself must not re-trigger
      // the decision pass.
      enableSearchDecision: false,
    );
  }

  /// Re-runs the model on the same user turn, replacing the previous
  /// assistant reply in place (see [ConversationStore.beginRegeneration]).
  /// The search decision pass runs again so a bad answer can be re-grounded.
  Future<ChatGenerationJob?> regenerate({
    required String conversationId,
    required String assistantMessageId,
    required String originalPrompt,
    required List<LocalChatTurn> history,
    required String systemContext,
    String groundedContext = '',
    String responseSuffix = '',
    List<WebSource> sources = const [],
  }) async {
    if (busy) return null;
    final generationId = _nextId();
    final timing = TtftTrace(
      generationId: generationId,
      conversationId: conversationId,
    );
    final analysis = const PromptIntentClassifier().classify(originalPrompt);
    timing.mark(TtftPhase.intentClassified);
    final assistant = conversations.beginRegeneration(
      conversationId: conversationId,
      messageId: assistantMessageId,
      generationId: generationId,
    );
    if (assistant == null) return null;
    return _listen(
      generationId: generationId,
      conversationId: conversationId,
      assistant: assistant,
      originalPrompt: originalPrompt,
      runtimePrompt: originalPrompt,
      history: history,
      systemContext: systemContext,
      groundedContext: groundedContext,
      responseSuffix: responseSuffix,
      sources: sources,
      analysis: analysis,
      initialText: '',
      continuationCount: assistant.continuationCount,
      trace: timing,
    );
  }

  /// Answers an existing user turn (e.g. after an edit) by appending a new
  /// assistant message, without adding a duplicate user message.
  Future<ChatGenerationJob?> replyToExisting({
    required String conversationId,
    required String prompt,
    required List<LocalChatTurn> history,
    required String systemContext,
    String groundedContext = '',
    String responseSuffix = '',
    List<WebSource> sources = const [],
  }) async {
    if (busy) return null;
    final timing = TtftTrace(
      generationId: _nextId(),
      conversationId: conversationId,
    );
    final generationId = timing.generationId;
    final analysis = const PromptIntentClassifier().classify(prompt);
    timing.mark(TtftPhase.intentClassified);
    final assistant = conversations.beginAssistantReply(
      conversationId: conversationId,
      generationId: generationId,
      modelTier: runtime.selectedModelName,
    );
    if (assistant == null) return null;
    return _listen(
      generationId: generationId,
      conversationId: conversationId,
      assistant: assistant,
      originalPrompt: prompt,
      runtimePrompt: prompt,
      history: history,
      systemContext: systemContext,
      groundedContext: groundedContext,
      responseSuffix: responseSuffix,
      sources: sources,
      analysis: analysis,
      initialText: '',
      continuationCount: 0,
      trace: timing,
    );
  }

  Timer? _preparingGuard;

  Stream<String> _generateWithContext(
    String prompt, {
    required String conversationId,
    required List<LocalChatTurn> history,
    required String systemContext,
    required String groundedContext,
    required PromptAnalysis analysis,
    required TtftTrace trace,
    required bool enableSearchDecision,
  }) {
    final current = runtime;
    if (current is FinnChatInferenceRuntime) {
      return current.generateReplyWithContext(
        prompt,
        conversationId: conversationId,
        history: history,
        systemContext: systemContext,
        groundedContext: groundedContext,
        promptAnalysis: analysis,
        trace: trace,
        enableSearchDecision: enableSearchDecision,
      );
    }
    return current.generateReply(
      prompt,
      conversationId: conversationId,
      history: history,
      systemContext: systemContext,
      promptAnalysis: analysis,
      trace: trace,
    );
  }

  ChatGenerationJob _listen({
    required String generationId,
    required String conversationId,
    required ConversationMessage assistant,
    required String originalPrompt,
    required String runtimePrompt,
    required List<LocalChatTurn> history,
    required String systemContext,
    String groundedContext = '',
    required String responseSuffix,
    required List<WebSource> sources,
    required PromptAnalysis analysis,
    required String initialText,
    required int continuationCount,
    required TtftTrace trace,
    bool enableSearchDecision = true,
  }) {
    final epoch = ++_epoch;
    _lateTokenCount = 0;
    _activeTrace = trace;
    _responseText = StringBuffer(initialText);
    _job = ChatGenerationJob(
      generationId: generationId,
      conversationId: conversationId,
      assistantMessageId: assistant.id,
      originalPrompt: originalPrompt,
      modelName: runtime.selectedModelName,
      state: ChatGenerationState.preparing,
      responseText: initialText,
      startedAt: _clock(),
      cancellationRequested: false,
      continuationCount: continuationCount,
      epoch: epoch,
      sources: sources,
    );
    if (!_disposed) notifyListeners();
    _preparingGuard?.cancel();
    _preparingGuard = Timer(const Duration(seconds: 90), () {
      final current = _job;
      if (current == null ||
          current.generationId != generationId ||
          current.epoch != epoch ||
          !current.busy ||
          current.state != ChatGenerationState.preparing) {
        return;
      }
      debugPrint('FINN_PREPARING_GUARD fired generation=$generationId');
      unawaited(
        _finishError(
          generationId,
          epoch,
          TimeoutException('Model did not start. Try again.'),
        ),
      );
    });

    _subscription =
        _generateWithContext(
          runtimePrompt,
          conversationId: conversationId,
          history: history,
          systemContext: systemContext,
          groundedContext: groundedContext,
          analysis: analysis,
          trace: trace,
          enableSearchDecision: enableSearchDecision,
        ).listen(
          (token) => _token(generationId, epoch, token),
          onError: (Object error, StackTrace stack) {
            unawaited(_finishError(generationId, epoch, error));
          },
          onDone: () {
            unawaited(_finish(generationId, epoch, responseSuffix));
          },
          cancelOnError: true,
        );
    return _job!;
  }

  void _token(String generationId, int epoch, String token) {
    if (token.isEmpty) return;
    final current = _job;
    if (current == null ||
        current.generationId != generationId ||
        current.epoch != epoch ||
        epoch != _epoch ||
        current.cancellationRequested) {
      _lateTokenCount++;
      return;
    }
    if (current.state == ChatGenerationState.preparing) {
      _preparingGuard?.cancel();
      _preparingGuard = null;
    }
    final responseText = (_responseText ??= StringBuffer(current.responseText))
      ..write(token);
    _job = current.copyWith(
      state: ChatGenerationState.generating,
      responseText: responseText.toString(),
      modelName: runtime.lastGeneratingModelName,
    );
    _schedulePersistence();
    if (current.responseText.isEmpty) {
      _notifyTimer?.cancel();
      _notifyTimer = null;
      _activeTrace?.mark(TtftPhase.uiPaintScheduled);
      if (!_disposed) notifyListeners();
    } else {
      _scheduleNotify();
    }
  }

  void markFirstVisiblePaintCompleted() {
    final trace = _activeTrace;
    if (trace == null || trace.hasUiPaintCompleted) return;
    trace.mark(TtftPhase.uiPaintCompleted);
    trace.report();
  }

  void _runtimeChanged() {
    final current = activeJob;
    if (current == null || current.cancellationRequested) return;
    final nextState = runtime.phase == InferencePhase.generating
        ? ChatGenerationState.generating
        : current.state;
    final nextModel = runtime.lastGeneratingModelName;
    if (nextState == current.state && nextModel == current.modelName) return;
    _job = current.copyWith(state: nextState, modelName: nextModel);
    if (!_disposed) notifyListeners();
  }

  List<WebSource> _runtimeSources() => runtime is FinnChatInferenceRuntime
      ? (runtime as FinnChatInferenceRuntime).lastSources
      : const [];

  int _runtimeTokenPaintIntervalMs() => runtime is FinnChatInferenceRuntime
      ? (runtime as FinnChatInferenceRuntime).tokenPaintIntervalMs
      : 50;

  Future<void> _finish(
    String generationId,
    int epoch,
    String responseSuffix,
  ) async {
    _preparingGuard?.cancel();
    _preparingGuard = null;
    final current = _job;
    if (current == null ||
        current.generationId != generationId ||
        current.epoch != epoch ||
        current.cancellationRequested ||
        !current.busy) {
      return;
    }
    final reportedReason =
        runtime.lastGenerationReport?.finishReason ??
        GenerationFinishReason.eos;
    // Some llama.cpp Android builds surface a normal stream termination as
    // StopUserAbort. Only this controller's explicit stop path is allowed to
    // label a message as user-cancelled; it invalidates the epoch and never
    // reaches _finish.
    final reason = reportedReason == GenerationFinishReason.userCancellation
        ? GenerationFinishReason.eos
        : reportedReason;
    final status = switch (reason) {
      GenerationFinishReason.eos => ConversationMessageStatus.complete,
      GenerationFinishReason.tokenLimit =>
        ConversationMessageStatus.tokenLimited,
      GenerationFinishReason.userCancellation =>
        ConversationMessageStatus.stopped,
      GenerationFinishReason.error => ConversationMessageStatus.failed,
    };
    final completedText =
        (reason == GenerationFinishReason.eos ||
                reason == GenerationFinishReason.tokenLimit) &&
            responseSuffix.isNotEmpty
        ? '${current.responseText.trimRight()}$responseSuffix'
        : current.responseText;
    await _finishPersisted(
      current.copyWith(
        state: reason == GenerationFinishReason.error
            ? ChatGenerationState.error
            : ChatGenerationState.complete,
        finishReason: reason,
        responseText: completedText,
        // Continuations carry pre-supplied sources on the job; the runtime's
        // lastSources is only populated for model-driven search turns.
        sources: _runtimeSources().isNotEmpty
            ? _runtimeSources()
            : current.sources,
      ),
      status,
    );
  }

  Future<void> _finishError(
    String generationId,
    int epoch,
    Object error,
  ) async {
    _preparingGuard?.cancel();
    _preparingGuard = null;
    final current = _job;
    if (current == null ||
        current.generationId != generationId ||
        current.epoch != epoch ||
        current.cancellationRequested ||
        !current.busy) {
      return;
    }
    await _finishPersisted(
      current.copyWith(
        state: ChatGenerationState.error,
        finishReason: GenerationFinishReason.error,
        errorMessage: runtime.status,
      ),
      ConversationMessageStatus.failed,
    );
  }

  Future<void> _finishPersisted(
    ChatGenerationJob terminal,
    ConversationMessageStatus status,
  ) async {
    _persistenceTimer?.cancel();
    _persistenceTimer = null;
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _subscription = null;
    conversations.updateMessageInConversation(
      terminal.conversationId,
      terminal.assistantMessageId,
      terminal.responseText,
      expectedGenerationId: terminal.generationId,
      modelTier: terminal.modelName,
      status: status,
      finishReason: terminal.finishReason?.name,
      continuationCount: terminal.continuationCount,
      sources: terminal.sources,
    );
    await conversations.flush();
    _job = terminal;
    if (!_disposed) notifyListeners();
  }

  Future<void> stop() {
    final running = _stopFuture;
    if (running != null) return running;
    final current = activeJob;
    if (current == null) return Future<void>.value();
    final future = _stop(current);
    _stopFuture = future;
    return future.whenComplete(() {
      if (identical(_stopFuture, future)) _stopFuture = null;
    });
  }

  Future<void> _stop(ChatGenerationJob captured) async {
    final watch = Stopwatch()..start();
    final invalidEpoch = ++_epoch;
    _job = captured.copyWith(
      state: ChatGenerationState.stopping,
      cancellationRequested: true,
    );
    if (!_disposed) notifyListeners();

    final subscription = _subscription;
    // Calling the native stop starts cancellation synchronously. Do not cancel
    // the Dart listener at the same time: some stream bridges complete native
    // shutdown by closing that listener, so concurrent close/cancel can
    // deadlock. The epoch above already makes every subsequent token inert.
    final nativeStop = runtime.stopGeneration();
    final persistence = _persistPartial();
    var resetRequired = false;
    Duration? nativeAcknowledgement;
    try {
      await Future.wait([nativeStop, persistence]).timeout(cancellationTimeout);
      nativeAcknowledgement = watch.elapsed;
    } catch (_) {
      resetRequired = true;
      await runtime.resetAfterCancellationTimeout();
      nativeAcknowledgement = watch.elapsed;
    }
    try {
      await (subscription?.cancel() ?? Future<void>.value()).timeout(
        cancellationTimeout,
      );
    } catch (_) {
      if (!resetRequired) {
        resetRequired = true;
        await runtime.resetAfterCancellationTimeout();
      }
    }

    // The invalidated epoch and generation ID remain authoritative even if a
    // fake or native source delivers callbacks after cancellation.
    _epoch = invalidEpoch;
    _subscription = null;
    _persistenceTimer?.cancel();
    _persistenceTimer = null;
    final latest = _job;
    if (latest == null || latest.generationId != captured.generationId) return;
    if (latest.responseText.trim().isEmpty) {
      conversations.removeMessageInConversation(
        latest.conversationId,
        latest.assistantMessageId,
        expectedGenerationId: latest.generationId,
      );
    } else {
      conversations.updateMessageInConversation(
        latest.conversationId,
        latest.assistantMessageId,
        latest.responseText,
        expectedGenerationId: latest.generationId,
        modelTier: latest.modelName,
        status: ConversationMessageStatus.stopped,
        finishReason: GenerationFinishReason.userCancellation.name,
        continuationCount: latest.continuationCount,
        sources: latest.sources,
      );
    }
    await conversations.flush();
    _job = latest.copyWith(
      state: ChatGenerationState.complete,
      finishReason: GenerationFinishReason.userCancellation,
    );
    _lastCancellationMetrics = CancellationMetrics(
      nativeAcknowledgement: nativeAcknowledgement,
      composerUnblocked: watch.elapsed,
      lateTokenCount: _lateTokenCount,
      engineResetRequired: resetRequired,
    );
    debugPrint(
      'FINN_CANCEL native_ack_ms=${nativeAcknowledgement.inMilliseconds} '
      'composer_unblocked_ms=${watch.elapsedMilliseconds} '
      'late_tokens=$_lateTokenCount reset_required=$resetRequired',
    );
    if (!_disposed) notifyListeners();
  }

  Future<void> flushActive() async {
    await _persistPartial();
    await conversations.flush();
  }

  Future<void> _persistPartial({bool persistSoon = false}) async {
    final current = _job;
    if (current == null || current.responseText.isEmpty) return;
    conversations.updateMessageInConversation(
      current.conversationId,
      current.assistantMessageId,
      current.responseText,
      expectedGenerationId: current.generationId,
      modelTier: current.modelName,
      status: current.busy ? ConversationMessageStatus.generating : null,
      continuationCount: current.continuationCount,
      sources: current.sources,
      persistSoon: persistSoon,
      notify: false,
    );
  }

  void _schedulePersistence() {
    _persistenceTimer ??= Timer(persistenceInterval, () {
      _persistenceTimer = null;
      // Checkpoint in memory and let ConversationStore coalesce encryption
      // and disk I/O. Stop, completion, navigation, and disposal still flush
      // immediately, so this removes hot-path writes without risking the
      // terminal response.
      unawaited(_persistPartial(persistSoon: true));
    });
  }

  void _scheduleNotify() {
    _notifyTimer ??= Timer(
      Duration(milliseconds: _runtimeTokenPaintIntervalMs()),
      () {
        _notifyTimer = null;
        if (!_disposed) notifyListeners();
      },
    );
  }

  String _nextId() => '${_clock().microsecondsSinceEpoch}-${_idSequence++}';

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    runtime.removeListener(_runtimeChanged);
    _persistenceTimer?.cancel();
    _notifyTimer?.cancel();
    _preparingGuard?.cancel();
    if (activeJob != null) unawaited(flushActive());
    super.dispose();
  }
}
