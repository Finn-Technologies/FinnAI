import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:finn_ai/src/engine/backends/llama_shim.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/engine/profiler/device_profile.dart';

/// Runtime knobs selected for one device.
///
/// The CPU baseline is always available and is the guaranteed fallback. When
/// a compatible accelerator backend is packaged and discovered, the config is
/// upgraded in place to offload model layers onto it.
@immutable
class RuntimeConfig {
  const RuntimeConfig({
    required this.contextSize,
    required this.threads,
    required this.batchThreads,
    required this.batchSize,
    required this.microBatchSize,
    required this.sessionCount,
    required this.kvType,
    required this.flashAttention,
    required this.gpuLayers,
    required this.deviceName,
    required this.isCpu,
  });

  final int contextSize;
  final int threads;
  final int batchThreads;
  final int batchSize;
  final int microBatchSize;
  final int sessionCount;
  final KvCacheType kvType;
  final FlashAttention flashAttention;
  final int gpuLayers;
  final String deviceName;
  final bool isCpu;

  RuntimeConfig copyWith({
    int? contextSize,
    int? threads,
    int? batchThreads,
    int? batchSize,
    int? microBatchSize,
    int? sessionCount,
    KvCacheType? kvType,
    FlashAttention? flashAttention,
    int? gpuLayers,
    String? deviceName,
    bool? isCpu,
  }) =>
      RuntimeConfig(
        contextSize: contextSize ?? this.contextSize,
        threads: threads ?? this.threads,
        batchThreads: batchThreads ?? this.batchThreads,
        batchSize: batchSize ?? this.batchSize,
        microBatchSize: microBatchSize ?? this.microBatchSize,
        sessionCount: sessionCount ?? this.sessionCount,
        kvType: kvType ?? this.kvType,
        flashAttention: flashAttention ?? this.flashAttention,
        gpuLayers: gpuLayers ?? this.gpuLayers,
        deviceName: deviceName ?? this.deviceName,
        isCpu: isCpu ?? this.isCpu,
      );

  Map<String, Object?> toJson() => {
        'contextSize': contextSize,
        'threads': threads,
        'batchThreads': batchThreads,
        'batchSize': batchSize,
        'microBatchSize': microBatchSize,
        'sessionCount': sessionCount,
        'kvType': kvType.name,
        'flashAttention': flashAttention.name,
        'gpuLayers': gpuLayers,
        'deviceName': deviceName,
        'isCpu': isCpu,
      };

  factory RuntimeConfig.fromJson(Map<String, Object?> json) => RuntimeConfig(
        contextSize: json['contextSize'] as int,
        threads: json['threads'] as int,
        batchThreads: json['batchThreads'] as int,
        batchSize: json['batchSize'] as int,
        microBatchSize: json['microBatchSize'] as int,
        sessionCount: json['sessionCount'] as int,
        kvType: KvCacheType.values.firstWhere(
          (e) => e.name == json['kvType'],
          orElse: () => KvCacheType.iq4_nl,
        ),
        flashAttention: FlashAttention.values.firstWhere(
          (e) => e.name == json['flashAttention'],
          orElse: () => FlashAttention.on,
        ),
        gpuLayers: json['gpuLayers'] as int,
        deviceName: json['deviceName'] as String? ?? '',
        isCpu: json['isCpu'] as bool? ?? true,
      );
}

/// Broad class of the selected compute backend.
enum ComputeBackend { cpu, gpu, npu }

/// A chosen accelerator together with the concrete config that offloads onto
/// it. CPU fallback is represented by a null [BackendSelection].
@immutable
class BackendSelection {
  const BackendSelection({
    required this.config,
    required this.backend,
    required this.deviceName,
    required this.registryName,
    required this.reason,
  });

  final RuntimeConfig config;
  final ComputeBackend backend;
  final String deviceName;
  final String registryName;
  final String reason;

  BackendSelection copyWithConfig(RuntimeConfig next) => BackendSelection(
        config: next,
        backend: backend,
        deviceName: deviceName,
        registryName: registryName,
        reason: reason,
      );
}

