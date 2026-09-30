part of '../finn_accelerator.dart';

extension FinnAcceleratorSessions on FinnAccelerator {
  Future<_PreparedSession> _prepareSession(
    _ModelRuntime runtime,
    String conversationId,
    List<LocalChatTurn> history,
    String systemContext, {
    String taskInstruction = '',
  }) =>
      runtime.sessionSetupGate.run(
        () => _prepareSessionUnlocked(
          runtime,
          conversationId,
          history,
          systemContext,
          taskInstruction: taskInstruction,
        ),
      );

  Future<_PreparedSession> _prepareSessionUnlocked(
    _ModelRuntime runtime,
    String conversationId,
    List<LocalChatTurn> history,
    String systemContext, {
    String taskInstruction = '',
  }) async {
    final configuration = sessionConfigurationHash(
      stableHash: _prefixCacheKey(runtime).stableHash,
      systemContext: systemContext,
      taskInstruction: taskInstruction,
    );
    final existing = runtime.sessions[conversationId];
    final historyMatches = existing != null &&
        existing.messageCount == history.length &&
        existing.promptConfigurationHash == configuration;
    if (historyMatches) {
      existing.lastUsed = ++runtime.useSequence;
      return (
        entry: existing,
        cacheHit: true,
        prefix: PrefixStateReport(
          cacheHit: existing.basePrefixReady,
          tokens: 0,
          fileBytes: 0,
        ),
      );
    }
    if (existing != null) {
      runtime.sessions.remove(conversationId);
      await existing.session.dispose();
    }

    final limit = _plan?.sessionCacheEntries ?? 1;
    var sequenceId = 0;
    if (runtime.sessions.length >= limit) {
      final oldest = runtime.sessions.values.reduce(
        (a, b) => a.lastUsed <= b.lastUsed ? a : b,
      );
      sequenceId = oldest.sequenceId;
      runtime.sessions.remove(oldest.conversationId);
      await oldest.session.dispose();
    } else {
      final used =
          runtime.sessions.values.map((entry) => entry.sequenceId).toSet();
      while (used.contains(sequenceId)) {
        sequenceId++;
      }
    }
    final session = await runtime.engine.createSession(
      seqId: sequenceId,
      lookaheadWindow: _plan?.lookaheadWindow ?? 4,
    );
    final prefix = await _restoreOrPrepareBasePrefix(
      runtime,
      session,
      _prefixCacheKey(runtime),
    );
    final entry = _ConversationSession(
      session: session,
      sequenceId: sequenceId,
      conversationId: conversationId,
      promptConfigurationHash: configuration,
      messageCount: history.length,
      lastUsed: ++runtime.useSequence,
      basePrefixReady: FinnAccelerator._persistentPrefixCacheEnabled &&
          !FinnAccelerator.debugDisablePrefixCache,
    );
    runtime.sessions[conversationId] = entry;
    return (entry: entry, cacheHit: false, prefix: prefix);
  }

  PrefixCacheCompatibilityKey _prefixCacheKey(_ModelRuntime runtime) {
    final plan = _plan;
    final architecture = sha256
        .convert(
          utf8.encode(
            '${runtime.engine.systemInfo}|threads=${plan?.threads}|'
            'batch_threads=${plan?.batchThreads}|batch=${plan?.batchSize}|'
            'ubatch=${plan?.microBatchSize}|flash=${plan?.flashAttention}|'
            'abi=${Platform.operatingSystem}-${Platform.version}',
          ),
        )
        .toString();
    final kvType = runtime.compactKv ? runtime.kvType.name : 'f16';

    return PrefixCacheCompatibilityKey(
      modelSha256: runtime.modelSha256,
      modelTier: runtime.model.tier.name,
      runtimeVersion:
          '${runtime.engine.packageVersion}:${runtime.engine.llamaCppCommit}',
      architectureIdentity: architecture,
      systemPromptVersion: FinnAccelerator.systemPromptVersion,
      chatTemplateVersion: FinnAccelerator.chatTemplateVersion,
      contextSize: runtime.contextSize,
      kvTypeK: kvType,
      kvTypeV: kvType,
      tokenizerSettings: 'add_special=true;parse_special=true',
    );
  }

