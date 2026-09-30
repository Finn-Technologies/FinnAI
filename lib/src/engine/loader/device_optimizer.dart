part of '../finn_accelerator.dart';

extension FinnAcceleratorOptimizer on FinnAccelerator {
  Future<void> optimizeForDevice() async {
    if (_benchmarkRunning || _replyInFlight || _runtimes.isNotEmpty) return;
    // Android inference is pinned to the CPU path: AdaptiveInferenceEngine
    // never restores a cached selection there and accelerateIfAvailable bails
    // out immediately, so select() discards whatever this benchmark records.
    // Running it anyway spawned two extra engines and burned up to ~30s of CPU
    // on every cold start (the selection cache is not restored on Android, so
    // needsBenchmark() always reported stale) while changing nothing.
    if (Platform.isAndroid) return;
    if (!Platform.isLinux) return;
    _benchmarkRunning = true;
    try {
      _setStatus(
        InferencePhase.loading,
        'Setting up FinnAI for optimal performance…',
        key: FinnStatusKey.optimizingForDevice,
      );
      final model = selected;
      if (!await isInstalled(model)) return;
      final path = (await _modelFile(model)).path;
      final profile = _deviceProfile ?? await DeviceProfiler.read();
      _deviceProfile = profile;
      final plan = _plan ?? DeviceProfiler.plan(profile);
      final adaptive = AdaptiveInferenceEngine.instance;

      // Discover the backends actually packaged with the runtime via a
      // lightweight CPU probe. Its own load is not benchmarked.
      final List<BackendDevice> devices;
      final probe = await _spawnBenchmarkEngine(
        model: model,
        path: path,
        config: runtimeConfigFromPlan(plan, profile),
        profile: profile,
        compactKv: plan.compactKv,
      ).timeout(const Duration(seconds: 60));
      try {
        devices = probe.devices;
      } finally {
        await probe.dispose();
      }

      final cpuConfig = runtimeConfigFromPlan(plan, profile);
      var bestTps = -1.0;
      BackendSelection best = BackendSelection(
        config: cpuConfig,
        backend: ComputeBackend.cpu,
        deviceName: 'CPU',
        registryName: 'CPU',
        reason: 'CPU baseline',
      );

      // Only test the single top preferred accelerator candidate (e.g. Hexagon NPU
      // or Vulkan/OpenCL GPU) rather than iterating through all backends.
      final candidate = preferredAccelerator(devices);
      if (!FinnAccelerator.debugForceCpu &&
          candidate != null &&
          candidate.isAccelerator &&
          candidate.registryName.toLowerCase() != 'blas' &&
          hasOffloadHeadroom(
            profile: profile,
            modelBytes: model.expectedBytes,
          )) {
        final config = acceleratedConfig(cpuConfig, candidate);
        try {
          final tps = await _benchmarkTokensPerSecond(
            model,
            path,
            config,
            profile,
            compactKv: plan.compactKv,
          ).timeout(const Duration(seconds: 15));
          debugPrint(
            'FINN_BENCH ${candidate.registryName}/${candidate.name} '
            '${tps.toStringAsFixed(2)} tok/s',
          );
          if (tps > 0) {
            bestTps = tps;
            best = BackendSelection(
              config: config,
              backend: classifyBackend(candidate),
              deviceName: candidate.name,
              registryName: candidate.registryName,
              reason: 'Benchmarked fastest backend.',
            );
          }
        } catch (e) {
          debugPrint(
            'FINN_BENCH skip candidate ${candidate.registryName}/${candidate.name}: $e',
          );
        }
      }

      // The CPU baseline is measured if accelerator was not selected or to verify floor.
      if (bestTps <= 0) {
        try {
          final cpuTps = await _benchmarkTokensPerSecond(
            model,
            path,
            cpuConfig,
            profile,
            compactKv: plan.compactKv,
          ).timeout(const Duration(seconds: 15));
          debugPrint('FINN_BENCH CPU ${cpuTps.toStringAsFixed(2)} tok/s');
          if (cpuTps > bestTps) {
            bestTps = cpuTps;
          }
        } catch (e) {
          debugPrint('FINN_BENCH cpu baseline failed: $e');
        }
      }

      // Persist the winner even when it is CPU so the benchmark does not run
      // again on every launch of a CPU-only or CPU-fastest device.
      await adaptive.recordBenchmark(
        profile: profile,
        modelSha256: model.sha256Digest,
        selection: best,
      );
      debugPrint(
        'FINN_BENCH selected ${best.backend.name} '
        '${best.deviceName} at ${bestTps.toStringAsFixed(2)} tok/s',
      );
      _setStatus(
        InferencePhase.idle,
        'FinnAI is optimized for this device',
        key: FinnStatusKey.optimizedForDevice,
      );
    } catch (e) {
      debugPrint('FINN_BENCH failed, keeping CPU fallback: $e');
      _setStatus(
        InferencePhase.idle,
        'FinnAI is optimized for this device',
        key: FinnStatusKey.optimizedForDevice,
      );
    } finally {
      _benchmarkRunning = false;
    }
  }