RuntimeConfig runtimeConfigFromPlan(
  InferencePlan plan,
  DeviceProfile profile,
) =>
    RuntimeConfig(
      contextSize: plan.contextSize,
      threads: plan.threads,
      batchThreads: plan.batchThreads,
      batchSize: plan.batchSize,
      microBatchSize: plan.microBatchSize,
      sessionCount: plan.sessionCacheEntries,
      kvType: plan.compactKv ? KvCacheType.q4_0 : KvCacheType.f16,
      flashAttention:
          plan.flashAttention ? FlashAttention.on : FlashAttention.off,
      gpuLayers: 0,
      deviceName: '',
      isCpu: true,
    );

/// Picks the single most promising accelerator device from the runtime's
/// backend enumeration.
///
/// Order: Hexagon NPU first (best token/sec/watt on Snapdragon), then GPU
/// (Metal/CUDA/Vulkan preferred, OpenCL as the Adreno/Mali fallback). The
/// CPU and the BLAS meta-backend are never chosen.
BackendDevice? preferredAccelerator(List<BackendDevice> devices) {
  BackendDevice? npu;
  BackendDevice? gpu;
  var gpuPriority = 0;

  for (final device in devices) {
    if (device.type == BackendDeviceType.cpu) continue;
    if (device.registryName.toLowerCase() == 'blas') continue;

    final registry = device.registryName.toLowerCase();
    final name = device.name.toUpperCase();
    final isNpu = device.type == BackendDeviceType.accel ||
        registry.contains('hexagon') ||
        registry.contains('htp') ||
        name.startsWith('HTP');
    if (isNpu) {
      npu ??= device;
      continue;
    }

    final priority = _gpuPriority(device.registryName);
    if (priority > gpuPriority) {
      gpuPriority = priority;
      gpu = device;
    }
  }
  return npu ?? gpu;
}

int _gpuPriority(String registryName) => switch (registryName) {
      'Metal' || 'CUDA' => 4,
      'Vulkan' => 3,
      'OpenCL' => 2,
      _ => 1,
    };

/// Classifies a discovered device as NPU or GPU for diagnostics.
ComputeBackend classifyBackend(BackendDevice device) {
  final registry = device.registryName.toLowerCase();
  final name = device.name.toUpperCase();
  if (device.type == BackendDeviceType.accel ||
      registry.contains('hexagon') ||
      registry.contains('htp') ||
      name.startsWith('HTP')) {
    return ComputeBackend.npu;
  }
  return ComputeBackend.gpu;
}

/// Conservative offload gate: acceleration only runs when there is enough
/// system RAM for the model plus a healthy headroom for KV cache, the OS, and
/// the app itself. Unknown available RAM is treated as permitted — the CPU
/// fallback ladder still protects against a failed accelerated spawn.
bool hasOffloadHeadroom({
  required DeviceProfile profile,
  required int modelBytes,
}) {
  final available = profile.availableRamBytes;
  if (available == null) return true;
  return available >= modelBytes + (1100 * 1024 * 1024);
}

/// Upgrades the CPU baseline to offload onto [device]. Uses a negative layer
/// count so llama.cpp offloads every layer onto the accelerator.
RuntimeConfig acceleratedConfig(RuntimeConfig cpu, BackendDevice device) =>
    cpu.copyWith(gpuLayers: -1, deviceName: device.name, isCpu: false);

class SelectionOutcome {
  const SelectionOutcome({
    required this.config,
    required this.results,
    required this.reason,
    this.engine,
    this.selection,
  });

  final RuntimeConfig config;
  final List<Object> results;
  final String reason;
  final LlamaEngine? engine;
  final BackendSelection? selection;
}

class AdaptiveDiagnostics {
  const AdaptiveDiagnostics(this.text);
  final String text;

  String toDiagnosticsString() => text;
}

class BenchmarkProfile {
  const BenchmarkProfile({required this.label, required this.createdAt});
  final String label;
  final DateTime createdAt;
}

class EngineStatus {
  const EngineStatus({required this.ready, required this.message});
  final bool ready;
  final String message;
}

