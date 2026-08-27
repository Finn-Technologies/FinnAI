import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum ProcessorClass { entry, balanced, flagship }

@immutable
class DeviceProfile {
  const DeviceProfile({
    required this.totalRamBytes,
    required this.availableRamBytes,
    required this.processor,
    required this.soc,
    required this.cores,
    required this.lowMemory,
    this.supportedAbis = const [],
    this.availableStorageBytes,
    this.nativeLibraryDir,
  });

  static const minimumRamBytes = 2200000000;

  final int? totalRamBytes;
  final int? availableRamBytes;
  final ProcessorClass processor;
  final String soc;
  final int cores;
  final bool lowMemory;
  final List<String> supportedAbis;
  final int? availableStorageBytes;
  final String? nativeLibraryDir;

  bool get supported =>
      !Platform.isAndroid ||
      (totalRamBytes != null &&
          totalRamBytes! >= minimumRamBytes &&
          supportedAbis.contains('arm64-v8a'));

  String get processorLabel => switch (processor) {
    ProcessorClass.entry => 'Efficiency processor',
    ProcessorClass.balanced => 'Balanced processor',
    ProcessorClass.flagship => 'High-performance processor',
  };
}

@immutable
class InferencePlan {
  const InferencePlan({
    required this.contextSize,
    required this.threads,
    required this.batchThreads,
    required this.batchSize,
    required this.microBatchSize,
    required this.compactKv,
    required this.tokenPaintIntervalMs,
    required this.sessionCacheEntries,
    required this.flashAttention,
  });

  final int contextSize;
  final int threads;
  final int batchThreads;
  final int batchSize;
  final int microBatchSize;
  final bool compactKv;
  final int tokenPaintIntervalMs;
  final int sessionCacheEntries;
  final bool flashAttention;
}

/// Benchmark-only overrides applied by the device harness (see
/// `main.dart`), so engine configs can be swept without rebuilding or
/// editing the adaptive backend cache. Null values leave the plan intact.
@immutable
class PlanOverrides {
  const PlanOverrides({
    this.threads,
    this.batchThreads,
    this.batchSize,
    this.microBatchSize,
    this.compactKv,
    this.flashAttention,
    this.nRsSeq,
  });

  final int? threads;
  final int? batchThreads;
  final int? batchSize;
  final int? microBatchSize;
  final bool? compactKv;
  final bool? flashAttention;
  final int? nRsSeq;

  bool get isEmpty =>
      threads == null &&
      batchThreads == null &&
      batchSize == null &&
      microBatchSize == null &&
      compactKv == null &&
      flashAttention == null &&
      nRsSeq == null;
}

class DeviceProfiler {
  DeviceProfiler._();

  static PlanOverrides planOverrides = const PlanOverrides();

  static bool isLowEnd(DeviceProfile profile) =>
      profile.lowMemory ||
      (profile.totalRamBytes != null &&
          profile.totalRamBytes! < 4 * 1000 * 1000 * 1000) ||
      profile.processor == ProcessorClass.entry;

  static const _channel = MethodChannel('finn_ai/device_profile');

  static Future<DeviceProfile> read() async {
    Map<Object?, Object?> native = const {};
    if (Platform.isAndroid) {
      try {
        native =
            await _channel.invokeMapMethod<Object?, Object?>(
              'getDeviceProfile',
            ) ??
            const {};
      } on PlatformException {
        native = const {};
      } on MissingPluginException {
        native = const {};
      }
    }

    final total =
        _asInt(native['totalRamBytes']) ?? await _memoryBytes('MemTotal');
    final available =
        _asInt(native['availableRamBytes']) ??
        await _memoryBytes('MemAvailable');
    final socParts = <Object?>[
      native['socManufacturer'],
      native['socModel'],
      native['hardware'],
      native['board'],
    ];
    final soc = socParts
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    final cores = math.max(
      1,
      _asInt(native['cores']) ?? Platform.numberOfProcessors,
    );
    return DeviceProfile(
      totalRamBytes: total,
      availableRamBytes: available,
      processor: _classifyProcessor(soc, cores),
      soc: soc.isEmpty ? 'Unknown SoC' : soc,
      cores: cores,
      lowMemory: native['lowMemory'] == true,
      supportedAbis:
          (native['supportedAbis'] as List<Object?>? ?? const <Object?>[])
              .whereType<String>()
              .toList(growable: false),
      availableStorageBytes: _asInt(native['availableStorageBytes']),
      nativeLibraryDir: native['nativeLibraryDir'] as String?,
    );
  }

