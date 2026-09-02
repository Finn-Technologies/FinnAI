import 'dart:async';
import 'package:flutter/foundation.dart';
import 'backends/llama_shim.dart';

import 'catalog/model_catalog.dart';

export 'catalog/model_catalog.dart';

/// Single conversational turn passed to the on-device inference engine.
@immutable
class LocalChatTurn {
  const LocalChatTurn({
    required this.role,
    required this.content,
    this.imagePath,
    this.imageBytes,
  });

  final String role;
  final String content;
  final String? imagePath;

  /// Optional in-memory image bytes (e.g. from picker). When present, the
  /// engine uses these directly via [LlamaMedia.imageBytes] and no temp file
  /// is needed. [imagePath] remains the persisted fallback.
  final Uint8List? imageBytes;
}

/// Lifecycle phases of the FinnEngine inference lifecycle.
enum InferencePhase { idle, downloading, loading, generating, error }

/// Reason why a generation turn terminated.
enum GenerationFinishReason { eos, tokenLimit, userCancellation, error }

/// Map internal llama.cpp stop reasons to unified engine finish reasons.
GenerationFinishReason finishReasonFromStopReason(StopReason reason) =>
    switch (reason) {
      StopEog() => GenerationFinishReason.eos,
      StopMaxTokens() => GenerationFinishReason.tokenLimit,
      StopUserAbort() => GenerationFinishReason.userCancellation,
    };

/// Stream helper converting generation events into the final termination reason.
Future<GenerationFinishReason> finishReasonFromEvents(
  Stream<GenerationEvent> events,
) async {
  try {
    await for (final event in events) {
      if (event case DoneEvent(:final reason)) {
        return finishReasonFromStopReason(reason);
      }
    }
  } catch (_) {
    return GenerationFinishReason.error;
  }
  return GenerationFinishReason.error;
}

/// Generation telemetry and performance report.
@immutable
class GenerationReport {
  const GenerationReport({
    required this.model,
    required this.intent,
    required this.route,
    required this.outputBudget,
    required this.finishReason,
    required this.firstTokenLatency,
    required this.totalGenerationTime,
    required this.outputTokens,
    required this.tokensPerSecond,
  });

  final FinnModelSpec model;
  final dynamic intent;
  final FinnModelTier route;
  final int outputBudget;
  final GenerationFinishReason finishReason;
  final Duration? firstTokenLatency;
  final Duration totalGenerationTime;
  final int outputTokens;
  final double tokensPerSecond;
}

/// Telemetry metrics for system prefix state caching.
@immutable
class PrefixStateReport {
  const PrefixStateReport({
    required this.cacheHit,
    required this.tokens,
    required this.fileBytes,
    this.preparation = Duration.zero,
    this.restoration = Duration.zero,
    this.promptTokensPerSecond = 0,
  });

  final bool cacheHit;
  final int tokens;
  final int fileBytes;
  final Duration preparation;
  final Duration restoration;
  final double promptTokensPerSecond;
}

/// Physical on-disk model installation & download recovery state.
@immutable
class ModelStorageState {
  const ModelStorageState({
    required this.model,
    required this.installedBytes,
    required this.partialBytes,
  });

  final FinnModelSpec model;
  final int installedBytes;
  final int partialBytes;

  bool get installed => installedBytes > 0;
  bool get resumable => !installed && partialBytes > 0;
  int get usedBytes => installedBytes + partialBytes;
}