/// Owns backend discovery, selection, and the persistent per-device cache.
///
/// The CPU baseline is always returned first. Once a worker isolate reports
/// the backends it actually loaded ([accelerateIfAvailable]), the selection is
/// upgraded to the best NPU/GPU and cached so the next cold start can spawn
/// the accelerated config directly. A failed accelerated spawn falls back to
/// the CPU engine at the call site, so a stale cache can never brick startup.
class AdaptiveInferenceEngine {
  AdaptiveInferenceEngine._();

  static final instance = AdaptiveInferenceEngine._();

  DeviceProfile? _profile;
  RuntimeConfig? _config;
  String? _llamaCppCommit;
  BackendSelection? _selection;
  String? _appVersion;

  /// Device+model fingerprints whose quantized KV cache could not be created
  /// by llama.cpp (`llama_init_from_model` returns null for an unsupported KV
  /// type). [FinnAccelerator] recovers by retrying with F16, but without this
  /// memory every cold start repeated the doomed native init — several seconds
  /// of delay plus a native error log before the first reply of each launch.
  final List<String> _compactKvUnsupported = <String>[];
  bool _compactKvCacheLoaded = false;

  /// Fingerprints are kept newest-last; older ones are dropped so an app that
  /// is updated repeatedly does not grow the file without bound.
  static const int _maxCompactKvFingerprints = 8;

  Directory? _cacheDirectoryOverride;

  /// Test hook: redirects the on-device cache file into [directory].
  @visibleForTesting
  set debugCacheDirectory(Directory? directory) {
    _cacheDirectoryOverride = directory;
    _compactKvCacheLoaded = false;
    _compactKvUnsupported.clear();
  }

  @visibleForTesting
  void debugResetCacheState() {
    _compactKvCacheLoaded = false;
    _compactKvUnsupported.clear();
  }

  /// Selects the initial config. Returns a cached accelerator when the device
  /// fingerprint still matches; otherwise the conservative CPU baseline.
  Future<SelectionOutcome> select({
    required String modelPath,
    required String modelSha256,
    required String modelLabel,
    required InferencePlan heuristicPlan,
  }) async {
    final profile = _profile ?? await DeviceProfiler.read();
    _profile = profile;
    final cpu = await _withSupportedKv(
      runtimeConfigFromPlan(heuristicPlan, profile),
      profile,
      modelSha256,
    );

    // Benchmark harness overrides always win over the cached backend so
    // config sweeps are honored without editing the cache.
    if (!DeviceProfiler.planOverrides.isEmpty) {
      _config = cpu;
      _selection = null;
      return SelectionOutcome(
        config: cpu,
        results: const [],
        reason: 'Benchmark override config selected.',
      );
    }

    final cached = await _readCachedSelection(profile, modelSha256);
    if (cached != null) {
      final cachedConfig = await _withSupportedKv(
        cached.config,
        profile,
        modelSha256,
      );
      final effective = cachedConfig == cached.config
          ? cached
          : cached.copyWithConfig(cachedConfig);
      _config = effective.config;
      _selection = effective;
      return SelectionOutcome(
        config: effective.config,
        results: const [],
        reason: 'Cached ${effective.backend.name} backend: '
            '${effective.deviceName}.',
        selection: effective,
      );
    }

    _config = cpu;
    _selection = null;
    return SelectionOutcome(
      config: cpu,
      results: const [],
      reason: 'Conservative mobile CPU profile selected.',
    );
  }

  /// Inspects the backends the freshly spawned engine actually loaded and, if
  /// a supported accelerator is available with enough RAM, upgrades to it and
  /// persists the decision. Returns null when CPU should be kept.
  Future<BackendSelection?> accelerateIfAvailable({
    required List<BackendDevice> devices,
    required DeviceProfile profile,
    required InferencePlan plan,
    required String modelSha256,
    required int modelBytes,
  }) async {
    // On mobile Android devices, CPU inference with ARM Neon SIMD is rock-solid,
    // power-efficient, and avoids GPU/Vulkan driver crashes across vendor chips.
    if (Platform.isAndroid) return null;

    final device = preferredAccelerator(devices);
    if (device == null) return null;

    final backend = classifyBackend(device);
    if (!hasOffloadHeadroom(profile: profile, modelBytes: modelBytes)) {
      return null;
    }

    final selection = BackendSelection(
      config: acceleratedConfig(runtimeConfigFromPlan(plan, profile), device),
      backend: backend,
      deviceName: device.name,
      registryName: device.registryName,
      reason: 'Discovered ${backend.name} device ${device.name} '
          '(${device.registryName}).',
    );
    _config = selection.config;
    _selection = selection;
    await _writeCachedSelection(profile, modelSha256, selection);
    return selection;
  }

