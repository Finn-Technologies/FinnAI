import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../device_profile.dart';

/// Runtime knobs selected for one device. The current product deliberately
/// uses a conservative CPU baseline; the facade leaves room for a measured
/// backend selector without making model startup depend on a benchmark run.
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
}

RuntimeConfig runtimeConfigFromPlan(
  InferencePlan plan,
  DeviceProfile profile,
) => RuntimeConfig(
  contextSize: plan.contextSize,
  threads: plan.threads,
  batchThreads: plan.batchThreads,
  batchSize: plan.batchSize,
  microBatchSize: plan.microBatchSize,
  sessionCount: plan.sessionCacheEntries,
  kvType: plan.compactKv ? KvCacheType.q8_0 : KvCacheType.f16,
  flashAttention: plan.flashAttention ? FlashAttention.on : FlashAttention.off,
  // Keep the first Qwen 3.5 release on the well-tested CPU path. The native
  // runtime can still use optimized CPU kernels from its bundled backends.
  gpuLayers: 0,
  deviceName: '',
  isCpu: true,
);

class SelectionOutcome {
  const SelectionOutcome({
    required this.config,
    required this.results,
    required this.reason,
    this.engine,
  });

  final RuntimeConfig config;
  final List<Object> results;
  final String reason;
  final LlamaEngine? engine;
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

/// Small compatibility facade used by the inference owner. It avoids an
/// expensive benchmark on every cold start while keeping diagnostics and a
/// future measured selector behind one API.
class AdaptiveInferenceEngine {
  AdaptiveInferenceEngine._();

  static final instance = AdaptiveInferenceEngine._();
  DeviceProfile? _profile;
  RuntimeConfig? _config;
  String? _llamaCppCommit;

  Future<SelectionOutcome> select({
    required String modelPath,
    required String modelSha256,
    required String modelLabel,
    required InferencePlan heuristicPlan,
  }) async {
    final profile = _profile ?? await DeviceProfiler.read();
    _profile = profile;
    final config = runtimeConfigFromPlan(heuristicPlan, profile);
    _config = config;
    return SelectionOutcome(
      config: config,
      results: const [],
      reason: 'Conservative mobile CPU profile selected.',
    );
  }

  void attachLlamaCppCommit(String? commit) {
    if (commit != null && commit.isNotEmpty) _llamaCppCommit = commit;
  }

  AdaptiveDiagnostics diagnostics() => AdaptiveDiagnostics(
    'Qwen 3.5 2B\n'
    'runtime=${_llamaCppCommit ?? 'bundled llama.cpp'}\n'
    'backend=${_config?.isCpu == true ? 'CPU' : 'accelerated'}\n'
    'context=${_config?.contextSize ?? 'not selected'}',
  );

  Future<DeviceProfile> deviceInfo() async => _profile ??= await DeviceProfiler.read();

  Future<BenchmarkProfile?> performanceProfile() async => null;

  EngineStatus status() => EngineStatus(
    ready: _config != null,
    message: _config == null ? 'Profile not selected' : 'Ready',
  );
}
