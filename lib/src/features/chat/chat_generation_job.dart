import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/search/web_search_service.dart';
import 'package:finn_ai/src/features/search/search_agent.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';

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
