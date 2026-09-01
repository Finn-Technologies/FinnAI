// ignore_for_file: dangling_library_doc_comments
library;

//sole caller allowed to import llama_cpp_dart in lib/src/engine.
// See analysis_options.yaml — all other engine files must stay llama-free.
//
/// Adapter wrapping `package:llama_cpp_dart`'s [LlamaEngine] / [EngineSession]
/// behind the engine-owned [FinnEngine] seam.
///
/// This is the ONLY file in `lib/src/engine` that may
/// `import 'package:llama_cpp_dart/llama_cpp_dart.dart'`. Every other file
/// depends on `lib/src/engine/api/engine_api.dart` instead. The rule is
/// enforced by `analysis_options.yaml` (import ban with `backends/` allowlist)
/// and documented in `docs/ENGINE_API.md`.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:llama_cpp_dart/llama_cpp_dart.dart' as llama;

import '../api/engine_api.dart';
import '../catalog/model_catalog.dart';
import '../finn_engine_config.dart' as cfg;
import '../finn_engine_types.dart' as types;
import '../profiler/device_profile.dart';

// ---------------------------------------------------------------------------
// Helpers — translate engine-owned types to/from llama_cpp_dart.
// ---------------------------------------------------------------------------

llama.SamplerParams _toLlamaSampler(EngineSamplerConfig c) => llama.SamplerParams(
      seed: c.seed ?? llama.defaultSeed,
      temperature: c.temperature,
      topK: c.topK,
      topP: c.topP,
      minP: c.minP,
      repeatPenalty: c.repeatPenalty,
      penaltyLastN: c.penaltyLastN,
      greedy: c.greedy,
    );

llama.ContextShiftPolicy _toShiftPolicy(EngineContextShiftPolicy p) =>
    switch (p) {
      EngineContextShiftPolicy.off => llama.ContextShiftPolicy.off,
      EngineContextShiftPolicy.auto => llama.ContextShiftPolicy.auto,
    };

FinnGenerationEvent _fromLlamaEvent(llama.GenerationEvent e) {
  if (e is llama.TokenEvent) {
    return EngineTokenEvent(
      id: e.id,
      bytes: e.bytes,
      text: e.text,
      position: e.position,
    );
  }
  if (e is llama.ShiftEvent) {
    return EngineShiftEvent(
      nKeep: e.nKeep,
      nDiscard: e.nDiscard,
      newPosition: e.newPosition,
    );
  }
  if (e is llama.DoneEvent) {
    return EngineDoneEvent(
      reason: _fromStopReason(e.reason),
      generatedCount: e.generatedCount,
      committedPosition: e.committedPosition,
      trailingText: e.trailingText,
    );
  }
  throw StateError('unknown llama GenerationEvent: $e');
}

types.GenerationFinishReason _fromStopReason(llama.StopReason r) =>
    switch (r) {
      llama.StopEog() => types.GenerationFinishReason.eos,
      llama.StopMaxTokens() => types.GenerationFinishReason.tokenLimit,
      llama.StopUserAbort() => types.GenerationFinishReason.userCancellation,
    };

llama.LlamaMedia _toLlamaMedia(EngineMedia m) => llama.LlamaMedia(
      bytes: m.bytes,
      kind: switch (m.kind) {
        EngineMediaKind.image => llama.MediaKind.image,
        EngineMediaKind.audio => llama.MediaKind.audio,
      },
      id: m.id,
    );

EngineDevice _fromBackendDevice(llama.BackendDevice d) => EngineDevice(
      name: d.name,
      description: d.description,
      registryName: d.registryName,
      isCpu: d.type == llama.BackendDeviceType.cpu,
    );

llama.KvCacheType _kvType(cfg.FinnKvCacheType t) => switch (t) {
      cfg.FinnKvCacheType.turboQuant2Bit => llama.KvCacheType.iq4_nl,
      cfg.FinnKvCacheType.compactQ8 => llama.KvCacheType.q8_0,
      cfg.FinnKvCacheType.compactQ4 => llama.KvCacheType.q4_0,
      cfg.FinnKvCacheType.fp16 => llama.KvCacheType.f16,
    };

// ---------------------------------------------------------------------------
// Session adapter.
// ---------------------------------------------------------------------------

class _LlamaSessionAdapter implements FinnEngineSession {
  _LlamaSessionAdapter(this._inner);

  final llama.EngineSession _inner;

  @override
  int get sessionId => _inner.sessionId;

  @override
  int get seqId => _inner.seqId;

