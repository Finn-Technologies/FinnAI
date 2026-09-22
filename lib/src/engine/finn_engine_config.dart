import 'package:flutter/foundation.dart';
import 'package:finn_ai/src/engine/backends/llama_shim.dart';

/// Supported Key-Value (KV) cache quantization formats.
///
/// These are llama.cpp's own KV cache types. TurboQuant — the research method
/// that quantises the KV cache with a Hadamard rotation down to a few bits per
/// value — is **not** one of them, and no part of this app implements it:
/// llama.cpp has no such KV type, so it would take ggml kernels, not a config
/// value. Naming a shipped type after it invites exactly the wrong conclusion.
enum FinnKvCacheType {
  /// llama.cpp `IQ4_NL` — 4-bit non-linear, the densest useful KV type.
  compactIq4,

  /// Fast integer Q8_0 quantization (compact ~32MB at 2048 context).
  compactQ8,

  /// Ultra-compact Q4_0 quantization.
  compactQ4,

  /// Uncompressed 16-bit float KV cache.
  fp16,
}

extension FinnKvCacheTypeExtension on FinnKvCacheType {
  KvCacheType toLlama() => switch (this) {
        FinnKvCacheType.compactIq4 => KvCacheType.iq4_nl,
        FinnKvCacheType.compactQ8 => KvCacheType.q8_0,
        FinnKvCacheType.compactQ4 => KvCacheType.q4_0,
        FinnKvCacheType.fp16 => KvCacheType.f16,
      };
}

/// Unified runtime configuration for FinnEngine instances.
@immutable
class FinnEngineConfig {
  const FinnEngineConfig({
    required this.contextSize,
    required this.threads,
    required this.batchThreads,
    required this.batchSize,
    required this.microBatchSize,
    this.kvCacheType = FinnKvCacheType.compactIq4,
    this.flashAttention = true,
    this.gpuLayers = 0,
    this.deviceName = 'CPU',
    this.isCpu = true,
    this.temperature = 0.7,
    this.topK = 40,
    this.topP = 0.95,
    this.minP = 0.05,
    this.repeatPenalty = 1.1,
  });

  final int contextSize;
  final int threads;
  final int batchThreads;
  final int batchSize;
  final int microBatchSize;
  final FinnKvCacheType kvCacheType;
  final bool flashAttention;
  final int gpuLayers;
  final String deviceName;
  final bool isCpu;
  final double temperature;
  final int topK;
  final double topP;
  final double minP;
  final double repeatPenalty;

  FinnEngineConfig copyWith({
    int? contextSize,
    int? threads,
    int? batchThreads,
    int? batchSize,
    int? microBatchSize,
    FinnKvCacheType? kvCacheType,
    bool? flashAttention,
    int? gpuLayers,
    String? deviceName,
    bool? isCpu,
    double? temperature,
    int? topK,
    double? topP,
    double? minP,
    double? repeatPenalty,
  }) {
    return FinnEngineConfig(
      contextSize: contextSize ?? this.contextSize,
      threads: threads ?? this.threads,
      batchThreads: batchThreads ?? this.batchThreads,
      batchSize: batchSize ?? this.batchSize,
      microBatchSize: microBatchSize ?? this.microBatchSize,
      kvCacheType: kvCacheType ?? this.kvCacheType,
      flashAttention: flashAttention ?? this.flashAttention,
      gpuLayers: gpuLayers ?? this.gpuLayers,
      deviceName: deviceName ?? this.deviceName,
      isCpu: isCpu ?? this.isCpu,
      temperature: temperature ?? this.temperature,
      topK: topK ?? this.topK,
      topP: topP ?? this.topP,
      minP: minP ?? this.minP,
      repeatPenalty: repeatPenalty ?? this.repeatPenalty,
    );
  }
}

typedef FinnAcceleratorConfig = FinnEngineConfig;
