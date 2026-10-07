part of '../finn_accelerator.dart';

/// Task-instruction prefix states kept on disk (one per intent and language
/// in use; a few MB each).
const _maxTaskPrefixStates = 12;

extension FinnAcceleratorSessions on FinnAccelerator {
  /// Whether the base prompt prefix is kept on disk between launches.
  ///
  /// Off on desktop Linux. There the model's recurrent state does not survive a
  /// round trip through the stock llama.cpp build: a turn that starts from a
  /// restored prefix stops after a token or two (an empty reply with a
  /// "Continue" button), while the same turn from a freshly computed prefix is
  /// fine. The prefix is about a hundred tokens, so computing it each time costs
  /// next to nothing; Android and OpenHarmony run a patched build and keep the
  /// cache.
  bool get _prefixCacheEnabled =>
      FinnAccelerator._persistentPrefixCacheEnabled &&
      !(_deviceProfile?.desktop ?? false);

  Future<_PreparedSession> _prepareSession(
    _ModelRuntime runtime,
    String conversationId,
    List<LocalChatTurn> history,
    String systemContext, {
    String taskInstruction = '',
    bool agent = false,
  }) =>
      runtime.sessionSetupGate.run(
        () => _prepareSessionUnlocked(
          runtime,
          conversationId,
          history,
          systemContext,
          taskInstruction: taskInstruction,
          agent: agent,
        ),
      );