  @override
  Future<void> append(String text, {bool addSpecial = false, bool parseSpecial = true}) =>
      _inner.append(text, addSpecial: addSpecial, parseSpecial: parseSpecial);

  @override
  Future<void> clear() => _inner.clear();

  @override
  Future<EnginePrefillResult> prefill() async {
    final r = await _inner.prefill();
    return EnginePrefillResult(
      evaluatedTokens: r.evaluatedTokens,
      tokenCount: r.tokenCount,
      kvHead: r.kvHead,
      elapsed: r.elapsed,
    );
  }

  @override
  GenerationStream generate(PromptSpec spec, {MediaList media = const []}) {
    return _inner
        .generate(
          prompt: spec.prompt,
          addSpecial: spec.addSpecial,
          parseSpecial: spec.parseSpecial,
          sampler: _toLlamaSampler(spec.sampler),
          maxTokens: spec.maxTokens,
          media: [for (final m in media) _toLlamaMedia(m)],
          shiftPolicy: _toShiftPolicy(spec.shiftPolicy),
          shift: llama.ContextShift(nKeep: spec.nKeep),
        )
        .map(_fromLlamaEvent);
  }

  @override
  Future<void> saveState(String path, {Map<String, Object?> extra = const {}}) =>
      _inner.saveState(path, extra: extra);

  @override
  Future<Map<String, Object?>> loadState(String path) => _inner.loadState(path);

  @override
  Future<void> dispose() => _inner.dispose();
}

// ---------------------------------------------------------------------------
// Engine adapter — the only place that spawns a LlamaEngine.
// ---------------------------------------------------------------------------

/// Adapter wrapping [llama.LlamaEngine] behind [FinnEngine].
///
/// Spawn logic (ModelParams / ContextParams / MultimodalParams construction)
/// lives here so the rest of the engine layer never imports `llama_cpp_dart`.
class LlamaBackend implements FinnEngine {
  LlamaBackend();

  llama.LlamaEngine? _engine;
  bool _disposed = false;

  // Set on load for capabilities that need memorizing.
  String _libraryPath = 'libllama.so';
  String? _backendDir;

  llama.LlamaEngine get _requireEngine {
    final e = _engine;
    if (e == null || _disposed) throw StateError('LlamaBackend not loaded');
    return e;
  }

  @override
  bool get isDisposed => _disposed;

  @override
  bool get multimodalLoaded => _engine?.multimodalLoaded ?? false;

  @override
  bool get canShift => _engine?.canShift ?? false;

  @override
  String get systemInfo => _engine?.systemInfo ?? '';

  @override
  String get packageVersion => _engine?.packageVersion ?? '';

  @override
  String get llamaCppCommit => _engine?.llamaCppCommit ?? '';

  @override
  List<EngineDevice> get devices =>
      (_engine?.devices ?? const <llama.BackendDevice>[]).map(_fromBackendDevice).toList(growable: false);

  @override
  EngineCapabilities get capabilities => EngineCapabilities(
        supportsVision: _engine?.supportsVision ?? false,
        supportsAudio: _engine?.supportsAudio ?? false,
        canShift: canShift,
        devices: devices,
        systemInfo: systemInfo,
        packageVersion: packageVersion,
        llamaCppCommit: llamaCppCommit,
        primaryAcceleratorName: _engine?.primaryAcceleratorName,
      );