  static InferencePlan plan(DeviceProfile profile) {
    final ram = profile.totalRamBytes ?? 4 * 1000 * 1000 * 1000;
    final ramGb = ram / 1000000000;
    final processor = profile.processor;

    // A single Qwen 3.5 2B model replaces the old tiered catalog. Compact KV
    // keeps longer contexts affordable: entry-class devices stay at 2K/4K so
    // the KV cache never competes with the model for RAM, while balanced and
    // flagship devices with enough headroom run an 8K context so long answers
    // and grounded web excerpts do not overflow the window mid-generation.
    final context = switch (processor) {
      ProcessorClass.entry => ramGb >= 5.5 ? 4096 : 2048,
      ProcessorClass.balanced => ramGb >= 7.0 ? 8192 : 4096,
      ProcessorClass.flagship => ramGb >= 7.0 ? 8192 : 4096,
    };

    // Measured on SM7325 (4x A78 + 4x A55, Qwen 3.5 2B, full CPU): decode
    // is bandwidth-bound and scales to 4 threads (52 ms/token @ 4 threads) —
    // extra decode threads only add contention, so decode stays pinned to
    // the fastest cluster. Batch (prefill) and lookahead batches are
    // compute-bound, so they use all cores: the native AAR affinity patch
    // spills threadpools with more threads than the fast cluster onto the
    // small cores (8 threads on 4xA78 + 4xA55 ≈ 1.35x prefill throughput).
    final constrained =
        profile.lowMemory ||
        (profile.availableRamBytes != null &&
            profile.availableRamBytes! < 1800 * 1024 * 1024) ||
        (profile.totalRamBytes != null &&
            profile.totalRamBytes! <= 3000 * 1000 * 1000);

    final decodeCeiling = constrained ? 2 : 4;
    final batchCeiling = constrained ? 4 : math.max(4, profile.cores);
    const threadOverride = int.fromEnvironment(
      'FINN_BENCH_THREADS',
      defaultValue: 0,
    );
    final normalThreads = threadOverride > 0
        ? threadOverride
        : math.max(1, math.min(decodeCeiling, profile.cores));
    final threads = normalThreads;
    const batchThreadOverride = int.fromEnvironment(
      'FINN_BENCH_BATCH_THREADS',
      defaultValue: 0,
    );
    final normalBatchThreads = math.max(
      threads,
      math.min(batchCeiling, profile.cores),
    );
    final batchThreads = batchThreadOverride > 0
        ? batchThreadOverride
        : normalBatchThreads;
    const batchOverride = int.fromEnvironment(
      'FINN_BENCH_BATCH',
      defaultValue: 0,
    );
    final normalBatchSize = constrained
        ? 128
        : processor == ProcessorClass.entry
        ? 256
        : 512;
    final batchSize = batchOverride > 0 ? batchOverride : normalBatchSize;
    const microBatchOverride = int.fromEnvironment(
      'FINN_BENCH_UBATCH',
      defaultValue: 0,
    );
    final normalMicroBatchSize = constrained
        ? 64
        : processor == ProcessorClass.entry
        ? 128
        : 256;
    final microBatchSize = microBatchOverride > 0
        ? microBatchOverride
        : normalMicroBatchSize;
    const f16Kv = bool.fromEnvironment('FINN_BENCH_F16_KV');
    const flashOff = bool.fromEnvironment('FINN_BENCH_FLASH_OFF');
    final overrides = planOverrides;
    final effectiveThreads = overrides.threads ?? threads;
    final effectiveBatchThreads = overrides.batchThreads ?? batchThreads;
    final effectiveBatch = overrides.batchSize ?? batchSize;
    final effectiveMicroBatch = overrides.microBatchSize ?? microBatchSize;
    final effectiveCompactKv = overrides.compactKv ?? !f16Kv;
    final effectiveFlash =
        overrides.flashAttention ??
        (!flashOff && processor != ProcessorClass.entry);
    return InferencePlan(
      contextSize: context,
      threads: effectiveThreads,
      batchThreads: effectiveBatchThreads,
      batchSize: effectiveBatch,
      microBatchSize: effectiveMicroBatch,
      compactKv: effectiveCompactKv,
      tokenPaintIntervalMs: switch (processor) {
        ProcessorClass.entry => 80,
        ProcessorClass.balanced => 50,
        ProcessorClass.flagship => 34,
      },
      sessionCacheEntries: switch (processor) {
        ProcessorClass.entry => 1,
        ProcessorClass.balanced => 2,
        ProcessorClass.flagship => 3,
      },
      flashAttention: effectiveFlash,
    );
  }

