part of '../finn_accelerator.dart';

extension FinnAcceleratorLoader on FinnAccelerator {
  Future<_ModelRuntime> _ensureLoaded(FinnModelSpec model, String path) async {
    await _pendingUnload;
    final loaded = _runtimes[model.tier];
    if (loaded != null) return loaded;
    return _deduplicatedLoads.run(model.tier, () async {
      final epoch = _runtimeEpoch;
      final job = _loadModel(model, path, epoch);
      _loadJobs[model.tier] = job;
      try {
        return await job;
      } finally {
        if (identical(_loadJobs[model.tier], job)) {
          _loadJobs.remove(model.tier);
        }
      }
    });
  }

  Future<_ModelRuntime> _loadModel(
    FinnModelSpec model,
    String path,
    int epoch,
  ) async {
    final loaded = _runtimes[model.tier];
    if (loaded != null) return loaded;
    _setStatus(
      InferencePhase.loading,
      'Loading the AI model',
      key: FinnStatusKey.loadingModel,
    );

    final profile = _deviceProfile ?? await DeviceProfiler.read();
    final hardwarePlan = _plan ?? DeviceProfiler.plan(profile);

    // Adaptive selection: measure (or reuse a cached profile for) the best
    // backend + configuration for this exact device and model. The heuristic
    // plan remains the guaranteed fallback; the q8_0→F16 KV retry below is
    // the last-resort compatibility baseline.
    final adaptive = AdaptiveInferenceEngine.instance;
    SelectionOutcome outcome;
    try {
      outcome = await adaptive
          .select(
            modelPath: path,
            modelSha256: model.sha256Digest,
            modelLabel: model.name,
            heuristicPlan: hardwarePlan,
          )
          .timeout(const Duration(seconds: 40));
    } on TimeoutException catch (e) {
      debugPrint('FINN_ADAPTIVE_TIMEOUT $e');
      final fallbackConfig = runtimeConfigFromPlan(hardwarePlan, profile);
      outcome = SelectionOutcome(
        config: fallbackConfig,
        results: const [],
        reason: 'Adaptive selection timed out; using heuristic CPU plan.',
      );
    }
    adaptive.attachLlamaCppCommit(
      outcome.engine?.llamaCppCommit ?? _lastKnownLlamaCppCommit,
    );
    var config = outcome.config;
    // A benchmarked engine for the selected config can be reused directly.
    LlamaEngine? engine = outcome.engine;

    final mmprojFile = await _mmprojFile();
    final hasMmproj = await mmprojFile.exists() &&
        await mmprojFile.length() == finnMmproj.expectedBytes;

    if (engine != null && hasMmproj && !engine.multimodalLoaded) {
      await engine.dispose();
      engine = null;
    }

    Future<LlamaEngine> spawnWith(
      RuntimeConfig cfg, {
      required bool compactKv,
    }) async {
      // Projector GPU offload is disabled on Android to eliminate legacy Vulkan
      // driver crashes and prevent gigabytes of GPU buffer memory allocation.
      final useProjectorGpu = !Platform.isAndroid &&
          hasOffloadHeadroom(
            profile: profile,
            modelBytes: model.expectedBytes,
          );
      final constrainedForProjector = DeviceProfiler.isLowEnd(profile) ||
          (profile.availableRamBytes != null &&
              profile.availableRamBytes! < 1800 * 1024 * 1024) ||
          (profile.totalRamBytes != null &&
              profile.totalRamBytes! <= 3000 * 1000 * 1000);
      final projectorMinTokens = constrainedForProjector ? 96 : 64;
      final projectorMaxTokens = constrainedForProjector ? 192 : 256;
      return LlamaEngine.spawn(
        libraryPath: 'libllama.so',
        backendDirectory: profile.nativeLibraryDir,
        multimodalParams: hasMmproj
            ? MultimodalParams(
                mmprojPath: mmprojFile.path,
                useGpu: useProjectorGpu,
                nThreads: cfg.batchThreads > 0 ? cfg.batchThreads : 8,
                imageMinTokens: projectorMinTokens,
                imageMaxTokens: projectorMaxTokens,
              )
            : null,
        modelParams: ModelParams(
          path: path,
          gpuLayers: cfg.gpuLayers,
          useMmap: true,
          // Weights stay RAM-resident via the OS page cache with mmap alone
          // (verified: zero major faults during decode). Locking 1.3 GB
          // actively hurts on 8 GB-class devices by removing reclaimable
          // headroom the OS needs for the KV cache and the app itself.
          useMlock: false,
          checkTensors: false,
          // See _spawnBenchmarkEngine: empty devices = all backends (Vulkan
          // included); pin CPU configs to the CPU device by name.
          devices: cfg.isCpu ? const ['CPU'] : [cfg.deviceName],
        ),
        contextParams: ContextParams(
          nCtx: cfg.contextSize,
          nBatch: cfg.batchSize,
          nUbatch: cfg.microBatchSize,
          nThreads: cfg.threads,
          nThreadsBatch: cfg.batchThreads,
          nSeqMax: cfg.sessionCount,
          flashAttn: cfg.flashAttention,
          typeK: compactKv ? cfg.kvType : KvCacheType.f16,
          typeV: compactKv ? cfg.kvType : KvCacheType.f16,
          defragThreshold: DeviceProfiler.isLowEnd(profile) ? 0.1 : -1.0,
          swaFull: false,
          noPerf: false,
          // Recurrent-state snapshots for lookahead decoding rollback.
          nRsSeq: DeviceProfiler.lookaheadSnapshots(profile),
        ),
      );
    }

    var compactKv =
        config.kvType != KvCacheType.f16 && config.kvType != KvCacheType.f32;
    var fellBackFromAccelerator = false;
    var fellBackFromCompactKv = false;
    try {
      engine ??= await spawnWith(
        config,
        compactKv: compactKv,
      ).timeout(const Duration(seconds: 90));
    } on TimeoutException catch (e) {
      debugPrint('FINN_LOADMODEL spawn timeout: $e');
      if (!config.isCpu) {
        // A cached accelerator hung at spawn (e.g. a broken driver's slow
        // shader compilation). Drop the bad cached pick, fall back to the
        // guaranteed CPU baseline, and make sure the next launch does not
        // retry the same broken backend.
        await adaptive.invalidateCachedSelection();
        config = runtimeConfigFromPlan(hardwarePlan, profile);
        compactKv = config.kvType != KvCacheType.f16 &&
            config.kvType != KvCacheType.f32;
        fellBackFromAccelerator = true;
        try {
          engine = await spawnWith(
            config,
            compactKv: compactKv,
          ).timeout(const Duration(seconds: 90));
        } on TimeoutException catch (e2) {
          debugPrint('FINN_LOADMODEL cpu fallback timeout: $e2');
          throw TimeoutException(
            'Model engine did not start in time. ${_friendlyError(e2)}',
          );
        }
      } else {
        throw TimeoutException(
          'Model engine did not start in time. ${_friendlyError(e)}',
        );
      }
    } catch (e) {
      if (config.isCpu && compactKv) {
        // Quantized KV is not universal. The F16 retry below is the
        // compatibility baseline, so this failure is expected and handled
        // rather than a load error — logging it as one made a normal first
        // launch look broken.
        debugPrint(
          'FINN_KV_FALLBACK quantized KV init failed, retrying F16: $e',
        );
      } else {
        debugPrint('FINN_LOADMODEL_ERROR $e');
      }
      if (!config.isCpu) {
        // A stale cached accelerator config failed (driver changed or the
        // backend was removed from the APK). Fall back to the guaranteed CPU
        // baseline instead of failing startup.
        await adaptive.invalidateCachedSelection();
        config = runtimeConfigFromPlan(hardwarePlan, profile);
        compactKv = config.kvType != KvCacheType.f16 &&
            config.kvType != KvCacheType.f32;
        fellBackFromAccelerator = true;
        try {
          engine = await spawnWith(
            config,
            compactKv: compactKv,
          ).timeout(const Duration(seconds: 90));
        } on TimeoutException catch (e2) {
          debugPrint('FINN_LOADMODEL cpu fallback timeout: $e2');
          throw TimeoutException(
            'Model engine did not start in time. ${_friendlyError(e2)}',
          );
        }
      } else if (compactKv) {
        // Quantized KV/Flash Attention is not universal. The F16 retry is the
        // compatibility baseline for older chips and vendor runtimes.
        compactKv = false;
        try {
          engine = await spawnWith(
            config,
            compactKv: false,
          ).timeout(const Duration(seconds: 90));
          fellBackFromCompactKv = true;
        } on TimeoutException catch (e2) {
          debugPrint('FINN_LOADMODEL retry timeout: $e2');
          throw TimeoutException(
            'Model engine did not start in time. ${_friendlyError(e2)}',
          );
        }
      } else {
        rethrow;
      }
    }

    if (fellBackFromCompactKv) {
      // Remember this device's KV capability so the next cold start plans F16
      // directly instead of paying another doomed quantized-KV native init.
      await adaptive.recordCompactKvUnsupported(
        profile: profile,
        modelSha256: model.sha256Digest,
      );
    }

    final primaryEngine = engine;
    _lastKnownLlamaCppCommit = primaryEngine.llamaCppCommit;
    adaptive.attachLlamaCppCommit(_lastKnownLlamaCppCommit);

    // The engine is now live. Inspect the backends the runtime actually
    // loaded and upgrade to the best NPU/GPU when available. A failed
    // accelerated spawn keeps the working CPU engine. Skip discovery when the
    // benchmark already cached a decision (including a deliberate CPU pick) or
    // when we just fell back from a cached accelerator that could not spawn.
    if (!FinnAccelerator.debugForceCpu &&
        outcome.selection == null &&
        config.isCpu &&
        !fellBackFromAccelerator) {
      try {
        final selection = await adaptive
            .accelerateIfAvailable(
              devices: primaryEngine.devices,
              profile: profile,
              plan: hardwarePlan,
              modelSha256: model.sha256Digest,
              modelBytes: model.expectedBytes,
            )
            .timeout(const Duration(seconds: 10));
        if (selection != null) {
          debugPrint(
            'FINN_ADAPTIVE accelerating on ${selection.backend.name} '
            '${selection.deviceName} (${selection.registryName})',
          );
          try {
            final accelerated = await spawnWith(
              selection.config,
              compactKv: compactKv,
            ).timeout(const Duration(seconds: 90));
            await primaryEngine.dispose();
            engine = accelerated;
            config = selection.config;
            _lastKnownLlamaCppCommit = accelerated.llamaCppCommit;
            adaptive.attachLlamaCppCommit(_lastKnownLlamaCppCommit);
          } catch (e) {
            debugPrint('FINN_ADAPTIVE offload failed, keeping CPU: $e');
          }
        }
      } catch (e) {
        debugPrint('FINN_ADAPTIVE discovery failed: $e');
      }
    }

    final liveEngine = engine!;
    debugPrint(
      'FINN_ENGINE threads=${config.threads} batchThreads=${config.batchThreads} '
      'batch=${config.batchSize} ubatch=${config.microBatchSize} '
      'kv=${compactKv ? config.kvType.name : "f16"} flash=${config.flashAttention.name} '
      'ctx=${config.contextSize} gpu=${config.gpuLayers} '
      'dev=${config.deviceName} cpu=${config.isCpu}',
    );
    if (epoch != _runtimeEpoch) {
      await liveEngine.dispose();
      throw StateError('Model loading was superseded by a memory release.');
    }
    final modelSha256 = model.sha256Digest.isEmpty
        ? (FinnAccelerator.debugSkipSha256
            ? 'benchmark-skip-sha256'
            : await sha256
                .bind(File(path).openRead())
                .first
                .then((digest) => digest.toString()))
        : model.sha256Digest;
    final runtime = _ModelRuntime(
      model,
      liveEngine,
      compactKv: compactKv,
      contextSize: config.contextSize,
      modelSha256: modelSha256,
      kvType: config.kvType,
    );
    _runtimes[model.tier] = runtime;
    return runtime;
  }

  String diagnostics() =>
      AdaptiveInferenceEngine.instance.diagnostics().toDiagnosticsString();

  Future<DeviceProfile> deviceInfo() =>
      AdaptiveInferenceEngine.instance.deviceInfo();

  Future<BenchmarkProfile?> performanceProfile() =>
      AdaptiveInferenceEngine.instance.performanceProfile();

  EngineStatus adaptiveStatus() => AdaptiveInferenceEngine.instance.status();
}