  void attachLlamaCppCommit(String? commit) {
    if (commit != null && commit.isNotEmpty) _llamaCppCommit = commit;
  }

  /// True when a quantized KV cache is known to be unusable for this device
  /// and model, so planning F16 saves a doomed native init at startup.
  Future<bool> isCompactKvUnsupported({
    required DeviceProfile profile,
    required String modelSha256,
  }) async {
    await _loadCompactKvCache();
    if (_compactKvUnsupported.isEmpty) return false;
    return _compactKvUnsupported.contains(
      await _kvFingerprint(profile, modelSha256),
    );
  }

  /// Records that a quantized KV cache could not be created here, so later
  /// launches plan F16 directly instead of failing first.
  Future<void> recordCompactKvUnsupported({
    required DeviceProfile profile,
    required String modelSha256,
  }) async {
    await _loadCompactKvCache();
    final fingerprint = await _kvFingerprint(profile, modelSha256);
    if (_compactKvUnsupported.contains(fingerprint)) return;
    _compactKvUnsupported.add(fingerprint);
    while (_compactKvUnsupported.length > _maxCompactKvFingerprints) {
      _compactKvUnsupported.removeAt(0);
    }
    debugPrint('FINN_KV_MEMO quantized KV unsupported; planning F16 KV');
    await _flushCompactKvCache();
  }

  /// Downgrades [config] to F16 KV when this device cannot create a quantized
  /// one. Every other setting is preserved.
  Future<RuntimeConfig> _withSupportedKv(
    RuntimeConfig config,
    DeviceProfile profile,
    String modelSha256,
  ) async {
    final compact =
        config.kvType != KvCacheType.f16 && config.kvType != KvCacheType.f32;
    if (!compact) return config;
    final unsupported = await isCompactKvUnsupported(
      profile: profile,
      modelSha256: modelSha256,
    );
    if (!unsupported) return config;
    return config.copyWith(kvType: KvCacheType.f16);
  }