  Future<_PreparedSession> _prepareSessionUnlocked(
    _ModelRuntime runtime,
    String conversationId,
    List<LocalChatTurn> history,
    String systemContext, {
    String taskInstruction = '',
    bool agent = false,
  }) async {
    final configuration = sessionConfigurationHash(
      stableHash: _prefixCacheKey(runtime).stableHash,
      systemContext: systemContext,
      mode: agent ? 'agent' : 'chat',
    );
    final existing = runtime.sessions[conversationId];
    final historyMatches = existing != null &&
        existing.messageCount == history.length &&
        existing.promptConfigurationHash == configuration &&
        // An agent rewrites its history between steps (it trims and compacts
        // it), so a matching count is not enough: the turns must be the ones
        // the session holds.
        (!agent ||
            (existing.primed &&
                AgentPrompt.continues(existing.agentHistoryKey, history)));
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
    // An agent session starts from its own system prompt, not the chat
    // persona's cached prefix.
    final prefix = agent
        ? const PrefixStateReport(cacheHit: false, tokens: 0, fileBytes: 0)
        : await _restoreOrPrepareBasePrefix(
            runtime,
            session,
            _prefixCacheKey(runtime),
            taskInstruction: taskInstruction,
          );
    final entry = _ConversationSession(
      session: session,
      sequenceId: sequenceId,
      conversationId: conversationId,
      promptConfigurationHash: configuration,
      messageCount: history.length,
      lastUsed: ++runtime.useSequence,
      basePrefixReady: !agent &&
          _prefixCacheEnabled &&
          !FinnAccelerator.debugDisablePrefixCache,
    );
    entry
      ..basePrefixTokens = prefix.tokens
      ..taskPrefixReady = entry.basePrefixReady && prefix.taskReady;
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
    final taskStates = <File>[];
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name.endsWith('.part')) {
        await entity.delete();
      } else if (name.endsWith('.state') && entity.path != compatible.path) {
        // Task states (see [_taskStateFile]) share the compatible key's name.
        if (name.startsWith('${key.stableHash}.task-')) {
          taskStates.add(entity);
        } else {
          await entity.delete();
        }
      }
    }
    // A state is a few MB; keep the most recently used few.
    if (taskStates.length <= _maxTaskPrefixStates) return;
    final stamped = [
      for (final file in taskStates) (file, await file.lastModified()),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    for (final (file, _) in stamped.skip(_maxTaskPrefixStates)) {
      await file.delete();
    }
  }

  Future<File> _taskStateFile(
    PrefixCacheCompatibilityKey key,
    String taskInstruction,
  ) async {
    final directory = await _prefixCacheDirectory(key);
    final task = sha256.convert(utf8.encode(taskInstruction.trim())).toString();
    return File(
      '${directory.path}${Platform.pathSeparator}'
      '${key.stableHash}.task-${task.substring(0, 24)}.state',
    );
  }

  /// The system block a fresh chat writes after the base prefix.
  static String _taskBlock(String taskInstruction) =>
      '<|im_start|>system\n$taskInstruction<|im_end|>\n';

  Future<void> _saveState(
    EngineSession session,
    File file,
    Map<String, Object?> extra,
  ) async {
    final partial = File('${file.path}.part');
    if (await partial.exists()) await partial.delete();
    await session.saveState(partial.path, extra: extra);
    if (await file.exists()) await file.delete();
    await partial.rename(file.path);
  }

  /// Restores the shared base prefix into [session], computing and saving it
  /// on a miss.
  ///
  /// With a [taskInstruction], the state saved and restored is the base prefix
  /// followed by that instruction's system block. A fresh chat used to read the
  /// instruction from scratch on every first turn: ~330 tokens after the
  /// cached prefix, 3.5-4 s to the first token on the 3B on a Mi 11 Lite. The
  /// instruction depends only on the intent and language, so its state is
  /// computed once and then restored like the base prefix.
  Future<PrefixStateReport> _restoreOrPrepareBasePrefix(
    _ModelRuntime runtime,
    EngineSession session,
    PrefixCacheCompatibilityKey key, {
    String taskInstruction = '',
  }) async {
    if (!_prefixCacheEnabled || FinnAccelerator.debugDisablePrefixCache) {
      return const PrefixStateReport(cacheHit: false, tokens: 0, fileBytes: 0);
    }
    final file = await _prefixStateFile(key);
    await _deleteIncompatiblePrefixStates(key, file);
    final task = taskInstruction.trim();
    if (task.isEmpty) return _restoreOrPrepareBaseOnly(session, key, file);

    final taskFile = await _taskStateFile(key, task);
    if (await taskFile.exists()) {
      final watch = Stopwatch()..start();
      try {
        final extra = await session.loadState(taskFile.path);
        watch.stop();
        if (extra['cache_key'] != key.stableHash ||
            extra['task_hash'] != taskFile.uri.pathSegments.last) {
          throw const FormatException('task prefix cache key mismatch');
        }
        // Touch it so the most recently used task states survive pruning.
        unawaited(taskFile.setLastModified(DateTime.now()).catchError((_) {}));
        return PrefixStateReport(
          cacheHit: true,
          tokens: (extra['prefix_tokens'] as num?)?.toInt() ?? 0,
          fileBytes: await taskFile.length(),
          restoration: watch.elapsed,
          taskReady: true,
        );
      } catch (_) {
        watch.stop();
        await session.clear();
        if (await taskFile.exists()) await taskFile.delete();
      }
    }

    final base = await _restoreOrPrepareBaseOnly(session, key, file);
    final watch = Stopwatch()..start();
    try {
      await session.append(_taskBlock(task), addSpecial: false);
      final prefill = await session.prefill();
      final tokens = base.tokens + prefill.evaluatedTokens;
      await _saveState(session, taskFile, <String, Object?>{
        ...key.toDiagnosticJson(),
        'cache_key': key.stableHash,
        'task_hash': taskFile.uri.pathSegments.last,
        'prefix_tokens': tokens,
        'stable_shared_content_only': true,
      });
      watch.stop();
      return PrefixStateReport(
        cacheHit: base.cacheHit,
        tokens: tokens,
        fileBytes: await taskFile.length(),
        preparation: base.preparation + watch.elapsed,
        restoration: base.restoration,
        promptTokensPerSecond: prefill.tokensPerSecond,
        taskReady: true,
      );
    } catch (error) {
      // The base prefix is intact or the session is unusable; either way the
      // turn renders the instruction itself, as it did before this cache.
      debugPrint('FINN_PREFIX task state skipped: ${error.runtimeType}');
      await session.clear();
      return _restoreOrPrepareBaseOnly(session, key, file);
    }
  }

  Future<PrefixStateReport> _restoreOrPrepareBaseOnly(
    EngineSession session,
    PrefixCacheCompatibilityKey key,
    File file,
  ) async {
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
    await _saveState(session, file, <String, Object?>{
      ...key.toDiagnosticJson(),
      'cache_key': key.stableHash,
      'prefix_tokens': prefill.evaluatedTokens,
      'stable_shared_content_only': true,
    });
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
    if (!_prefixCacheEnabled || runtime.sessions.isNotEmpty) {
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
