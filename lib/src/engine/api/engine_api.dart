// FinnAI Engine seam — owned by lib/src/engine, no third-party imports.
//
// This file defines the engine abstraction that the rest of the app depends
// on. The llama.cpp backend is one implementation among N; only
// lib/src/engine/backends/* may import `package:llama_cpp_dart`.
// See docs/ENGINE_API.md for the contract and docs/ENGINE_ROADMAP.md
// for the 12-month runway.
//
// Mirrors the current accelerator surface but is owned by the engine layer:
// ModelSpec, PromptSpec, MediaList, GenerationEvent are engine-owned types
// rather than re-exported FFI types.

import 'dart:async';
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

// ignore: unused_import
import '../catalog/model_catalog.dart';
import '../finn_engine_config.dart';
import '../finn_engine_types.dart';

// ---------------------------------------------------------------------------
// Engine media — replaces `LlamaMedia` in engine-owned code.
// ---------------------------------------------------------------------------

/// Kind of media carried by an [EngineMedia].
enum EngineMediaKind { image, audio }

/// One image or audio attachment owned by the engine layer.
///
/// Holds only bytes + primitives so it is Sendable across isolates. The
/// backend hands the bytes to the native mtmd helper for decoding.
@immutable
class EngineMedia {
  const EngineMedia({
    required this.bytes,
    required this.kind,
    this.id,
  });

  final Uint8List bytes;
  final EngineMediaKind kind;
  final String? id;

  factory EngineMedia.imageBytes(Uint8List bytes, {String? id}) =>
      EngineMedia(bytes: bytes, kind: EngineMediaKind.image, id: id);

  factory EngineMedia.audioBytes(Uint8List bytes, {String? id}) =>
      EngineMedia(bytes: bytes, kind: EngineMediaKind.audio, id: id);

  @override
  String toString() =>
      'EngineMedia(${kind.name}, ${bytes.length} bytes${id == null ? '' : ', id=$id'})';
}

/// Ordered list of media attachments for one generation turn.
typedef MediaList = List<EngineMedia>;

// ---------------------------------------------------------------------------
// Model / prompt specs — replace the ad-hoc argument lists in
// FinnAccelerator.generate*.
// ---------------------------------------------------------------------------

/// Describes the on-disk model and its optional projector.
///
/// Owned by the engine so callers never construct `ModelParams` /
/// `MultimodalParams` directly.
@immutable
class ModelSpec {
  const ModelSpec({
    required this.path,
    required this.config,
    this.mmprojPath,
    this.modelLabel = '',
    this.sha256Digest = '',
  });

  /// Absolute path to the GGUF file.
  final String path;

  /// Optional projector (mmproj) path; null when vision is not installed.
  final String? mmprojPath;

  /// Runtime knobs (threads, batch, KV, FlashAttention, etc.).
  final FinnEngineConfig config;

  /// Human label for diagnostics (e.g. "LFM2.5-VL 1.6B").
  final String modelLabel;

  /// Expected SHA-256 hex digest when known, else ''.
  final String sha256Digest;
}

/// Sampler knobs for one generation turn.
///
/// Intentionally mirrors the llama sampler fields the app actually tunes so
/// policy can stay in the engine layer. Backends translate to their native
/// sampler type.
@immutable
class EngineSamplerConfig {
  const EngineSamplerConfig({
    this.seed,
    this.temperature = 0.8,
    this.topK = 40,
    this.topP = 0.95,
    this.minP = 0.05,
    this.repeatPenalty = 1.1,
    this.penaltyLastN = 64,
    this.greedy = false,
  });

  final int? seed;
  final double temperature;
  final int topK;
  final double topP;
  final double minP;
  final double repeatPenalty;
  final int penaltyLastN;
  final bool greedy;
}

/// Context-shift policy for the KV window.
enum EngineContextShiftPolicy { off, auto }

/// Prompt spec for one generation turn.
@immutable
class PromptSpec {
  const PromptSpec({
    required this.prompt,
    this.maxTokens = 512,
    this.sampler = const EngineSamplerConfig(),
    this.addSpecial = false,
    this.parseSpecial = true,
    this.shiftPolicy = EngineContextShiftPolicy.off,
    this.nKeep = 0,
  });

  final String prompt;
  final int maxTokens;
  final EngineSamplerConfig sampler;
  final bool addSpecial;
  final bool parseSpecial;
  final EngineContextShiftPolicy shiftPolicy;
  final int nKeep;
}

// ---------------------------------------------------------------------------
// Generation stream — engine-owned, backend-agnostic.
// ---------------------------------------------------------------------------

/// One event in a generation stream.
///
/// Mirrors `package:llama_cpp_dart`'s `GenerationEvent` but is owned by the
/// engine layer so callers never import the FFI package outside `backends/`.
sealed class FinnGenerationEvent {
  const FinnGenerationEvent();
}

final class EngineTokenEvent extends FinnGenerationEvent {
  const EngineTokenEvent({
    required this.id,
    required this.bytes,
    required this.text,
    required this.position,
  });

