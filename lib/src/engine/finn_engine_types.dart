import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:finn_ai/src/engine/backends/llama_shim.dart';

import 'package:finn_ai/src/engine/catalog/model_catalog.dart';

export 'package:finn_ai/src/engine/catalog/model_catalog.dart';

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

/// The newest turn in [history] that carries an attachment, or null.
///
/// A turn is "attached" when it has image bytes (a picker handed them over) or
/// a non-empty [LocalChatTurn.imagePath], which for a document is the file the
/// engine reads. This is the single turn whose attachment is fed back into a
/// prompt: using every attached turn let an older image outrank a file the user
/// had just attached, and the reply answered about the older image instead.
LocalChatTurn? newestAttachmentTurn(List<LocalChatTurn> history) {
  for (final turn in history.reversed) {
    final hasPath = turn.imagePath != null && turn.imagePath!.isNotEmpty;
    if (hasPath || turn.imageBytes != null) return turn;
  }
  return null;
}

/// Lifecycle phases of the FinnEngine inference lifecycle.
enum InferencePhase { idle, downloading, loading, generating, error }

/// Machine-readable key for the accelerator's human-readable [status] text.
///
/// Every [FinnAccelerator] status update carries one stable key alongside
/// the English display string, so the UI layer can map keys to localized
/// strings instead of parsing text. Treat the values as a public contract:
/// never rename or remove an entry (add new ones at the end), and keep the
/// documentation in sync with the exact string the accelerator displays.
///
/// Companion strings (what the accelerator shows today):
/// - ready: 'Ready'
/// - optimizedAutomatically: 'Optimized automatically'
/// - modelReady: 'AI model is ready'
/// - downloadPaused: 'Download paused'
/// - modelRemoved: 'Model removed'
/// - checkingWeb: 'Checking web...'
/// - searchingBrowser: 'Searching browser...'
/// - thinkingOnDevice: 'Thinking on this device'
/// - generatedLocally: 'Generated locally'
/// - stopped: 'Stopped'
/// - readyAfterRuntimeReset: 'Ready after runtime reset'
/// - optimizingForDevice: 'Setting up FinnAI for optimal performance…'
/// - optimizedForDevice: 'FinnAI is optimized for this device'
/// - checkingDownload: 'Checking the download'
/// - downloadingModel: 'Downloading the AI model'
/// - downloadingArtifact: `Downloading <artifact label>`
/// - verifyingArtifact: `Verifying <artifact label>`
/// - loadingModel: 'Loading the AI model'
/// - error: dynamic friendly error text (see _friendlyError)
enum FinnStatusKey {
  /// Engine idle and ready to accept work ('Ready').
  ready,

  /// Automatic tier selection re-engaged ('Optimized automatically').
  optimizedAutomatically,

  /// The required model finished installing and is ready ('AI model is ready').
  modelReady,

  /// A model download was paused by the user ('Download paused').
  downloadPaused,

  /// A model (or its artifacts) was removed from storage ('Model removed').
  modelRemoved,

  /// The model-driven web-search decision pass is running ('Checking web...').
  checkingWeb,

  /// The browser search tool is fetching results ('Searching browser...').
  searchingBrowser,

  /// On-device generation is in progress ('Thinking on this device').
  thinkingOnDevice,

  /// The last generation completed fully on-device ('Generated locally').
  generatedLocally,

  /// Generation was stopped by the user ('Stopped').
  stopped,

  /// The engine is ready again after a runtime reset ('Ready after runtime
  /// reset').
  readyAfterRuntimeReset,

  /// The one-time post-download backend benchmark is running
  /// ('Setting up FinnAI for optimal performance…').
  optimizingForDevice,

  /// The backend benchmark finished and the device choice is cached
  /// ('FinnAI is optimized for this device').
  optimizedForDevice,

  /// A completed download is being validated before promotion
  /// ('Checking the download').
  checkingDownload,

  /// The main language model is downloading ('Downloading the AI model').
  downloadingModel,

  /// A named artifact (e.g. the multimodal component) is downloading
  /// (`Downloading <artifact label>`).
  downloadingArtifact,

  /// A downloaded artifact is being verified (`Verifying <artifact label>`).
  verifyingArtifact,

  /// The model engine is being loaded into memory ('Loading the AI model').
  loadingModel,

  /// A recoverable failure occurred; status carries the friendly error text.
  error,
}

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
    this.taskReady = false,
  });

  final bool cacheHit;
  final int tokens;
  final int fileBytes;
  final Duration preparation;
  final Duration restoration;
  final double promptTokensPerSecond;

  /// Whether the restored state already holds the turn's task instruction
  /// after the base prefix, so the prompt must not write it again.
  final bool taskReady;
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