  Future<Directory> _prefixCacheDirectory(
    PrefixCacheCompatibilityKey key,
  ) async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}prefix_states'
      '${Platform.pathSeparator}${key.modelSha256}',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<File> _prefixStateFile(PrefixCacheCompatibilityKey key) async {
    final directory = await _prefixCacheDirectory(key);
    return File(
      '${directory.path}${Platform.pathSeparator}${key.stableHash}.state',
    );
  }

  Future<void> _deleteIncompatiblePrefixStates(
    PrefixCacheCompatibilityKey key,
    File compatible,
  ) async {
    final directory = await _prefixCacheDirectory(key);
    await for (final entity in directory.list()) {
      if (entity is File &&
          entity.path.endsWith('.state') &&
          entity.path != compatible.path) {
        await entity.delete();
      }
      if (entity is File && entity.path.endsWith('.part')) {
        await entity.delete();
      }
    }
  }

  Future<PrefixStateReport> _restoreOrPrepareBasePrefix(
    _ModelRuntime runtime,
    EngineSession session,
    PrefixCacheCompatibilityKey key,
  ) async {
    if (!FinnAccelerator._persistentPrefixCacheEnabled ||
        FinnAccelerator.debugDisablePrefixCache) {
      return const PrefixStateReport(cacheHit: false, tokens: 0, fileBytes: 0);
    }
    final file = await _prefixStateFile(key);
    await _deleteIncompatiblePrefixStates(key, file);
    if (await file.exists()) {
      final watch = Stopwatch()..start();
      try {
        final extra = await session.loadState(file.path);
        watch.stop();
        if (extra['cache_key'] != key.stableHash) {
          throw const FormatException('prefix cache key mismatch');
        }
        return PrefixStateReport(
          cacheHit: true,
          tokens: (extra['prefix_tokens'] as num?)?.toInt() ?? 0,
          fileBytes: await file.length(),
          restoration: watch.elapsed,
        );
      } catch (_) {
        watch.stop();
        await session.clear();
        if (await file.exists()) await file.delete();
      }
    }

    final watch = Stopwatch()..start();
    await session.append(_baseSystemPrefix, addSpecial: true);
    final prefill = await session.prefill();
    final partial = File('${file.path}.part');
    if (await partial.exists()) await partial.delete();
    await session.saveState(
      partial.path,
      extra: <String, Object?>{
        ...key.toDiagnosticJson(),
        'cache_key': key.stableHash,
        'prefix_tokens': prefill.evaluatedTokens,
        'stable_shared_content_only': true,
      },
    );
    if (await file.exists()) await file.delete();
    await partial.rename(file.path);
    watch.stop();
    return PrefixStateReport(
      cacheHit: false,
      tokens: prefill.evaluatedTokens,
      fileBytes: await file.length(),
      preparation: watch.elapsed,
      promptTokensPerSecond: prefill.tokensPerSecond,
    );
  }

  Future<PrefixStateReport> _prepareBasePrefixState(_ModelRuntime runtime) {
    final running = runtime.prefixWarmup;
    if (running != null) return running;
    late final Future<PrefixStateReport> job;
    job = runtime.sessionSetupGate.run(
      () => _prepareBasePrefixStateUnlocked(runtime),
    );
    runtime.prefixWarmup = job;
    return job.whenComplete(() {
      if (identical(runtime.prefixWarmup, job)) runtime.prefixWarmup = null;
    });
  }

  Future<PrefixStateReport> _prepareBasePrefixStateUnlocked(
    _ModelRuntime runtime,
  ) async {
    if (!FinnAccelerator._persistentPrefixCacheEnabled ||
        runtime.sessions.isNotEmpty) {
      return const PrefixStateReport(cacheHit: false, tokens: 0, fileBytes: 0);
    }
    final session = await runtime.engine.createSession(seqId: 0);
    try {
      final report = await _restoreOrPrepareBasePrefix(
        runtime,
        session,
        _prefixCacheKey(runtime),
      );
      if (PerfLogSampler.sample()) {
        debugPrint(
          'FINN_PREFIX ${jsonEncode({
                'cache_hit': report.cacheHit,
                'tokens': report.tokens,
                'file_bytes': report.fileBytes,
                'preparation_ms': report.preparation.inMicroseconds / 1000,
                'restoration_ms': report.restoration.inMicroseconds / 1000,
                'prompt_tokens_per_second': report.promptTokensPerSecond,
                'runtime': runtime.engine.packageVersion,
                'llama_cpp_commit': runtime.engine.llamaCppCommit,
                'system_info': runtime.engine.systemInfo
              })}',
        );
      }
      return report;
    } finally {
      await session.dispose();
    }
  }
}