  final int id;
  final Uint8List bytes;
  final String text;
  final int position;

  @override
  String toString() => 'EngineTokenEvent(id=$id, pos=$position, text="$text")';
}

final class EngineShiftEvent extends FinnGenerationEvent {
  const EngineShiftEvent({
    required this.nKeep,
    required this.nDiscard,
    required this.newPosition,
  });

  final int nKeep;
  final int nDiscard;
  final int newPosition;
}

final class EngineDoneEvent extends FinnGenerationEvent {
  const EngineDoneEvent({
    required this.reason,
    required this.generatedCount,
    required this.committedPosition,
    this.trailingText = '',
  });

  final GenerationFinishReason reason;
  final int generatedCount;
  final int committedPosition;
  final String trailingText;
}

/// Stream of generation events for one turn.
typedef GenerationEvent = FinnGenerationEvent;
typedef GenerationStream = Stream<FinnGenerationEvent>;

/// Lightweight device descriptor exposed by [EngineCapabilities].
@immutable
class EngineDevice {
  const EngineDevice({
    required this.name,
    required this.description,
    required this.registryName,
    required this.isCpu,
  });

  final String name;
  final String description;
  final String registryName;
  final bool isCpu;
}

/// Snapshot of what the loaded engine can do.
@immutable
class EngineCapabilities {
  const EngineCapabilities({
    required this.supportsVision,
    required this.supportsAudio,
    required this.canShift,
    required this.devices,
    required this.systemInfo,
    required this.packageVersion,
    required this.llamaCppCommit,
    this.primaryAcceleratorName,
  });

  final bool supportsVision;
  final bool supportsAudio;
  final bool canShift;
  final List<EngineDevice> devices;
  final String systemInfo;
  final String packageVersion;
  final String llamaCppCommit;
  final String? primaryAcceleratorName;
}

// ---------------------------------------------------------------------------
// Low-level session handle — engine-owned, analogous to `EngineSession`.
// ---------------------------------------------------------------------------

/// Prefill measurements for a session, analogous to `SessionPrefillResult`.
@immutable
class EnginePrefillResult {
  const EnginePrefillResult({
    required this.evaluatedTokens,
    required this.tokenCount,
    required this.kvHead,
    required this.elapsed,
  });

  final int evaluatedTokens;
  final int tokenCount;
  final int kvHead;
  final Duration elapsed;

  double get tokensPerSecond => elapsed.inMicroseconds == 0
      ? 0
      : evaluatedTokens * Duration.microsecondsPerSecond / elapsed.inMicroseconds;
}

/// Session owned by a [FinnEngine] instance.
abstract class FinnEngineSession {
  int get sessionId;
  int get seqId;

  Future<void> append(String text, {bool addSpecial = false, bool parseSpecial = true});
  Future<void> clear();
  Future<EnginePrefillResult> prefill();
  GenerationStream generate(PromptSpec spec, {MediaList media = const []});
  Future<void> saveState(String path, {Map<String, Object?> extra = const {}});
  Future<Map<String, Object?>> loadState(String path);
  Future<void> dispose();
}

// ---------------------------------------------------------------------------
// FinnEngine — the engine seam.
// ---------------------------------------------------------------------------

/// Engine seam required by Phase 1 of the 12-month runway.
///
/// The rest of the app depends on this abstraction; only
/// `lib/src/engine/backends/llama_backend.dart` may import
/// `package:llama_cpp_dart` and translate to/from it.
///
/// High-level model lifecycle (`load`/`unload`/`capabilities`) mirrors the
/// current `FinnAccelerator` contract but is now owned by the engine layer.
/// Low-level session management (`createSession`) is also exposed so the
/// accelerator can keep its existing conversation/KV logic without reaching
/// through to `LlamaEngine` directly.
abstract class FinnEngine {
  /// Load (spawn) the native engine for [spec]. Idempotent per [ModelSpec.path].
  Future<void> load(ModelSpec spec);

  /// Generate a turn from [prompt] with optional [media]. Queues behind any
  /// in-flight load; callers should `await load` first when they need the
  /// model resident before the first token.
  Future<GenerationStream> generate(PromptSpec prompt, MediaList media);

  /// Unload the native engine and release its isolate.
  Future<void> unload();

  /// Snapshot of what the engine can do (vision, shift, devices, etc.).
  EngineCapabilities get capabilities;

  // --- Low-level surface used by FinnAccelerator internally ---

  /// Whether the underlying isolate has been disposed.
  bool get isDisposed;

  /// Create a conversation session bound to this engine.
  Future<FinnEngineSession> createSession({int seqId = 0, int lookaheadWindow = 0});

  /// Dispose the engine and its isolate. Alias for [unload] when the engine
  /// was created via [load].
  Future<void> dispose();

  /// Whether vision projector was loaded.
  bool get multimodalLoaded;

  /// Whether context-shift is supported.
  bool get canShift;

  /// Raw device list for diagnostics.
  List<EngineDevice> get devices;

  /// Backend-reported system info / version strings.
  String get systemInfo;
  String get packageVersion;
  String get llamaCppCommit;
}