  /// Spawns the worker isolate that owns the native model and context.
  ///
  /// Threads / batch / KV / FlashAttention / defrag policy mirror the
  /// previous logic in `FinnAccelerator._spawnBenchmarkEngine` /
  /// `_loadModel.spawnWith` — now centralized here so the rest of the engine
  /// never touches `llama_cpp_dart` params.
  @override
  Future<void> load(ModelSpec spec) async {
    if (_disposed) throw StateError('LlamaBackend already disposed');
    if (_engine != null) {
      // Already loaded — idempotent when the path matches; otherwise swap.
      return;
    }

    final cfg.FinnEngineConfig c = spec.config;

    // Low-end detection for defrag + FlashAttention policy — matches the
    // previous DeviceProfiler.isLowEnd gating that lived in FinnAccelerator.
    // When the caller passes a DeviceProfile-aware config, FlashAttention is
    // already gated; otherwise we degrade gracefully (compact path wins).
    final isLowEndGuess = c.contextSize <= 2048 && c.threads <= 2;
    final compactKv = c.kvCacheType != cfg.FinnKvCacheType.fp16;
    final effectiveFlash = switch (c.flashAttention) {
      true when isLowEndGuess => llama.FlashAttention.off,
      true => llama.FlashAttention.on,
      false => llama.FlashAttention.off,
    };

    // Resolve backend dir from the current DeviceProfile when available.
    String? nativeLibDir = _backendDir;
    try {
      final profile = await DeviceProfiler.read();
      nativeLibDir = profile.nativeLibraryDir;
      _backendDir = nativeLibDir;
    } catch (_) {
      // Non-Android or channel absent: keep previous.
    }

    final hasMmproj = spec.mmprojPath != null && spec.mmprojPath!.isNotEmpty
        ? await File(spec.mmprojPath!).exists().then((e) async =>
            e && await File(spec.mmprojPath!).length() == qwenMmproj.expectedBytes)
        : false;

    final llama.MultimodalParams? mmp = hasMmproj
        ? llama.MultimodalParams(
            mmprojPath: spec.mmprojPath!,
            useGpu: false,
            nThreads: c.batchThreads > 0 ? c.batchThreads : 8,
            imageMinTokens: 64,
            imageMaxTokens: 256,
          )
        : null;

    _engine = await llama.LlamaEngine.spawn(
      libraryPath: _libraryPath,
      backendDirectory: nativeLibDir,
      multimodalParams: mmp,
      modelParams: llama.ModelParams(
        path: spec.path,
        gpuLayers: c.gpuLayers,
        useMmap: true,
        useMlock: false,
        checkTensors: false,
        devices: c.isCpu ? const ['CPU'] : [c.deviceName],
      ),
      contextParams: llama.ContextParams(
        nCtx: c.contextSize,
        nBatch: c.batchSize,
        nUbatch: c.microBatchSize,
        nThreads: c.threads,
        nThreadsBatch: c.batchThreads,
        nSeqMax: c.isCpu ? 1 : 1,
        flashAttn: effectiveFlash,
        typeK: compactKv ? _kvType(c.kvCacheType) : llama.KvCacheType.f16,
        typeV: compactKv ? _kvType(c.kvCacheType) : llama.KvCacheType.f16,
        defragThreshold: isLowEndGuess ? 0.1 : -1.0,
        swaFull: false,
        noPerf: false,
        nRsSeq: 0,
      ),
    );
  }

  /// Low-level spawn used by benchmarks — bypasses [ModelSpec] so callers can
  /// explicitly control raw context fields when sweeping.
  Future<void> loadRaw({
    required String libraryPath,
    required llama.ModelParams modelParams,
    required llama.ContextParams contextParams,
    llama.MultimodalParams? multimodalParams,
    String? backendDirectory,
  }) async {
    if (_disposed) throw StateError('LlamaBackend already disposed');
    if (_engine != null) return;
    _libraryPath = libraryPath;
    _backendDir = backendDirectory;
    _engine = await llama.LlamaEngine.spawn(
      libraryPath: libraryPath,
      backendDirectory: backendDirectory,
      modelParams: modelParams,
      contextParams: contextParams,
      multimodalParams: multimodalParams,
    );
  }

  @override
  Future<GenerationStream> generate(PromptSpec prompt, MediaList media) async {
    final engine = _requireEngine;
    // Allocate a throwaway session for this one-shot generate. Conversation
    // reuse is still managed by FinnAccelerator's session layer; this path
    // exists for non-conversational callers and benchmarks.
    final s = await engine.createSession(seqId: 0);
    final stream = s.generate(
      prompt: prompt.prompt,
      addSpecial: prompt.addSpecial,
      parseSpecial: prompt.parseSpecial,
      sampler: _toLlamaSampler(prompt.sampler),
      maxTokens: prompt.maxTokens,
      media: [for (final m in media) _toLlamaMedia(m)],
      shiftPolicy: _toShiftPolicy(prompt.shiftPolicy),
      shift: llama.ContextShift(nKeep: prompt.nKeep),
    );
    return stream.map(_fromLlamaEvent).asBroadcastStream(
      onCancel: (sub) => s.dispose(),
    );
  }

  @override
  Future<FinnEngineSession> createSession({int seqId = 0, int lookaheadWindow = 0}) async {
    final s = await _requireEngine.createSession(seqId: seqId, lookaheadWindow: lookaheadWindow);
    return _LlamaSessionAdapter(s);
  }

  @override
  Future<void> unload() => dispose();

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final e = _engine;
    _engine = null;
    if (e != null) await e.dispose();
  }

  /// Expose raw engine for code paths that have not yet migrated off it.
  ///
  /// Temporary — will be removed once FinnAccelerator no longer reaches
  /// through. Marked `@visibleForTesting` so new callers cannot depend on it.
  @visibleForTesting
  llama.LlamaEngine? get rawEngineForTesting => _engine;
}
