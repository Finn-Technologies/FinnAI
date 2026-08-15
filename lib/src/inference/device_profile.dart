import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bonsai_inference.dart';

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

  static const minimumRamBytes = 3000000000;

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
    required this.tier,
    required this.contextSize,
    required this.threads,
    required this.batchThreads,
    required this.batchSize,
    required this.microBatchSize,
    required this.compactKv,
    required this.maxOutputTokens,
    required this.tokenPaintIntervalMs,
    required this.sessionCacheEntries,
    required this.flashAttention,
  });

  final BonsaiTier tier;
  final int contextSize;
  final int threads;
  final int batchThreads;
  final int batchSize;
  final int microBatchSize;
  final bool compactKv;
  final int maxOutputTokens;
  final int tokenPaintIntervalMs;
  final int sessionCacheEntries;
  final bool flashAttention;
}

class DeviceProfiler {
  DeviceProfiler._();

  static bool isLowEnd(DeviceProfile profile) =>
      profile.lowMemory ||
      (profile.totalRamBytes != null && profile.totalRamBytes! < 4 * 1000 * 1000 * 1000) ||
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

    final tier = switch (processor) {
      ProcessorClass.entry => BonsaiTier.lite,
      ProcessorClass.balanced =>
        ramGb >= 5.5 && !_prefersLiteModel(profile.soc)
            ? BonsaiTier.plus
            : BonsaiTier.lite,
      ProcessorClass.flagship =>
        ramGb >= 7.5
            ? BonsaiTier.pro
            : ramGb >= 5
            ? BonsaiTier.plus
            : BonsaiTier.lite,
    };

    final context = switch ((tier, processor, ramGb)) {
      (BonsaiTier.lite, ProcessorClass.entry, >= 5.5) => 4096,
      (BonsaiTier.lite, ProcessorClass.entry, _) => 2048,
      (BonsaiTier.lite, _, >= 4.5) => 4096,
      (BonsaiTier.plus, ProcessorClass.flagship, >= 11.5) => 12288,
      // 4K keeps the KV cache compact on mid-range SoCs. Conversation
      // shifting preserves long chats without paying the 8K memory/bandwidth
      // cost on every generated token.
      (BonsaiTier.plus, ProcessorClass.balanced, _) => 4096,
      (BonsaiTier.plus, _, >= 7.5) => 8192,
      (BonsaiTier.plus, _, _) => 4096,
      (BonsaiTier.pro, _, >= 11.5) => 8192,
      (BonsaiTier.pro, _, _) => 4096,
      _ => 2048,
    };

    final decodeCeiling = switch (processor) {
      ProcessorClass.entry => 3,
      ProcessorClass.balanced => 5,
      ProcessorClass.flagship => 6,
    };
    final batchCeiling = switch (processor) {
      ProcessorClass.entry => 4,
      ProcessorClass.balanced => 8,
      ProcessorClass.flagship => 8,
    };
    const threadOverride = int.fromEnvironment(
      'FINN_BENCH_THREADS',
      defaultValue: 0,
    );
    final normalThreads = threadOverride > 0
        ? threadOverride
        : math.max(1, math.min(decodeCeiling, profile.cores - 2));
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
    final constrained =
        profile.lowMemory ||
        (profile.availableRamBytes != null &&
            profile.availableRamBytes! < 1800 * 1024 * 1024);
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
    return InferencePlan(
      tier: tier,
      contextSize: context,
      threads: threads,
      batchThreads: batchThreads,
      batchSize: batchSize,
      microBatchSize: microBatchSize,
      compactKv: !f16Kv,
      maxOutputTokens: switch (tier) {
        BonsaiTier.lite => 2048,
        BonsaiTier.plus => 4096,
        BonsaiTier.pro => 8092,
      },
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
      flashAttention: !flashOff,
    );
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
      'snapdragon 8',
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
      'dimensity 800',
      'dimensity 900',
      'dimensity 1000',
      'dimensity 1080',
      'dimensity 1200',
      'dimensity 1300',
      'exynos 980',
      'exynos 1080',
      'exynos 1280',
      'exynos 1380',
      'exynos 1480',
      'tensor',
    ];
    if (flagship.any(value.contains)) return ProcessorClass.flagship;
    if (balanced.any(value.contains)) return ProcessorClass.balanced;
    if (value.contains('sm4') ||
        value.contains('sm6') ||
        value.contains('sdm6') ||
        value.contains('helio') ||
        value.contains('mt67')) {
      return ProcessorClass.entry;
    }
    return cores >= 8 ? ProcessorClass.balanced : ProcessorClass.entry;
  }

  static bool _prefersLiteModel(String raw) {
    final value = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    // These older mid-range SoCs have enough RAM for the 4B model but their
    // CPU prefill is too slow for an acceptable default-chat startup. Plus
    // remains available as a manual selection.
    return const ['sm7150', 'sm7250', 'sdm730', 'sdm765'].any(value.contains);
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