  Future<bool> needsBenchmark() async {
    final profile = _deviceProfile ?? await DeviceProfiler.read();
    return AdaptiveInferenceEngine.instance.isBenchmarkStale(
      profile: profile,
      modelSha256: selected.sha256Digest,
    );
  }

  Future<LlamaEngine> _spawnBenchmarkEngine({
    required FinnModelSpec model,
    required String path,
    required RuntimeConfig config,
    required DeviceProfile profile,
    required bool compactKv,
  }) async {
    return LlamaEngine.spawn(
      libraryPath: 'libllama.so',
      backendDirectory: profile.nativeLibraryDir,
      // The benchmark engine solely probes language model throughput and device
      // performance; do not allocate the multimodal vision projector here.
      multimodalParams: null,
      modelParams: ModelParams(
        path: path,
        gpuLayers: config.gpuLayers,
        useMmap: true,
        // Weights stay RAM-resident via the OS page cache with mmap alone
        // (verified: zero major faults during decode). Locking 1.3 GB
        // actively hurts on 8 GB-class devices by removing reclaimable
        // headroom the OS needs for the KV cache and the app itself.
        useMlock: false,
        checkTensors: false,
        // Explicit device list: an EMPTY devices array means "use every
        // loaded backend" (llama.cpp default), which pulls the Vulkan
        // backend into CPU configs and allocates GPU compute buffers +
        // triggers driver shader compiles. Pin CPU configs to the CPU
        // device by name.
        devices: config.isCpu ? const ['CPU'] : [config.deviceName],
      ),
      contextParams: ContextParams(
        nCtx: config.contextSize,
        nBatch: config.batchSize,
        nUbatch: config.microBatchSize,
        nThreads: config.threads,
        nThreadsBatch: config.batchThreads,
        nSeqMax: config.sessionCount,
        flashAttn: config.flashAttention,
        typeK: compactKv ? config.kvType : KvCacheType.f16,
        typeV: compactKv ? config.kvType : KvCacheType.f16,
        defragThreshold: DeviceProfiler.isLowEnd(profile) ? 0.1 : -1.0,
        swaFull: false,
        noPerf: false,
        // Recurrent-state snapshots for lookahead decoding rollback.
        nRsSeq: DeviceProfiler.lookaheadSnapshots(profile),
      ),
    );
  }

  Future<double> _benchmarkTokensPerSecond(
    FinnModelSpec model,
    String path,
    RuntimeConfig config,
    DeviceProfile profile, {
    required bool compactKv,
  }) async {
    final engine = await _spawnBenchmarkEngine(
      model: model,
      path: path,
      config: config,
      profile: profile,
      compactKv: compactKv,
    );
    try {
      final session = await engine.createSession(seqId: 0);
      final watch = Stopwatch()..start();
      var tokens = 0;
      await for (final event in session.generate(
        prompt: 'Hello',
        addSpecial: true,
        parseSpecial: true,
        sampler: SamplerParams.greedyDefault,
        maxTokens: 16,
        shiftPolicy:
            engine.canShift ? ContextShiftPolicy.auto : ContextShiftPolicy.off,
      )) {
        if (event case DoneEvent(:final generatedCount)) {
          tokens = generatedCount;
        }
      }
      watch.stop();
      await session.dispose();
      if (watch.elapsedMilliseconds <= 0 || tokens <= 0) return 0;
      return tokens * 1000 / watch.elapsedMilliseconds;
    } finally {
      await engine.dispose();
    }
  }
}
