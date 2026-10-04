import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/src/engine/profiler/desktop_profile.dart';

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
    this.llamaLibraryPath,
    this.performanceCores,
    this.desktop = false,
  });

  static const minimumRamBytes = 2200000000;

  final int? totalRamBytes;
  final int? availableRamBytes;
  final ProcessorClass processor;
  final String soc;
  final int cores;

  /// Cores in the fastest cluster(s), as reported by the platform, or `null`
  /// when the topology could not be read. `null` is treated as homogeneous:
  /// the plan may then use every core.
  final int? performanceCores;

  final bool lowMemory;
  final List<String> supportedAbis;
  final int? availableStorageBytes;
  final String? nativeLibraryDir;

  /// Absolute path of `libllama.so` when the host cannot resolve it by name.
  ///
  /// On Android the loader finds `libllama.so` through the app's native
  /// library directory and on OpenHarmony through the bundle mount, so both
  /// pass the bare name. A desktop Linux bundle keeps its libraries in
  /// `lib/` next to the executable, and `dlopen` from inside the Dart VM does
  /// not search the executable's RUNPATH, so it needs the full path.
  final String? llamaLibraryPath;

  /// True on desktop Linux, which answers no platform channel: free storage
  /// comes from `df` instead, and nothing like Android's download service
  /// stands between a transfer and a full disk.
  final bool desktop;

  bool get supported =>
      // Android and OpenHarmony both ship an arm64-only build of the engine
      // libs, so both need the RAM + ABI gate. An empty ABI list means the
      // native channel did not answer (desktop Linux answers no channel), and
      // the RAM half of the check is still worth applying.
      !Platform.isAndroid ||
      (totalRamBytes != null &&
          totalRamBytes! >= minimumRamBytes &&
          (supportedAbis.isEmpty || supportedAbis.contains('arm64-v8a')));

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
    this.lookaheadWindow = 4,
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
  final int lookaheadWindow;
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
    this.lookaheadWindow,
  });

  final int? threads;
  final int? batchThreads;
  final int? batchSize;
  final int? microBatchSize;
  final bool? compactKv;
  final bool? flashAttention;
  final int? nRsSeq;
  final int? lookaheadWindow;

  bool get isEmpty =>
      threads == null &&
      batchThreads == null &&
      batchSize == null &&
      microBatchSize == null &&
      compactKv == null &&
      flashAttention == null &&
      nRsSeq == null &&
      lookaheadWindow == null;
}

class DeviceProfiler {
  DeviceProfiler._();

  static PlanOverrides planOverrides = const PlanOverrides();

  /// Treats every device as Lite. For testing the low-end path on a capable
  /// phone or an emulator: `--dart-define=FINN_FORCE_LITE=true`.
  static const bool forceLite = bool.fromEnvironment('FINN_FORCE_LITE');

  /// Whether the image projector is loaded together with the model.
  ///
  /// The projector is 854 MB, more than the 696 MB language model, and it is
  /// only needed for a turn that carries an image. A Lite device (under 4 GB,
  /// or an entry-class chip) therefore loads text-only and brings the
  /// projector in on the first image (ADR 0004); a capable device keeps the
  /// single load so its first image has no extra wait.
  static bool loadsProjectorEagerly(DeviceProfile profile) =>
      !isLowEnd(profile);

  static bool isLowEnd(DeviceProfile profile) =>
      forceLite ||
      profile.lowMemory ||
      (profile.totalRamBytes != null &&
          profile.totalRamBytes! < 4 * 1000 * 1000 * 1000) ||
      profile.processor == ProcessorClass.entry;

  static const _channel = MethodChannel('finn_ai/device_profile');

