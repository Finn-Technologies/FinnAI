import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/search/web_search_service.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/inference/prompt_intent.dart';
import 'package:finn_ai/src/inference/ttft_metrics.dart';

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