  Future<void> _loadCompactKvCache() async {
    if (_compactKvCacheLoaded) return;
    _compactKvCacheLoaded = true;
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return;
      final data =
          (jsonDecode(await file.readAsString()) as Map<Object?, Object?>)
              .cast<String, Object?>();
      final stored = data['compactKvUnsupported'];
      if (stored is List) {
        _compactKvUnsupported
          ..clear()
          ..addAll(stored.whereType<String>());
      }
    } catch (_) {
      // The cache is an optimization; a read failure just re-attempts.
    }
  }

  Future<void> _flushCompactKvCache() async {
    try {
      final file = await _cacheFile();
      await file.parent.create(recursive: true);
      var data = <String, Object?>{};
      if (await file.exists()) {
        try {
          data =
              (jsonDecode(await file.readAsString()) as Map<Object?, Object?>)
                  .cast<String, Object?>();
        } catch (_) {
          // Overwrite a corrupt cache rather than failing.
        }
      }
      data['compactKvUnsupported'] = List<String>.of(_compactKvUnsupported);
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // Worst case the next launch repeats one fallback attempt.
    }
  }

  /// True when there is no cached accelerator selection that is still valid
  /// for this device, model, and app build. Used to decide whether the
  /// one-time post-download benchmark should run again after an app update.
  Future<bool> isBenchmarkStale({
    required DeviceProfile profile,
    required String modelSha256,
  }) async =>
      (await _readCachedSelection(profile, modelSha256)) == null;

  /// Drops a persisted accelerator decision (e.g. after a cached backend
  /// failed or timed out at spawn). The next cold start re-runs discovery
  /// instead of retrying the broken backend.
  Future<void> invalidateCachedSelection() async {
    _config = null;
    _selection = null;
    try {
      final file = await _cacheFile();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort: a stale cache simply gets ignored on the next read.
    }
  }

  /// Persists the measured benchmark winner so later cold starts reuse it.
  Future<void> recordBenchmark({
    required DeviceProfile profile,
    required String modelSha256,
    required BackendSelection selection,
  }) async {
    _config = selection.config;
    _selection = selection;
    await _writeCachedSelection(profile, modelSha256, selection);
  }

  AdaptiveDiagnostics diagnostics() {
    final selection = _selection;
    final backend = selection == null
        ? (_config?.isCpu == true ? 'CPU' : 'accelerated')
        : '${selection.backend.name} (${selection.deviceName})';
    return AdaptiveDiagnostics(
      'LFM2.5-VL 1.6B\n'
      'runtime=${_llamaCppCommit ?? 'bundled llama.cpp'}\n'
      'backend=$backend\n'
      'context=${_config?.contextSize ?? 'not selected'}',
    );
  }

  Future<DeviceProfile> deviceInfo() async =>
      _profile ??= await DeviceProfiler.read();

  Future<BenchmarkProfile?> performanceProfile() async => null;

  EngineStatus status() => EngineStatus(
        ready: _config != null,
        message: _config == null
            ? 'Profile not selected'
            : (_selection == null
                ? 'Ready (CPU)'
                : 'Ready (${_selection!.backend.name})'),
      );

  @visibleForTesting
  BackendSelection? get selectionForTest => _selection;

  Future<String> _fingerprint(DeviceProfile profile, String modelSha256) async {
    // The app version invalidates the cache after a software update so the
    // benchmark re-runs against the newly shipped runtime.
    final raw = '${profile.processor}|${profile.totalRamBytes}|$modelSha256|'
        '${profile.nativeLibraryDir}|${await _appVersionString()}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  /// Fingerprint for the quantized-KV capability memory.
  ///
  /// Deliberately excludes [DeviceProfile.nativeLibraryDir]. On Android that
  /// path embeds the per-install random `/data/app/~~<id>==/…` directory, so
  /// folding it in would drop the memory on every update and make each user pay
  /// the doomed native init again after each release. The capability being
  /// remembered is a property of the chip, the model and the shipped runtime,
  /// none of which that path describes.
  Future<String> _kvFingerprint(
    DeviceProfile profile,
    String modelSha256,
  ) async {
    final raw = '${profile.processor}|${profile.totalRamBytes}|$modelSha256|'
        '${await _appVersionString()}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Future<String> _appVersionString() async {
    if (_appVersion == null) {
      try {
        final info = await PackageInfo.fromPlatform();
        _appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {
        _appVersion = 'unknown';
      }
    }
    return _appVersion!;
  }

  Future<File> _cacheFile() async {
    final root =
        _cacheDirectoryOverride ?? await getApplicationSupportDirectory();
    return File('${root.path}${Platform.pathSeparator}adaptive_backend.json');
  }

  Future<BackendSelection?> _readCachedSelection(
    DeviceProfile profile,
    String modelSha256,
  ) async {
    if (Platform.isAndroid) return null;
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;
      final data =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      if (data['fingerprint'] != await _fingerprint(profile, modelSha256)) {
        return null;
      }
      final config = RuntimeConfig.fromJson(
        (data['config'] as Map).cast<String, Object?>(),
      );
      final backend = ComputeBackend.values.firstWhere(
        (e) => e.name == data['backend'],
        orElse: () => ComputeBackend.cpu,
      );
      return BackendSelection(
        config: config,
        backend: backend,
        deviceName: data['deviceName'] as String? ?? config.deviceName,
        registryName: data['registryName'] as String? ?? '',
        reason: 'Restored cached backend selection.',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCachedSelection(
    DeviceProfile profile,
    String modelSha256,
    BackendSelection selection,
  ) async {
    try {
      final file = await _cacheFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'fingerprint': await _fingerprint(profile, modelSha256),
          'config': selection.config.toJson(),
          'backend': selection.backend.name,
          'deviceName': selection.deviceName,
          'registryName': selection.registryName,
        }),
        flush: true,
      );
    } catch (_) {
      // The cache is an optimization. A write failure must never affect the
      // in-memory selection for the current session.
    }
  }
}