  static Future<DeviceProfile> read() async {
    Map<Object?, Object?> native = const {};
    // OpenHarmony answers this channel too (DeviceProfilePlugin.ets). It is
    // keyed off `Platform.isLinux` rather than an OHOS-specific check because
    // dart:io reports 'linux' there; desktop Linux answers no channel, and the
    // MissingPluginException below degrades it to the /proc/meminfo path.
    if (Platform.isAndroid || Platform.isLinux) {
      try {
        native = await _channel.invokeMapMethod<Object?, Object?>(
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
    final available = _asInt(native['availableRamBytes']) ??
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
    // Desktop Linux answers no platform channel (OpenHarmony, which also
    // reports Linux, does), so an empty reply is what identifies it here.
    final desktop = Platform.isLinux && native.isEmpty;
    final desktopCpu = desktop ? await DesktopProfile.cpuName() : null;
    final bundledLib = desktop ? DesktopProfile.bundledLlamaLibrary() : null;
    return DeviceProfile(
      totalRamBytes: total,
      availableRamBytes: available,
      // The SoC keyword table describes phone chips and would misread a desktop
      // CPU name, so a desktop is classed by core count and memory alone.
      processor: desktop
          ? DesktopProfile.classify(cores, total)
          : _classifyProcessor(soc, cores),
      soc: soc.isNotEmpty ? soc : (desktopCpu ?? 'Unknown SoC'),
      cores: cores,
      performanceCores: await _performanceCores(cores),
      lowMemory: native['lowMemory'] == true,
      supportedAbis:
          (native['supportedAbis'] as List<Object?>? ?? const <Object?>[])
              .whereType<String>()
              .toList(growable: false),
      availableStorageBytes: _asInt(native['availableStorageBytes']) ??
          (desktop ? await DesktopProfile.freeBytes() : null),
      desktop: desktop,
      nativeLibraryDir:
          native['nativeLibraryDir'] as String? ?? bundledLib?.parent.path,
      llamaLibraryPath: bundledLib?.path,
    );
  }

  static InferencePlan plan(DeviceProfile profile) {
    final processor = profile.processor;

    final constrained = forceLite ||
        profile.lowMemory ||
        (profile.availableRamBytes != null &&
            profile.availableRamBytes! < 1800 * 1024 * 1024) ||
        (profile.totalRamBytes != null &&
            profile.totalRamBytes! <= 3000 * 1000 * 1000);

    // Compact KV cache quantization stores a KV value in a few bits instead of
    // 16. It is a memory optimisation, not a speed one: on CPU every attention
    // step pays to dequantise it. Measured on the SM6225 reference (4x A73
    // 2.4 GHz + 4x A53 1.8 GHz) with Flash Attention on, f16 KV reached the
    // first token 16% sooner (7.0 s vs 8.4 s across a 327-token prompt) and
    // decoded 3% faster than q4_0 KV, for ~11 MB more state at 4096 context.
    // f16 is therefore the default; the compact path stays reachable through
    // [PlanOverrides], and the adaptive KV memo still records devices whose
    // backend rejects it.
    final context = constrained
        ? 2048
        : switch (processor) {
            ProcessorClass.entry => 2048,
            ProcessorClass.balanced => 4096,
            ProcessorClass.flagship => 4096,
          };

    // Both pools are barrier-synchronised, so a worker on a little core does
    // not merely do less work — every other thread waits for it. Decode is
    // bandwidth-bound and was already capped at the fast cluster; prefill is
    // compute-bound and used to scale across every core, which measured much
    // worse on real hardware: the same prompt reached its first token in
    // 11.9 s at 8 batch threads, 13.0 s at 6, and 7.0 s at 4, while 8 decode
    // threads collapsed throughput to 0.25 tok/s. Homogeneous devices, where
    // the platform reports no separate cluster, keep every core.
    final fastCores = switch (profile.performanceCores) {
      final int reported when reported > 0 => math.min(reported, profile.cores),
      _ => profile.cores,
    };
    final decodeCeiling = constrained ? 2 : 4;
    final batchCeiling = constrained ? 4 : math.max(4, fastCores);
    const threadOverride = int.fromEnvironment(
      'FINN_BENCH_THREADS',
      defaultValue: 0,
    );
    final normalThreads = threadOverride > 0
        ? threadOverride
        : math.max(1, math.min(decodeCeiling, fastCores));
    final threads = normalThreads;
    const batchThreadOverride = int.fromEnvironment(
      'FINN_BENCH_BATCH_THREADS',
      defaultValue: 0,
    );
    final normalBatchThreads = math.max(
      threads,
      math.min(batchCeiling, fastCores),
    );
    final batchThreads =
        batchThreadOverride > 0 ? batchThreadOverride : normalBatchThreads;
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
    final microBatchSize =
        microBatchOverride > 0 ? microBatchOverride : normalMicroBatchSize;
    const flashOff = bool.fromEnvironment('FINN_BENCH_FLASH_OFF');
    final overrides = planOverrides;
    final effectiveThreads = overrides.threads ?? threads;
    final effectiveBatchThreads = overrides.batchThreads ?? batchThreads;
    final effectiveBatch = overrides.batchSize ?? batchSize;
    final effectiveMicroBatch = overrides.microBatchSize ?? microBatchSize;
    final effectiveCompactKv = overrides.compactKv ?? false;
    final effectiveFlash = overrides.flashAttention ??
        (!flashOff && processor != ProcessorClass.entry);
    return InferencePlan(
      contextSize: context,
      threads: effectiveThreads,
      batchThreads: effectiveBatchThreads,
      batchSize: effectiveBatch,
      microBatchSize: effectiveMicroBatch,
      compactKv: effectiveCompactKv,
      tokenPaintIntervalMs: switch (processor) {
        ProcessorClass.entry => 32,
        ProcessorClass.balanced => 16,
        ProcessorClass.flagship => 16,
      },
      sessionCacheEntries: 1,
      flashAttention: effectiveFlash,
      lookaheadWindow: overrides.lookaheadWindow ?? 0,
    );
  }

  /// Number of recurrent-state snapshots (n_rs_seq) to allocate so
  /// lookahead decoding can roll back rejected drafts on hybrid/recurrent
  /// models. Each snapshot costs one extra recurrent-state buffer (~39 MiB
  /// for LFM2.5-VL 1.6B Q4_0); the lookahead window is nRsSeq + 1 tokens.
  ///
  /// Disabled by default: on-device measurement (SM7325, LFM2.5-VL 1.6B Q4_0,
  /// full CPU) showed n-gram drafts match the model's argmax ~0.1% of the time,
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
      'kirin 9000',
      'kirin 9000s',
      'kirin 9010',
      'kirin 9000e',
      'kirin 990',
      'kirin 985',
      'kirin 980',
      'hi3690',
      'hi36a0',
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
      'kirin 820',
      'kirin 810',
      'kirin 8000',
      'kirin 9000w',
      'kirin 9000sl',
      'kirin',
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
      'kirin 710',
      'kirin 659',
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

  static int? _cachedPerformanceCores;

  /// Cores in the fastest cluster(s) of a heterogeneous CPU.
  ///
  /// Android publishes each core's peak frequency under sysfs, so cores
  /// clocked above the slowest peak form the performance cluster. A
  /// tri-cluster part (prime + performance + efficiency) reports both of its
  /// fast clusters this way. Returns `null` when every core is clocked the
  /// same or when the topology cannot be read — the plan treats `null` as
  /// homogeneous and leaves the thread counts alone.
  ///
  /// Read once: a CPU's cluster layout cannot change while the app runs.
  static Future<int?> _performanceCores(int cores) async {
    final cached = _cachedPerformanceCores;
    if (cached != null) return cached;
    final peaks = <int>[];
    for (var cpu = 0; cpu < cores; cpu++) {
      final peak = await _peakFrequencyKhz(cpu);
      if (peak == null || peak <= 0) return null;
      peaks.add(peak);
    }
    if (peaks.isEmpty) return null;
    final slowest = peaks.reduce(math.min);
    if (peaks.every((peak) => peak == slowest)) return null;
    final performance = peaks.where((peak) => peak > slowest).length;
    if (performance < 1) return null;
    return _cachedPerformanceCores = performance;
  }

  static Future<int?> _peakFrequencyKhz(int cpu) async {
    try {
      final raw = await File(
        '/sys/devices/system/cpu/cpu$cpu/cpufreq/cpuinfo_max_freq',
      ).readAsString();
      return int.tryParse(raw.trim());
    } catch (_) {
      return null;
    }
  }
}
