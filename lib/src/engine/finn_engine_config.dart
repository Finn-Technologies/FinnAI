import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

/// Supported Key-Value (KV) cache quantization formats.
enum FinnKvCacheType {
  /// TurboQuant Hadamard-rotated 2-bit/3-bit vector quantization.
  turboQuant2Bit,

  /// Fast integer Q8_0 quantization (compact ~32MB at 2048 context).
  compactQ8,

  /// Ultra-compact Q4_0 quantization.
  compactQ4,

  /// Uncompressed 16-bit float KV cache.
  fp16,
}

extension FinnKvCacheTypeExtension on FinnKvCacheType {
  KvCacheType toLlama() => switch (this) {
    FinnKvCacheType.turboQuant2Bit => KvCacheType.iq4_nl,
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
    this.kvCacheType = FinnKvCacheType.turboQuant2Bit,
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
