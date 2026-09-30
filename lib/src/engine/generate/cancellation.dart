part of '../finn_accelerator.dart';

extension FinnAcceleratorCancellation on FinnAccelerator {
  Future<void> stopGeneration() async {
    _generationEpoch++;
    _markCancelled();
    await _generation?.cancel();
    _generation = null;
    final output = _activeOutput;
    _activeOutput = null;
    if (output != null && !output.isClosed) await output.close();
    if (_phase == InferencePhase.generating ||
        _phase == InferencePhase.loading) {
      _setStatus(
        InferencePhase.idle,
        'Stopped',
        key: FinnStatusKey.stopped,
      );
    }
  }

  Future<void> resetAfterCancellationTimeout() async {
    _generationEpoch++;
    final generation = _generation;
    _generation = null;
    unawaited(generation?.cancel());
    final output = _activeOutput;
    _activeOutput = null;
    if (output != null && !output.isClosed) await output.close();

    _runtimeEpoch++;
    final runtimes = _runtimes.values.toList(growable: false);
    _runtimes.clear();
    _loadJobs.clear();
    for (final runtime in runtimes) {
      await runtime.engine.dispose();
    }
    _replyInFlight = false;
    _setStatus(
      InferencePhase.idle,
      'Ready after runtime reset',
      key: FinnStatusKey.readyAfterRuntimeReset,
    );
  }

  Future<void> _recoverAfterError() async {
    try {
      _generationEpoch++;
      final generation = _generation;
      _generation = null;
      unawaited(generation?.cancel());
      final output = _activeOutput;
      _activeOutput = null;
      if (output != null && !output.isClosed) await output.close();
      await releaseConversationSessions();
    } catch (_) {
      // Recovery is best-effort; the controller already surfaces the original
      // error on the failed message.
    }
  }

  void _markCancelled() {
    final previous = _lastGenerationReport;
    if (previous == null) return;
    _lastGenerationReport = GenerationReport(
      model: previous.model,
      intent: previous.intent,
      route: previous.route,
      outputBudget: previous.outputBudget,
      finishReason: GenerationFinishReason.userCancellation,
      firstTokenLatency: previous.firstTokenLatency,
      totalGenerationTime: previous.totalGenerationTime,
      outputTokens: previous.outputTokens,
      tokensPerSecond: previous.tokensPerSecond,
    );
  }

  void _throwIfGenerationCancelled(int epoch) {
    if (epoch != _generationEpoch) throw const _GenerationCancelled();
  }
}