  /// Number of recurrent-state snapshots (n_rs_seq) to allocate so
  /// lookahead decoding can roll back rejected drafts on hybrid/recurrent
  /// models. Each snapshot costs one extra recurrent-state buffer (~39 MiB
  /// for Qwen 3.5 2B); the lookahead window is nRsSeq + 1 tokens.
  ///
  /// Disabled by default: on-device measurement (SM7325, Qwen 3.5 2B, full
  /// CPU) showed n-gram drafts match the model's argmax ~0.1% of the time,
  /// so lookahead paid ~2x decode cost (n_rs_seq=15: ~207 ms/token vs
  /// ~100 ms/token baseline) with effectively zero accepted batches, and the
  /// K-slot recurrent-state buffers added ~580 MiB RSS. `FINN_BENCH_NRS`
  /// (int) or the harness PlanOverrides re-enable it for experiments.
  static int lookaheadSnapshots(DeviceProfile profile) {
    final harness = planOverrides.nRsSeq;
    if (harness != null) return harness; // 0 explicitly disables snapshots
    const define = int.fromEnvironment('FINN_BENCH_NRS', defaultValue: 0);
    if (define > 0) return define;
    return 0;
  }

  static ProcessorClass _classifyProcessor(String raw, int cores) {
    final value = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');

    // Snapdragon 765/765G reports SM7250 on many devices. It is deliberately
    // balanced rather than flagship, so 8 GB selects 4B with a longer context.
    const flagship = <String>[
      'sm8150',
      'sm8250',
      'sm8350',
      'sm8450',
      'sm8475',
      'sm8550',
      'sm8635',
      'sm8650',
      'sm8750',
      'sm8850',
      'sm7675',
      'snapdragon 8',
      'snapdragon 7+ gen 3',
      '7+ gen 3',
      'dimensity 8100',
      'dimensity 8200',
      'dimensity 9000',
      'dimensity 9200',
      'dimensity 9300',
      'dimensity 9400',
      'exynos 2100',
      'exynos 2200',
      'exynos 2400',
      'exynos 2500',
      'tensor g3',
      'tensor g4',
      'tensor g5',
    ];
    const balanced = <String>[
      'sm7150',
      'sm7250',
      'sm7325',
      'sm7350',
      'sm7435',
      'sm7450',
      'sm7550',
      'sm7635',
      'sdm730',
      'sdm765',
      'snapdragon 7',
      'dimensity 700',
      'dimensity 7000',
      'dimensity 7020',
      'dimensity 7025',
      'dimensity 7030',
      'dimensity 7050',
      'dimensity 7200',
      'dimensity 7300',
      'dimensity 800',
      'dimensity 900',
      'dimensity 1000',
      'dimensity 1080',
      'dimensity 1200',
      'dimensity 1300',
      'dimensity 6020',
      'dimensity 6080',
      'dimensity 6100',
      'dimensity 6300',
      'mt6855',
      'mt6877',
      'mt6885',
      'mt6893',
      'mt6895',
      'exynos 980',
      'exynos 1080',
      'exynos 1280',
      'exynos 1380',
      'exynos 1480',
      'tensor',
    ];
    if (flagship.any(value.contains)) return ProcessorClass.flagship;
    if (balanced.any(value.contains)) return ProcessorClass.balanced;

    const entryKeywords = <String>[
      'sm4',
      'sm6',
      'sdm6',
      'helio',
      'mt67',
      'mt6833',
      'unisoc',
      'spreadtrum',
      'sprd',
      'ums',
      'sc9863',
      't606',
      't610',
      't612',
      't616',
      't618',
      't700',
      'tiger',
      'jlq',
      'allwinner',
      'rockchip',
      'g80',
      'g85',
      'g88',
      'g90',
      'g95',
      'g99',
    ];
    if (entryKeywords.any(value.contains)) {
      return ProcessorClass.entry;
    }
    return cores >= 8 ? ProcessorClass.balanced : ProcessorClass.entry;
  }

  static int? _asInt(Object? value) => value is int ? value : null;

  static Future<int?> _memoryBytes(String field) async {
    if (!Platform.isAndroid && !Platform.isLinux) return null;
    try {
      final contents = await File('/proc/meminfo').readAsString();
      final match = RegExp(
        '^$field:\\s+(\\d+)\\s+kB\$',
        multiLine: true,
      ).firstMatch(contents);
      return match == null ? null : int.parse(match.group(1)!) * 1024;
    } catch (_) {
      return null;
    }
  }
}
