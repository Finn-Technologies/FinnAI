import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/search/search_agent.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/inference/prompt_intent.dart';
import 'package:finn_ai/src/inference/ttft_metrics.dart';
import 'package:finn_ai/src/features/search/web_search_service.dart';

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
    this.toolActivities = const [],
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

  /// The browser steps this turn took, in order.
  final List<ToolActivity> toolActivities;
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
    List<ToolActivity>? toolActivities,
  }) =>
      ChatGenerationJob(
        generationId: generationId,
        conversationId: conversationId,
        assistantMessageId: assistantMessageId,
        originalPrompt: originalPrompt,
        modelName: modelName ?? this.modelName,
        state: state ?? this.state,
        responseText: responseText ?? this.responseText,
        finishReason: finishReason ?? this.finishReason,
        startedAt: startedAt,
        cancellationRequested:
            cancellationRequested ?? this.cancellationRequested,
        continuationCount: continuationCount,
        epoch: epoch,
        sources: sources ?? this.sources,
        toolActivities: toolActivities ?? this.toolActivities,
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
  }) =>
      generateReplyWithContext(
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
    List<WebSource> sources = const [],
    PromptAnalysis? promptAnalysis,
    TtftTrace? trace,
  }) =>
      inference.generateReplyQueued(
        prompt,
        conversationId: conversationId,
        history: history,
        systemContext: systemContext,
        groundedContext: groundedContext,
        sources: sources,
        promptAnalysis: promptAnalysis,
        trace: trace,
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

  /// True from the moment a turn's answer has been committed to the store
  /// until that commit has reached disk.
  ///
  /// [busy] stays true for that window so "the controller is not busy" keeps
  /// meaning "the previous answer is durable", but [activeJob] is already null
  /// and [_job] already terminal, so nothing can write over the finished turn
  /// while the encrypted flush is in flight.
  bool _commitPending = false;
  bool get busy => _commitPending || activeJob != null;

  /// Browser steps recorded for the running turn, oldest first.
  ///
  /// Both search paths feed this: the shell records the policy-driven search it
  /// runs before generation, and the engine reports each tool call the model
  /// makes mid-turn. The reply then renders it, live while streaming and
  /// collapsed once finished, instead of the shell floating a global banner.
  List<ToolActivity> _toolActivities = const [];
  List<ToolActivity> get toolActivities => _toolActivities;

  /// Records one browser step for the running turn.
  void noteToolActivity(ToolActivity activity) {
    _toolActivities = [..._toolActivities, activity];
    final current = activeJob;
    if (current != null) {
      _job = current.copyWith(toolActivities: _toolActivities);
    }
    _notify();
  }

  /// Drops the live step list. The steps survive on the persisted message, so
  /// this only clears the streaming signal once a turn has ended.
  void _clearToolActivities() => _toolActivities = const [];

  StreamSubscription<String>? _subscription;
  Timer? _persistenceTimer;
  Timer? _notifyTimer;
  Future<void>? _stopFuture;

  /// Authoritative accumulator for the running answer.
  ///
  /// Tokens are appended here and *only* here. The immutable snapshot that
  /// the UI reads through [ChatGenerationJob.responseText] is materialised
  /// from this buffer by [_materialize], which is called when a listener is
  /// actually notified, when a persistence checkpoint runs, and on every
  /// terminal write. Calling `buffer.toString()` per token made a 500-token
  /// answer copy the whole string 500 times (O(n^2) in allocated characters);
  /// now the copy happens once per paint batch instead.
  StringBuffer? _responseText;

  /// `StringBuffer.length` at the time the current snapshot was materialised,
  /// or -1 when no snapshot exists for this generation. A cheap O(1) guard so
  /// a notify that does not change the text does not re-materialise it.
  int _materializedLength = -1;
  int _materializationCount = 0;
  int _materializedChars = 0;

  /// How many times the growing buffer has been materialised into a snapshot,
  /// and how many characters those snapshots contained in total. Both are the
  /// cost that used to scale with the token count instead of the paint rate.
  @visibleForTesting
  int get responseMaterializationCount => _materializationCount;
  @visibleForTesting
  int get responseMaterializedChars => _materializedChars;

  var _epoch = 0;
  var _idSequence = 0;
  var _lateTokenCount = 0;
  var _disposed = false;

  /// Tokens that arrived after the job lost ownership of the stream (stopped,
  /// superseded, or the controller was disposed). They are counted for the
  /// cancellation metrics and never applied to the answer.
  @visibleForTesting
  int get lateTokenCount => _lateTokenCount;
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
              LocalChatTurn(
                  role: 'user', content: prompt, imagePath: imagePath),
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
    List<WebSource> sources = const [],
    required PromptAnalysis analysis,
    required TtftTrace trace,
  }) {
    final current = runtime;
    if (current is FinnChatInferenceRuntime) {
      return current.generateReplyWithContext(
        prompt,
        conversationId: conversationId,
        history: history,
        systemContext: systemContext,
        groundedContext: groundedContext,
        sources: sources,
        promptAnalysis: analysis,
        trace: trace,
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
  }) {
    final epoch = ++_epoch;
    _lateTokenCount = 0;
    _activeTrace = trace;
    _responseText = StringBuffer(initialText);
    _materializedLength = -1;
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
      // The policy-driven search runs before the turn starts, so the job must
      // adopt whatever has already been recorded or those steps would never
      // reach the finished message.
      toolActivities: _toolActivities,
    );
    _notify();
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

    _subscription = _generateWithContext(
      runtimePrompt,
      conversationId: conversationId,
      history: history,
      systemContext: systemContext,
      groundedContext: groundedContext,
      sources: sources,
      analysis: analysis,
      trace: trace,
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
    // A disposed controller has already detached from the stream and flushed
    // what it had; anything that lands afterwards is a late token to be
    // counted, never applied.
    if (_disposed ||
        current == null ||
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
    (_responseText ??= StringBuffer(current.responseText)).write(token);
    // Deliberately does NOT call `buffer.toString()`. The job keeps the last
    // materialised snapshot; _notify() refreshes it exactly when a listener is
    // about to read it, which is once per paint batch instead of once per
    // token. That is what removed the O(n^2) copy from the token path.
    _job = current.copyWith(
      state: ChatGenerationState.generating,
      modelName: runtime.lastGeneratingModelName,
    );
    _schedulePersistence();
    if (current.responseText.isEmpty) {
      _notifyTimer?.cancel();
      _notifyTimer = null;
      _activeTrace?.mark(TtftPhase.uiPaintScheduled);
      _notify();
    } else {
      _scheduleNotify();
    }
  }

  /// Materialises the token accumulator into the immutable snapshot the UI
  /// reads, publishing it on [_job].
  ///
  /// Returns the snapshot. This is the *only* place the growing buffer is
  /// copied, and it is a no-op when the buffer has not grown since the last
  /// call, so a burst of tokens costs one copy rather than one per token.
  String _materialize() {
    final buffer = _responseText;
    final job = _job;
    if (buffer == null) return job?.responseText ?? '';
    if (_materializedLength == buffer.length) return job?.responseText ?? '';
    final text = buffer.toString();
    _materializedLength = buffer.length;
    _materializationCount++;
    _materializedChars += text.length;
    if (job != null && !identical(job.responseText, text)) {
      _job = job.copyWith(responseText: text);
    }
    return text;
  }

  /// The single notification path. A disposed controller never notifies, and
  /// the response snapshot it publishes is always current with the buffer, so
  /// every `notifyListeners()` the UI observes sees the full text.
  void _notify() {
    if (_disposed) return;
    _materialize();
    notifyListeners();
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
    _notify();
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
    final reportedReason = runtime.lastGenerationReport?.finishReason ??
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
    final completedText = (reason == GenerationFinishReason.eos ||
                reason == GenerationFinishReason.tokenLimit) &&
            responseSuffix.isNotEmpty
        ? '${_materialize().trimRight()}$responseSuffix'
        : _materialize();
    await _finishPersisted(
      current.copyWith(
        state: reason == GenerationFinishReason.error
            ? ChatGenerationState.error
            : ChatGenerationState.complete,
        finishReason: reason,
        responseText: completedText,
        // Continuations carry pre-supplied sources on the job; the runtime's
        // lastSources is only populated for model-driven search turns.
        sources:
            _runtimeSources().isNotEmpty ? _runtimeSources() : current.sources,
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
    _materialize();
    await _finishPersisted(
      current.copyWith(
        state: ChatGenerationState.error,
        finishReason: GenerationFinishReason.error,
        errorMessage: runtime.status,
      ),
      ConversationMessageStatus.failed,
    );
  }

  /// Writes a finished answer to the store as a terminal message. Returns
  /// `false` (and leaves the store alone) when the message is already settled,
  /// so a late partial writer can never undo a completed turn.
  bool _commitTerminal(
      ChatGenerationJob job, ConversationMessageStatus status) {
    if (job.responseText.trim().isEmpty) {
      return conversations.removeMessageInConversation(
        job.conversationId,
        job.assistantMessageId,
        expectedGenerationId: job.generationId,
      );
    }
    return conversations.updateMessageInConversation(
      job.conversationId,
      job.assistantMessageId,
      job.responseText,
      expectedGenerationId: job.generationId,
      modelTier: job.modelName,
      status: status,
      finishReason: job.finishReason?.name,
      continuationCount: job.continuationCount,
      sources: job.sources,
      // An empty list would erase the steps a continuation inherited; leaving
      // it null keeps whatever the message already carries.
      toolActivities: job.toolActivities.isEmpty ? null : job.toolActivities,
    );
  }

  /// True once the assistant message behind [job] has left the `generating`
  /// state, i.e. it already carries a settled answer.
  ///
  /// A missing message counts as settled: [ConversationStore] prunes the
  /// message when a turn produced nothing, and re-creating it would put an
  /// orphan bubble back in the transcript.
  bool _messageSettled(ChatGenerationJob job) {
    final conversation = conversations.conversationById(job.conversationId);
    if (conversation == null) return true;
    for (final message in conversation.messages) {
      if (message.id != job.assistantMessageId) continue;
      return message.status != ConversationMessageStatus.generating;
    }
    return true;
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
    // The store write and the terminal job MUST land in the same synchronous
    // step, before the first await. Publishing `_job` only after the awaited
    // encrypted flush left the controller advertising a live generation for
    // as long as the disk write took: `busy` stayed true (the composer stayed
    // stuck on "Finn is typing…"), and any `flushActive()` / `stop()` / the
    // 1.5 s persistence timer that ran in that window re-read the stale
    // non-terminal job and overwrote the finished answer — downgrading its
    // status back to `generating` and, whenever the last paint batch lagged
    // behind the token buffer, truncating its text. On device that is how a
    // two-token reply ("blue") only showed up once the *next* user turn made
    // the store dirty again.
    _commitTerminal(terminal, status);
    _job = terminal;
    _clearToolActivities();
    _commitPending = true;
    _notify();
    try {
      await conversations.flush();
    } finally {
      _commitPending = false;
    }
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
    _notify();

    final subscription = _subscription;
    // Calling the native stop starts cancellation synchronously. Do not cancel
    // the Dart listener at the same time: some stream bridges complete native
    // shutdown by closing that listener, so concurrent close/cancel can
    // deadlock. The epoch above already makes every subsequent token inert.
    final nativeStop = runtime.stopGeneration();
    _persistPartial();
    var resetRequired = false;
    Duration? nativeAcknowledgement;
    try {
      await nativeStop.timeout(cancellationTimeout);
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
    final capturedLatest = _job;
    if (capturedLatest == null ||
        capturedLatest.generationId != captured.generationId) {
      return;
    }
    _materialize();
    final latest = _job!;
    // A finish that committed while the native stop was in flight is
    // authoritative: the answer is already in the transcript, so do not
    // relabel it as user-cancelled and do not resurrect `generating`.
    final settled = !latest.busy || _messageSettled(latest);
    if (!settled) {
      _commitTerminal(
        latest.copyWith(finishReason: GenerationFinishReason.userCancellation),
        ConversationMessageStatus.stopped,
      );
    }
    // Publish the terminal job before the flush, for the same reason
    // _finishPersisted does: nothing downstream may observe a live job once
    // this turn's answer is in the store.
    _clearToolActivities();
    _job = latest.copyWith(
      state: ChatGenerationState.complete,
      finishReason: GenerationFinishReason.userCancellation,
    );
    _commitPending = true;
    _notify();
    try {
      await conversations.flush();
    } finally {
      _commitPending = false;
    }
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
    _notify();
  }

  Future<void> flushActive() async {
    _persistPartial();
    await conversations.flush();
  }

  /// Checkpoints the in-memory answer without announcing it to the UI.
  ///
  /// Never downgrades a message that has already settled: this is the path the
  /// shell fires unawaited on every lifecycle pause, conversation switch and
  /// disposal, so it used to be able to land after a finish had committed and
  /// replace a completed answer with its own stale snapshot.
  void _persistPartial({bool persistSoon = false}) {
    final current = _job;
    if (current == null || !current.busy) return;
    if (_messageSettled(current)) return;
    // Materialising here keeps the checkpoint complete even when the last UI
    // paint batch lagged behind the token buffer.
    final text = _materialize();
    if (text.isEmpty) return;
    conversations.updateMessageInConversation(
      current.conversationId,
      current.assistantMessageId,
      text,
      expectedGenerationId: current.generationId,
      modelTier: current.modelName,
      status: ConversationMessageStatus.generating,
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
      _persistPartial(persistSoon: true);
    });
  }

  void _scheduleNotify() {
    _notifyTimer ??= Timer(
      Duration(milliseconds: _runtimeTokenPaintIntervalMs()),
      () {
        _notifyTimer = null;
        _notify();
      },
    );
  }

  String _nextId() => '${_clock().microsecondsSinceEpoch}-${_idSequence++}';

  @override
  void dispose() {
    if (_disposed) return;
    final running = activeJob;
    // Invalidate the running turn BEFORE detaching, so anything the runtime
    // still delivers (native decode loop, queued microtask) is counted as a
    // late token and can never be written over the partial flushed below.
    _epoch++;
    _lateTokenCount = 0;
    _disposed = true;
    runtime.removeListener(_runtimeChanged);
    _persistenceTimer?.cancel();
    _persistenceTimer = null;
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _preparingGuard?.cancel();
    _preparingGuard = null;
    final subscription = _subscription;
    _subscription = null;
    if (running != null) {
      // Cancelling the Dart subscription alone left llama.cpp decoding to
      // completion in the background: the engine kept the job's KV session
      // pinned and burned battery on an answer nobody would ever see, and the
      // discarded cancel future meant the native stop might never even be
      // delivered. Tear the generation down explicitly instead.
      _persistPartial();
      unawaited(_shutdownGeneration(subscription));
      unawaited(conversations.flush());
    } else {
      unawaited(subscription?.cancel() ?? Future<void>.value());
    }
    super.dispose();
  }

  /// Stops the native generation this controller started and then detaches
  /// from its token stream.
  ///
  /// The runtime is asked first and awaited, for the same reason [_stop] does:
  /// a runtime may complete native shutdown by closing this very listener, so
  /// the cancel must not race the stop. Every step is best effort — a runtime
  /// that throws on the way down must not turn `dispose()` into an error, and
  /// the epoch bump above already makes whatever is still decoding harmless.
  Future<void> _shutdownGeneration(
      StreamSubscription<String>? subscription) async {
    try {
      await runtime.stopGeneration();
    } catch (error) {
      debugPrint('FINN_DISPOSE stop failed: $error');
    }
    try {
      await subscription?.cancel();
    } catch (error) {
      debugPrint('FINN_DISPOSE cancel failed: $error');
    }
  }
}
