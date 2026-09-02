import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'backends/llama_shim.dart';
import 'prompt/prompt_formatter.dart';
import 'package:path_provider/path_provider.dart';

import 'profiler/device_profile.dart';
import 'metrics/ttft_metrics.dart';
import 'policy/residency_policy.dart';
import 'adaptive/adaptive.dart';
import 'finn_engine_types.dart';
import '../inference/prompt_intent.dart';
import '../search/search_agent.dart';
import '../search/web_search_service.dart';

export 'finn_engine_types.dart';

/// Per-generation RNG used to pick a fresh llama.cpp sampler seed.
///
/// llama.cpp resolves its sentinel default seed (`LLAMA_DEFAULT_SEED`) once
/// per process, so relying on it makes every generation deterministic — the
/// same prompt then produces byte-identical output every time (e.g. the same
/// joke repeating in chat). Passing an explicit random seed per generation
/// restores the intended runtime-chosen variation.
final math.Random _generationSeedRng = math.Random();

int _nextGenerationSeed() => _generationSeedRng.nextInt(1 << 32);

class _ModelRuntime {
  _ModelRuntime(
    this.model,
    this.engine, {
    required this.compactKv,
    required this.contextSize,
    required this.modelSha256,
    this.kvType = KvCacheType.iq4_nl,
  });

  final FinnModelSpec model;
  final LlamaEngine engine;
  final bool compactKv;
  final int contextSize;
  final String modelSha256;
  final KvCacheType kvType;
  final Map<String, _ConversationSession> sessions = {};
  final SerializedAsyncGate sessionSetupGate = SerializedAsyncGate();
  Future<PrefixStateReport>? prefixWarmup;
  int useSequence = 0;
}

typedef _PreparedSession = ({
  _ConversationSession entry,
  bool cacheHit,
  PrefixStateReport prefix,
});

class _ConversationSession {
  _ConversationSession({
    required this.session,
    required this.sequenceId,
    required this.conversationId,
    required this.promptConfigurationHash,
    required this.messageCount,
    required this.lastUsed,
    required this.basePrefixReady,
  });

  final EngineSession session;
  final int sequenceId;
  final String conversationId;
  String promptConfigurationHash;
  int messageCount;
  bool primed = false;
  bool basePrefixReady;
  String? lastTaskInstruction;
  int lastUsed;
}

class _GenerationCancelled implements Exception {
  const _GenerationCancelled();
}

/// Owns model installation, memory lifecycle, and native llama.cpp acceleration.
///
/// The runtime lives on a dedicated worker isolate, models are mmap-backed, and all
/// settings retain CPU/GPU/NPU paths via the FinnAI-Accelerator architecture.
class FinnAccelerator extends ChangeNotifier {
  static const _backgroundDownloadChannel = MethodChannel(
    'finn_ai/model_download',
  );

  FinnAccelerator._({SearchAgent? searchAgent})
      : _searchAgent = searchAgent ?? SearchAgent();

  static final FinnAccelerator instance = FinnAccelerator._();

  /// Model-driven web search orchestration. Injected for tests.
  final SearchAgent _searchAgent;

  /// True when a web-search decision pass ran for the current/last turn and
  /// reached the search step. Used by the controller/UI to show status.
  bool searchRanForCurrentTurn = false;

  /// True when the last turn's web search was requested by the model but no
  /// results could be retrieved (offline/unavailable). The answer then used
  /// the knowledge fallback.
  bool _lastSearchFailed = false;
  bool get lastSearchFailed => _lastSearchFailed;

  /// Sources attached to the last completed answer (from web search), or
  /// empty when the answer did not use the web.
  List<WebSource> _lastSources = const [];
  List<WebSource> get lastSources => _lastSources;

  static const continuationPrompt =
      'Continue exactly where the previous response stopped. Do not repeat '
      'the introduction or completed sections. Finish the requested answer '
      'in the same language and format.';
  static const systemPromptVersion = 11;
  static const chatTemplateVersion = 2;
  static const _persistentPrefixCacheEnabled = bool.fromEnvironment(
    'FINN_PREFIX_CACHE',
    defaultValue: true,
  );

  /// Benchmark harness flag: allows the device harness to disable
  /// prefix-state restore at runtime so the cached-KV path can be compared
  /// against a fresh prefill on the same build. No effect in normal release.
  static bool debugDisablePrefixCache = false;

  /// Benchmark harness flag: forces the CPU engine. Skips accelerator
  /// discovery benchmarks and the post-spawn upgrade. Used by the harness
  /// because some vendor GPU drivers silently corrupt quantized matmuls
  /// (Adreno + Q5_K), which no benchmark would catch.
  static bool debugForceCpu = false;

  /// Benchmark-harness only: the candidate model has no stored digest, so
  /// hashing the 1.3 GB file adds tens of seconds to every TTFT measurement
  /// while contributing nothing (production models carry their digest from
  /// the download verification). When set, a stable placeholder is used.
  static bool debugSkipSha256 = false;
  static const _retiredModelFiles = <String>{
    'Bonsai-1.7B-Q1_0.gguf',
    'Bonsai-4B-Q1_0.gguf',
    'Bonsai-8B-Q1_0.gguf',
    'Qwen3-0.6B-Q4_K_M.gguf',
    'Qwen3-1.7B-Q4_K_M.gguf',
    'Qwen3.5-0.8B-Q4_K_M.gguf',
    'Qwen3.5-0.8B-Q6_K.gguf',
  };
  static const _retiredPrefixHashes = <String>{
    '3d7c6c90dd98717a203adb22d5eacd2581850e40aa5327e144b97766cae5f7e3',
    '4524b3f997f0f06444e568d1f26e2efd69effa3218c7ad3047432fb171e42168',
    '284a335aa3fb2ced3b1b01fcb40b08aa783e3b70832767f0dd2e3fdfa134bd54',
  };

  FinnModelSpec _selected = finnModels.single;
  FinnModelSpec get selected => _selected;
  List<FinnModelSpec> get requiredModels => finnModels;

  /// Last known llama.cpp commit, surfaced by the adaptive engine so its
  /// profile cache key invalidates when the native build changes.
  String? _lastKnownLlamaCppCommit;

  DeviceProfile? _deviceProfile;
  DeviceProfile? get deviceProfile => _deviceProfile;
  InferencePlan? _plan;
  InferencePlan? get plan => _plan;
  bool _automaticSelection = true;
  bool get automaticSelection => _automaticSelection;
  bool get isDeviceSupported => _deviceProfile?.supported ?? true;

  /// Short-lived cache for the Android per-turn profile refresh. Re-querying
  /// the platform channel and /proc/meminfo on every turn cost measurable
  /// latency per message while the values only matter when they change
  /// materially. The cache is invalidated when the app releases memory
  /// (backgrounded) so the first turn after a resume re-reads fresh values.
  static const _deviceProfileCacheTtl = Duration(seconds: 30);
  DeviceProfile? _deviceProfileCache;
  DateTime? _deviceProfileCacheAt;

  /// Returns a cached [DeviceProfile] when fresh, otherwise re-reads it and
  /// refreshes the cache. Mirrors the profile into [_deviceProfile] so
  /// diagnostics and planning stay on the latest observed state.
  Future<DeviceProfile> _profileForTurn() async {
    final cached = _deviceProfileCache;
    final cachedAt = _deviceProfileCacheAt;
    final now = DateTime.now();
    if (cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < _deviceProfileCacheTtl) {
      return cached;
    }
    final profile = await DeviceProfiler.read();
    _deviceProfile = profile;
    _deviceProfileCache = profile;
    _deviceProfileCacheAt = now;
    return profile;
  }

  void _invalidateDeviceProfileCache() {
    _deviceProfileCache = null;
    _deviceProfileCacheAt = null;
  }

  InferencePhase _phase = InferencePhase.idle;
  InferencePhase get phase => _phase;

  String _status = 'Ready';
  String get status => _status;

  /// Machine-readable counterpart of [status] for the UI layer. Carried by
  /// every [_setStatus] call so localized labels can be derived without
  /// parsing the display text (which stays unchanged for now).
  FinnStatusKey _statusKey = FinnStatusKey.ready;
  FinnStatusKey get statusKey => _statusKey;

  double? _downloadProgress;
  double? get downloadProgress => _downloadProgress;

  int _downloadTotalBytes = 0;
  double _downloadReceivedBytes = 0;
  int _downloadRemainingBytes = 0;
  DateTime? _downloadSampleAt;
  double _downloadSpeedBps = 0;

  /// Expected bytes of the complete install run (language model + the
  /// post-model multimodal component), or 0 when no install is active. The
  /// two artifacts download sequentially, so the install card can show one
  /// honest total and one progress bar instead of jumping back to ~0% (or
  /// appearing finished) when the second artifact starts.
  int _installTotalBytes = 0;

  /// Bytes of artifacts that finished downloading in the current install run.
  int _installCompletedBytes = 0;

  int get downloadTotalBytes => _downloadTotalBytes;
  int get downloadReceivedBytes => _downloadReceivedBytes.round();

  /// Aggregate progress (0..1) across every artifact of the current install
  /// run; null when no install is running.
  double? get installProgress {
    if (_installTotalBytes <= 0) return null;
    return ((_installCompletedBytes + _downloadReceivedBytes).clamp(
          0,
          _installTotalBytes,
        ) /
        _installTotalBytes);
  }

  /// Bytes fully downloaded so far in the current install run.
  int get installReceivedBytes =>
      _installCompletedBytes + _downloadReceivedBytes.round();

  /// Bytes still to download in the current install run.
  int get installRemainingBytes =>
      math.max(0, _installTotalBytes - installReceivedBytes);

  /// Bytes-per-second for the active download; 0 when idle. On Android this is
  /// the foreground service's own estimate, so it matches the notification.
  double get downloadSpeedBps =>
      _phase == InferencePhase.downloading ? _downloadSpeedBps : 0;

  /// Rough time remaining for the active download; null when unknown or idle.
  Duration? get downloadEta {
    if (_phase != InferencePhase.downloading ||
        _downloadSpeedBps <= 0 ||
        _downloadTotalBytes <= 0) {
      return null;
    }
    final remaining = _downloadRemainingBytes > 0
        ? _downloadRemainingBytes
        : _downloadTotalBytes - _downloadReceivedBytes;
    if (remaining <= 0) return Duration.zero;
    return Duration(seconds: (remaining / _downloadSpeedBps).floor());
  }

  /// Human-readable transfer speed for the active download; null when the
  /// estimate is not ready yet. Shared by the install card and settings card.
  String? get downloadSpeedLabel {
    final bps = downloadSpeedBps;
    if (bps <= 0) return null;
    if (bps >= 1024 * 1024) {
      return '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(bps / 1024).toStringAsFixed(0)} KB/s';
  }

  /// Human-readable time remaining for the active download; null when the
  /// estimate is not ready yet.
  String? get downloadEtaLabel {
    final eta = downloadEta;
    if (eta == null) return null;
    if (eta.inHours > 0) {
      return '${eta.inHours}h ${eta.inMinutes % 60}m left';
    }
    if (eta.inMinutes > 0) {
      return '${eta.inMinutes}m ${eta.inSeconds % 60}s left';
    }
    return '${eta.inSeconds}s left';
  }

  /// Test hook: simulates a download progress tick so the speed/ETA math can
  /// be verified without a real network transfer.
  @visibleForTesting
  void reportDownloadProgressForTest(double progress, int totalBytes) {
    _setStatus(
      InferencePhase.downloading,
      'Downloading test',
      key: FinnStatusKey.downloadingModel,
      progress: progress,
      totalBytes: totalBytes,
    );
  }

  /// Test hook: returns the download phase to idle after simulated progress.
  @visibleForTesting
  void resetDownloadStateForTest() {
    _setStatus(
      InferencePhase.idle,
      'Ready',
      key: FinnStatusKey.ready,
    );
  }

  FinnModelSpec? _workingModel;
  FinnModelSpec? get workingModel => _workingModel;

  final Map<FinnModelTier, _ModelRuntime> _runtimes = {};
  final Map<FinnModelTier, Future<_ModelRuntime>> _loadJobs = {};
  final DeduplicatedLoadJob<FinnModelTier, _ModelRuntime> _deduplicatedLoads =
      DeduplicatedLoadJob<FinnModelTier, _ModelRuntime>();
  StreamSubscription<GenerationEvent>? _generation;
  StreamController<String>? _activeOutput;
  int _generationEpoch = 0;
  Future<void> _pendingUnload = Future<void>.value();
  var _runtimeEpoch = 0;
  bool _replyInFlight = false;
  bool get isGeneratingReply => _replyInFlight;

  /// FIFO gate for queued generations (see [generateReplyQueued]).
  @visibleForTesting
  final ReplyTurnGate replyGate = ReplyTurnGate(
    capacity: maxQueuedReplyRequests,
  );
  static const int maxQueuedReplyRequests = 2;
  Future<void>? _installJob;
  HttpClient? _downloadClient;
  bool _cancelDownload = false;
  bool _benchmarkRunning = false;
  final Set<FinnModelTier> _verifiedModels = <FinnModelTier>{};
  Future<Directory>? _modelDirectoryJob;

  Future<void> initialize() async {
    _deviceProfile = await DeviceProfiler.read();
    _deviceProfileCache = _deviceProfile;
    _deviceProfileCacheAt = DateTime.now();
    _plan = DeviceProfiler.plan(_deviceProfile!);
    // Clean up any retired legacy artifacts in background without blocking startup
    unawaited(_removeRetiredModelArtifacts());
    _selected = finnModels.single;
    _automaticSelection = true;
  }

  void select(FinnModelTier tier) {
    if (tier != FinnModelTier.standard || !_automaticSelection) return;
    _automaticSelection = false;
    _setStatus(
      InferencePhase.idle,
      'Ready',
      key: FinnStatusKey.ready,
    );
  }

  void useAutomaticSelection() {
    _automaticSelection = true;
    _setStatus(
      InferencePhase.idle,
      'Optimized automatically',
      key: FinnStatusKey.optimizedAutomatically,
    );
  }

  Future<bool> isInstalled(FinnModelSpec model) async {
    if (_verifiedModels.contains(model.tier)) return true;
    final file = await _modelFile(model);
    final installed = await _isVerifiedModelFile(model, file);
    if (installed) _verifiedModels.add(model.tier);
    return installed;
  }

  Future<List<ModelStorageState>> inspectModels() async {
    final states = <ModelStorageState>[];
    for (final model in finnModels) {
      final file = await _modelFile(model);
      final partial = File('${file.path}.part');
      final installed = await isInstalled(model);
      states.add(
        ModelStorageState(
          model: model,
          installedBytes: installed ? await file.length() : 0,
          partialBytes: await partial.exists() ? await partial.length() : 0,
        ),
      );
    }
    return states;
  }

  Future<FinnModelTier> recommendedTier() async {
    return FinnModelTier.standard;
  }

  Future<void> install(FinnModelSpec model) {
    // A model can be verified from a previous app run while the post-model
    // component is still missing. Re-entering install must finish that second
    // artifact instead of treating the whole install as complete.
    if (_verifiedModels.contains(model.tier)) return _preinstallMmproj();
    final running = _installJob;
    if (running != null) {
      if (_workingModel == model) return running;
      return Future<void>.error(
        StateError('Another model download is already in progress.'),
      );
    }
    _workingModel = model;
    _cancelDownload = false;
    final job = _runInstall(model);
    _installJob = job;
    notifyListeners();
    return job;
  }

  Future<void> installRequiredModels() async {
    for (final model in requiredModels) {
      if (!await isInstalled(model)) await install(model);
    }
    // The projector is a separate artifact by design. It is downloaded only
    // after the language model has been verified, but it is not loaded or
    // exposed as an input capability in this release.
    await _preinstallMmproj();
  }

  /// Resumes a partially-downloaded required model after an app restart,
  /// without waiting for the user to reach the install screen again. Only a
  /// model that already has bytes on disk is resumed, so a fresh install never
  /// starts a surprise download. install() is idempotent, so this also no-ops
  /// if the same model is already being installed by the onboarding flow.
  Future<void> resumeInterruptedDownloads() async {
    for (final model in requiredModels) {
      final target = await _modelFile(model);
      // Avoid the full SHA-256 verification here; a right-sized target is
      // treated as installed and re-verified lazily when the engine loads it.
      if (await target.exists() &&
          await target.length() == model.expectedBytes) {
        continue;
      }
      final partial = File('${target.path}.part');
      if (!await partial.exists() || await partial.length() <= 0) continue;
      unawaited(
        install(model).catchError((Object _) {
          // _runInstall already surfaced the failure through the status
          // listener; this only prevents an unhandled async error at startup.
        }),
      );
    }
  }

  Future<void> _preinstallMmproj() async {
    if (await isMmprojInstalled()) return;
    // Standalone projector install (the language model was already verified):
    // size the aggregate progress to this artifact alone. When called from
    // _runInstall the total was already set to model + component, so this
    // guard leaves it untouched.
    var trackedStandalone = false;
    if (_installTotalBytes <= 0) {
      _installTotalBytes = finnMmproj.expectedBytes;
      _installCompletedBytes = 0;
      trackedStandalone = true;
    }
    try {
      await installMmproj();
    } catch (error, stack) {
      // Text chat remains usable if the future-vision artifact is unavailable.
      debugPrint('FINN_MMPROJ download skipped: $error\n$stack');
      if (_phase == InferencePhase.downloading ||
          _phase == InferencePhase.loading) {
        _setStatus(
          InferencePhase.idle,
          'AI model is ready',
          key: FinnStatusKey.modelReady,
        );
      }
    } finally {
      if (trackedStandalone) {
        _installTotalBytes = 0;
        _installCompletedBytes = 0;
      }
    }
  }

  Future<void> _runInstall(FinnModelSpec model) async {
    try {
      // Size the aggregate progress across every artifact this install must
      // fetch: the language model (unless already verified) plus the
      // post-model multimodal component (unless already present).
      final modelAlreadyInstalled = await isInstalled(model);
      final componentAlreadyInstalled = await isMmprojInstalled();
      _installTotalBytes = (modelAlreadyInstalled ? 0 : model.expectedBytes) +
          (componentAlreadyInstalled ? 0 : finnMmproj.expectedBytes);
      _installCompletedBytes = 0;
      await _ensureDownloaded(model);
      _verifiedModels.add(model.tier);
      // Keep the projector out of the runtime for now, but install it as the
      // second verified artifact so a future vision release does not need to
      // redownload the model package.
      await _preinstallMmproj();
      _setStatus(
        InferencePhase.idle,
        'AI model is ready',
        key: FinnStatusKey.modelReady,
      );
    } catch (error) {
      if (_cancelDownload) {
        _setStatus(
          InferencePhase.idle,
          'Download paused',
          key: FinnStatusKey.downloadPaused,
        );
        return;
      }
      _setStatus(
        InferencePhase.error,
        _friendlyError(error),
        key: FinnStatusKey.error,
      );
      rethrow;
    } finally {
      _workingModel = null;
      _installJob = null;
      _downloadClient = null;
      _cancelDownload = false;
      _installTotalBytes = 0;
      _installCompletedBytes = 0;
    }
  }

  /// Records a fully-downloaded artifact in the aggregate install progress so
  /// the next artifact's bytes count on top of it instead of restarting the
  /// bar at zero.
  void _completeInstallArtifact(int expectedBytes) {
    _installCompletedBytes += expectedBytes;
    _downloadReceivedBytes = 0;
  }

  void pauseDownload() {
    if (_workingModel == null || _phase != InferencePhase.downloading) return;
    _cancelDownload = true;
    _downloadClient?.close(force: true);
    if (Platform.isAndroid) {
      final model = _workingModel;
      if (model != null) {
        unawaited(
          _modelFile(model).then((file) => _cancelAndroidDownload(file.path)),
        );
      }
    }
  }

  Future<void> _cancelAndroidDownload(String targetPath) async {
    try {
      await _backgroundDownloadChannel.invokeMethod<void>('cancel', {
        'target': targetPath,
      });
    } on PlatformException {
      // The foreground download is opportunistic on unsupported platform
      // versions; Dart-side cancellation still stops its own HTTP client.
    } on MissingPluginException {
      // Background channel absent on non-Android hosts; nothing to cancel.
    }
  }

  /// Maps the recommended/default model. Direct Plus requests therefore reuse
  /// this exact load instead of first paying for an unrelated Lite engine.
  Future<void> prewarm() async {
    final profile = (Platform.isAndroid || Platform.isLinux)
        ? await DeviceProfiler.read()
        : _deviceProfile;
    if (profile != null) {
      _deviceProfile = profile;
      if (_runtimes.isEmpty) _plan = DeviceProfiler.plan(profile);
    }
    // The selected automatic tier is the product's recommended/default model.
    // Loading Lite first made every direct Plus request pay two cold loads.
    final model = _selected;
    if (!await isInstalled(model)) return;
    final file = await _modelFile(model);
    try {
      final runtime = await _ensureLoaded(model, file.path);
      await _prepareBasePrefixState(runtime);
      _setStatus(
        InferencePhase.idle,
        'Ready',
        key: FinnStatusKey.ready,
      );
    } catch (error, stack) {
      // Prewarm is opportunistic. A background failure must not become the
      // visible result of the user's next request; foreground generation can
      // retry through its normal error handling.
      debugPrint('FINN_PREWARM failed: $error\n$stack');
      _setStatus(
        InferencePhase.idle,
        'Ready',
        key: FinnStatusKey.ready,
      );
    }
  }

  Future<void> prewarmTier(FinnModelTier tier) async {
    final model = finnModels.firstWhere((candidate) => candidate.tier == tier);
    if (!await isInstalled(model)) return;
    final file = await _modelFile(model);
    final runtime = await _ensureLoaded(model, file.path);
    await _prepareBasePrefixState(runtime);
    _setStatus(
      InferencePhase.idle,
      'Ready',
      key: FinnStatusKey.ready,
    );
  }

  Future<void> releaseConversationSessions() async {
    for (final runtime in _runtimes.values) {
      final sessions = runtime.sessions.values.toList(growable: false);
      runtime.sessions.clear();
      for (final entry in sessions) {
        await entry.session.dispose();
      }
    }
  }

  /// Releases the large native context when the app leaves the foreground.
  /// Also drops the cached device profile: after a resume the first turn
  /// must observe fresh memory/storage values.
  Future<void> releaseMemory() {
    _invalidateDeviceProfileCache();
    _queueUnload();
    return _pendingUnload;
  }

  /// Memory-pressure order: inactive sessions, active sessions, secondary
  /// engines, and finally the selected/default engine.
  Future<void> handleMemoryPressure() async {
    for (final runtime in _runtimes.values) {
      if (runtime.sessions.length <= 1) continue;
      final newest = runtime.sessions.values.reduce(
        (a, b) => a.lastUsed >= b.lastUsed ? a : b,
      );
      final inactive = runtime.sessions.values
          .where((entry) => !identical(entry, newest))
          .toList(growable: false);
      for (final entry in inactive) {
        runtime.sessions.remove(entry.conversationId);
        await entry.session.dispose();
      }
    }
    for (final runtime in _runtimes.values) {
      final active = runtime.sessions.values.toList(growable: false);
      runtime.sessions.clear();
      for (final entry in active) {
        await entry.session.dispose();
      }
    }
    for (final tier in _runtimes.keys.toList(growable: false)) {
      if (tier != _selected.tier) await _unloadModel(tier);
    }
    // Memory pressure is exactly when a stale profile would mislead the
    // low-RAM decisions below, so force a fresh read and re-prime the cache.
    _invalidateDeviceProfileCache();
    final profile = await _profileForTurn();
    final tightRam = profile.availableRamBytes != null &&
        profile.availableRamBytes! < 1200 * 1024 * 1024;
    if (profile.lowMemory || tightRam) await _unloadModel(_selected.tier);
  }

  ModelResidencyLevel residencyFor(FinnModelTier tier) {
    final runtime = _runtimes[tier];
    if (runtime == null) return ModelResidencyLevel.unloaded;
    if (runtime.sessions.values.any((entry) => entry.primed)) {
      return ModelResidencyLevel.conversationWarm;
    }
    return ModelResidencyLevel.engineReady;
  }

  @visibleForTesting
  bool get hasDuplicateLoadJobs => _deduplicatedLoads.activeJobCount > 1;

  Future<Set<String>> remove(FinnModelSpec model) async {
    final failures = <String>{};
    await _unloadModel(model.tier);
    try {
      final file = await _modelFile(model);
      if (await file.exists()) await file.delete();
    } catch (e) {
      if (!e.toString().contains('MissingPluginException')) {
        debugPrint('Model file removal error: $e');
        failures.add('Downloaded model (${model.name})');
      }
    }
    try {
      final file = await _modelFile(model);
      final partial = File('${file.path}.part');
      if (await partial.exists()) await partial.delete();
    } catch (e) {
      if (!e.toString().contains('MissingPluginException')) {
        debugPrint('Partial file removal error: $e');
        failures.add('Partial download (${model.name})');
      }
    }
    try {
      await _removePrefixStatesFor(model.sha256Digest);
    } catch (error) {
      if (!error.toString().contains('MissingPluginException')) {
        debugPrint('Prefix cache removal error: $error');
        failures.add('Model prefix cache (${model.name})');
      }
    }
    _verifiedModels.remove(model.tier);
    _setStatus(
      InferencePhase.idle,
      'Model removed',
      key: FinnStatusKey.modelRemoved,
    );
    return failures;
  }

  Future<Set<String>> removeAllModels() async {
    final failures = <String>{};
    for (final model in finnModels) {
      final res = await remove(model);
      failures.addAll(res);
    }
    failures.addAll(await removeMmproj());
    return failures;
  }

  /// Removes the downloaded projector separately from the language model.
  /// Vision is not exposed by this release, but data deletion must still
  /// remove the reserved artifact if it was installed.
  Future<Set<String>> removeMmproj() async {
    final failures = <String>{};
    try {
      final file = await _mmprojFile();
      for (final suffix in const ['', '.part']) {
        final candidate = File('${file.path}$suffix');
        if (await candidate.exists()) await candidate.delete();
      }
    } catch (error) {
      if (!error.toString().contains('MissingPluginException')) {
        debugPrint('Projector file removal error: $error');
        failures.add('Post-model component');
      }
    }
    _setStatus(
      InferencePhase.idle,
      'Model removed',
      key: FinnStatusKey.modelRemoved,
    );
    return failures;
  }

  FinnModelSpec? _lastGeneratingModel;
  FinnModelSpec get lastGeneratingModel => _lastGeneratingModel ?? selected;
  GenerationReport? _lastGenerationReport;
  GenerationReport? get lastGenerationReport => _lastGenerationReport;

  Stream<String> generateReply(
    String prompt, {
    required String conversationId,
    List<LocalChatTurn> history = const [],
    String systemContext = '',
    String groundedContext = '',
    PromptAnalysis? promptAnalysis,
    TtftTrace? trace,
    bool enableSearchDecision = true,
  }) async* {
    if (_replyInFlight) {
      throw StateError('Finn is already generating a response.');
    }
    _replyInFlight = true;
    _lastSources = const [];
    _lastSearchFailed = false;
    searchRanForCurrentTurn = false;
    try {
      yield* _generateReplyUnlocked(
        prompt,
        conversationId: conversationId,
        history: history,
        systemContext: systemContext,
        groundedContext: groundedContext,
        promptAnalysis: promptAnalysis,
        trace: trace,
        enableSearchDecision: enableSearchDecision,
      );
    } finally {
      _replyInFlight = false;
      // Hand the engine to the oldest queued caller (no-op when none waits).
      replyGate.signalNext();
    }
  }

  /// Like [generateReply], but waits for the engine to become available
  /// instead of throwing when a generation is already in flight.
  ///
  /// Secondary callers (e.g. the creation generator) queue here so a user
  /// creation no longer fails with "Finn is already generating" just because
  /// a chat answer is streaming. Waiting is FIFO and bounded: at most
  /// [maxQueuedReplyRequests] callers may hold a reservation; beyond that the
  /// call throws [StateError] with an actionable message instead of growing
  /// without bound. When the engine is idle this behaves exactly like
  /// [generateReply] and never reserves a slot.
  Stream<String> generateReplyQueued(
    String prompt, {
    required String conversationId,
    List<LocalChatTurn> history = const [],
    String systemContext = '',
    String groundedContext = '',
    PromptAnalysis? promptAnalysis,
    TtftTrace? trace,
    bool enableSearchDecision = true,
  }) async* {
    if (_replyInFlight) {
      final turn = replyGate.waitTurn();
      try {
        await turn;
      } finally {
        // If this stream was cancelled while waiting, give the reservation
        // back so capacity is not consumed by a dead waiter. A no-op when
        // the turn was already granted.
        replyGate.abandon(turn);
      }
    }
    yield* generateReply(
      prompt,
      conversationId: conversationId,
      history: history,
      systemContext: systemContext,
      groundedContext: groundedContext,
      promptAnalysis: promptAnalysis,
      trace: trace,
      enableSearchDecision: enableSearchDecision,
    );
  }

  /// Developer harness entry point for an already-installed GGUF at [path].
  ///
  /// Production chat never calls this and model downloads/defaults are not
  /// changed. The caller must release memory between different model files.
  ///
  /// Security: an evaluation candidate carries no SHA-256 digest, so nothing
  /// verifies its contents. Release builds therefore refuse to run such a
  /// model unless the benchmark harness explicitly opted out via
  /// [debugSkipSha256]; debug/profile builds only log a warning so quality
  /// sweeps can evaluate arbitrary local candidates.
  Stream<String> generateEvaluationReply(
    String prompt, {
    required String path,
    required String modelLabel,
    required FinnModelTier tier,
    required String conversationId,
    List<LocalChatTurn> history = const [],
    TtftTrace? trace,
  }) async* {
    if (_replyInFlight) {
      throw StateError('Finn is already generating a response.');
    }
    _replyInFlight = true;
    final model = FinnModelSpec(
      tier: tier,
      name: modelLabel,
      parameterLabel: modelLabel,
      fileName: path,
      downloadUrl: '',
      expectedBytes: 0,
      sha256Digest: '',
    );
    if (model.sha256Digest.isEmpty && !debugSkipSha256) {
      final message =
          'Evaluation model "$modelLabel" has no SHA-256 digest; refusing to '
          'load unverified weights.';
      if (kReleaseMode) {
        throw StateError(message);
      }
      debugPrint('FINN_EVAL_WARNING $message');
    }
    try {
      _lastGeneratingModel = model;
      yield* _cleanModelStream(
        _generateForModel(
          model,
          prompt,
          conversationId: conversationId,
          history: history,
          analysis: const PromptIntentClassifier().classify(prompt),
          modelPath: path,
          trace: trace,
          // The evaluation harness measures the raw model answer; it must not
          // trigger the model-driven web-search decision pass.
          enableSearchDecision: false,
        ),
      );
    } finally {
      _replyInFlight = false;
    }
  }

  Stream<String> _generateReplyUnlocked(
    String prompt, {
    required String conversationId,
    required List<LocalChatTurn> history,
    required String systemContext,
    String groundedContext = '',
    PromptAnalysis? promptAnalysis,
    TtftTrace? trace,
    bool enableSearchDecision = true,
  }) async* {
    final analysis =
        promptAnalysis ?? const PromptIntentClassifier().classify(prompt);
    trace?.mark(TtftPhase.intentClassified);
    trace
      ?..modelTier = selected.name
      ..mark(TtftPhase.routeSelected);
    if (Platform.isAndroid) {
      // Cached per-turn refresh: avoids a platform-channel round trip plus
      // /proc/meminfo reads on every message (see _profileForTurn).
      final freshProfile = await _profileForTurn();
      if (_runtimes.isEmpty) _plan = DeviceProfiler.plan(freshProfile);
    }
    final model = selected;
    _lastGeneratingModel = model;
    yield* _cleanModelStream(
      _generateForModel(
        model,
        prompt,
        conversationId: conversationId,
        history: history,
        systemContext: systemContext,
        groundedContext: groundedContext,
        analysis: analysis,
        trace: trace,
        enableSearchDecision: enableSearchDecision,
      ),
      trace: trace,
    );
  }

  Stream<String> _cleanModelStream(
    Stream<String> source, {
    TtftTrace? trace,
  }) async* {
    final prefix = StringBuffer();
    var decided = false;
    var hidingThought = false;
    await for (final token in source) {
      if (decided) {
        final sanitized = _stripToolTags(token);
        if (sanitized.isNotEmpty) {
          trace?.mark(TtftPhase.sanitizedToken);
          yield sanitized;
        }
        continue;
      }
      prefix.write(token);
      final buffered = prefix.toString();
      final trimmed = buffered.trimLeft();
      if (!hidingThought) {
        if ('<think>'.startsWith(trimmed)) continue;
        if (trimmed.startsWith('<think>')) {
          hidingThought = true;
        } else {
          decided = true;
          final sanitized = _stripToolTags(trimmed);
          if (sanitized.isNotEmpty) {
            trace?.mark(TtftPhase.sanitizedToken);
            yield sanitized;
          }
          continue;
        }
      }
      final close = buffered.indexOf('</think>');
      if (close < 0) continue;
      final visible = buffered.substring(close + '</think>'.length).trimLeft();
      decided = true;
      final sanitized = _stripToolTags(visible);
      if (sanitized.isNotEmpty) {
        trace?.mark(TtftPhase.sanitizedToken);
        yield sanitized;
      }
    }
    // An unterminated reasoning block is intentionally not surfaced.
    if (!decided && !hidingThought && prefix.isNotEmpty) {
      final sanitized = _stripToolTags(prefix.toString());
      if (sanitized.isNotEmpty) {
        trace?.mark(TtftPhase.sanitizedToken);
        yield sanitized;
      }
    }
  }

  static String _stripToolTags(String text) => text
      .replaceAll(RegExp(r'</?tool_call>', caseSensitive: false), '')
      .replaceAll(RegExp(r'</?tool_response>', caseSensitive: false), '');

  /// Runs the model-driven tool-calling pass. The AI model itself evaluates
  /// whether to call the browser_search tool. When a tool call is emitted,
  /// the browser search is executed and returned with toolCallMade: true.
  Future<({String groundedContext, List<WebSource> sources, bool toolCallMade})>
      _runSearchDecision(
    EngineSession session,
    String prompt,
    PromptAnalysis analysis,
    int generationEpoch, {
    required List<LocalChatTurn> history,
    required bool primed,
    required bool basePrefixReady,
    required bool includeTaskInstruction,
    TtftTrace? trace,
  }) async {
    if (analysis.intent == PromptIntent.greeting) {
      return (
        groundedContext: '',
        sources: const <WebSource>[],
        toolCallMade: false,
      );
    }
    final directive = PromptIntentPolicy.searchDecisionDirectiveFor(
      analysis.language,
    );
    final decisionPrompt = _renderDecisionPromptText(
      primed: primed,
      basePrefixReady: basePrefixReady,
      includeTaskInstruction: includeTaskInstruction,
      analysis: analysis,
      prompt: prompt,
      history: history,
      directive: directive,
    );
    _setStatus(
      InferencePhase.generating,
      'Checking web...',
      key: FinnStatusKey.checkingWeb,
    );
    trace?.mark(TtftPhase.decisionPass);
    final decisionText = StringBuffer();
    await for (final event in session.generate(
      prompt: decisionPrompt,
      addSpecial: !primed && !basePrefixReady,
      parseSpecial: true,
      // Fast bounded budget to decode decision or tool call
      maxTokens: 40,
      sampler: PromptIntentPolicy.searchDecisionSampler.params.copyWith(
        seed: _nextGenerationSeed(),
      ),
    )) {
      if (generationEpoch != _generationEpoch) {
        throw const _GenerationCancelled();
      }
      if (event case TokenEvent(:final text)) {
        decisionText.write(text);
        final current = decisionText.toString();
        // Break early as soon as the decision or tool call is terminated
        if (current.contains('ANSWER') || current.contains('</tool_call>')) {
          break;
        }
      }
    }
    _throwIfGenerationCancelled(generationEpoch);
    final decision = const SearchDecisionParser().parse(
      decisionText.toString(),
    );
    if (decision.kind == SearchDecisionKind.answerFromKnowledge) {
      return (
        groundedContext: '',
        sources: const <WebSource>[],
        toolCallMade: false,
      );
    }
    final query = decision.query?.trim();
    if (query == null || query.isEmpty) {
      return (
        groundedContext: '',
        sources: const <WebSource>[],
        toolCallMade: false,
      );
    }
    searchRanForCurrentTurn = true;
    final grounded = await _searchAndFetch(query);
    _throwIfGenerationCancelled(generationEpoch);
    return (
      groundedContext: grounded.groundedContext,
      sources: grounded.sources,
      toolCallMade: true,
    );
  }

  /// Searches the browser and fetches content, returning the grounded result
  /// or the offline fallback note when retrieval fails.
  Future<({String groundedContext, List<WebSource> sources})> _searchAndFetch(
    String query, {
    bool markFailure = true,
  }) async {
    _setStatus(
      InferencePhase.generating,
      'Searching browser...',
      key: FinnStatusKey.searchingBrowser,
    );
    try {
      final grounded = await _searchAgent
          .searchAndFetch(query)
          .timeout(const Duration(milliseconds: 3000), onTimeout: () => null);
      if (grounded == null) {
        if (markFailure) _lastSearchFailed = true;
        return (
          groundedContext:
              'Note: browser search was requested for "$query" but no results were available (offline or unavailable). Answer carefully from general knowledge, state uncertainty for time-sensitive claims, and do not invent sources.',
          sources: const <WebSource>[],
        );
      }
      return (
        groundedContext: grounded.groundedContext,
        sources: grounded.search.sources,
      );
    } on _GenerationCancelled {
      rethrow;
    } on Object {
      if (markFailure) _lastSearchFailed = true;
      return (
        groundedContext:
            'Note: browser search was requested for "$query" but no results were available (offline or unavailable). Answer carefully from general knowledge, state uncertainty for time-sensitive claims, and do not invent sources.',
        sources: const <WebSource>[],
      );
    }
  }

  Stream<String> _generateForModel(
    FinnModelSpec model,
    String prompt, {
    required String conversationId,
    required List<LocalChatTurn> history,
    String systemContext = '',
    String groundedContext = '',
    PromptAnalysis? analysis,
    String? modelPath,
    TtftTrace? trace,
    bool enableSearchDecision = true,
  }) {
    late StreamController<String> output;
    var nativeFinished = false;
    output = StreamController<String>(
      onListen: () async {
        _activeOutput = output;
        final generationEpoch = _generationEpoch;
        final runWatch = Stopwatch()..start();
        Duration? firstTokenAt;
        var emittedTokens = 0;
        final promptAnalysis =
            analysis ?? const PromptIntentClassifier().classify(prompt);
        final outputBudget = _outputBudget(promptAnalysis);
        _lastGenerationReport = GenerationReport(
          model: model,
          intent: promptAnalysis.intent,
          route: model.tier,
          outputBudget: outputBudget,
          // Native completion is the default. Explicit stopGeneration()
          // changes this to userCancellation synchronously.
          finishReason: GenerationFinishReason.eos,
          firstTokenLatency: null,
          totalGenerationTime: Duration.zero,
          outputTokens: 0,
          tokensPerSecond: 0,
        );
        try {
          if (modelPath == null && !await isInstalled(model)) {
            await install(model);
          }
          _throwIfGenerationCancelled(generationEpoch);
          final path = modelPath ?? (await _modelFile(model)).path;
          final alreadyResident = _runtimes.containsKey(model.tier);
          trace
            ?..modelTier = model.tier.name
            ..modelAlreadyResident = alreadyResident
            ..mark(TtftPhase.modelLoadRequested);
          final runtime = await _ensureLoaded(model, path);
          trace?.mark(TtftPhase.modelReady);
          _throwIfGenerationCancelled(generationEpoch);
          final combinedContext = [
            systemContext,
            groundedContext,
          ].where((s) => s.trim().isNotEmpty).join('\n\n');
          final prepared = await _prepareSession(
            runtime,
            conversationId,
            history,
            combinedContext,
          );
          trace
            ?..conversationSessionCacheHit = prepared.cacheHit
            ..basePrefixCacheHit = prepared.prefix.cacheHit
            ..prefixStateTokens = prepared.prefix.tokens
            ..prefixStateBytes = prepared.prefix.fileBytes
            ..prefixStatePreparationMicros =
                prepared.prefix.preparation.inMicroseconds
            ..prefixStateRestorationMicros =
                prepared.prefix.restoration.inMicroseconds
            ..prefixPromptTokensPerSecond =
                prepared.prefix.promptTokensPerSecond
            ..mark(TtftPhase.sessionReady);
          _throwIfGenerationCancelled(generationEpoch);
          final entry = prepared.entry;
          final session = entry.session;
          // Collect ALL image attachments in history window + prefer in-memory bytes.
          final allImageTurns = history
              .where((t) =>
                  (t.imagePath != null && t.imagePath!.isNotEmpty) ||
                  t.imageBytes != null)
              .toList(growable: false);
          final candidatePaths = <String>[];
          final candidateBytes = <Uint8List?>[];
          for (final turn in allImageTurns) {
            if (turn.imageBytes != null) {
              candidatePaths.add(turn.imagePath ?? 'memory');
              candidateBytes.add(turn.imageBytes);
            } else if (turn.imagePath != null) {
              candidatePaths.add(turn.imagePath!);
              candidateBytes.add(null);
            }
          }

          final mediaList = <LlamaMedia>[];
          final skippedHeicPaths = <String>[];
          final validImageIndices = <int>[];
          for (var i = 0; i < candidatePaths.length; i++) {
            final path = candidatePaths[i];
            final bytes = candidateBytes[i];
            if (bytes != null) {
              final isHeic = _isHeicPath(path);
              if (isHeic) {
                skippedHeicPaths.add(path);
                debugPrint('FINN_HEIC skipped in-memory HEIC for $path');
                continue;
              }
              try {
                mediaList.add(LlamaMedia.imageBytes(bytes));
                validImageIndices.add(i);
              } catch (e) {
                debugPrint('FINN_MEDIA imageBytes failed for $path: $e');
              }
            } else {
              final isHeic = _isHeicPath(path);
              final isImageExt = _isImageFile(path);
              if (!isImageExt && !isHeic) continue;
              try {
                final exists = await File(path).exists();
                if (!exists) continue;
                final fileBytes = await File(path).readAsBytes();
                // stb_image cannot decode HEIC; treat as skipped, not crash
                if (isHeic && !_bytesLookLikeImage(fileBytes, path)) {
                  skippedHeicPaths.add(path);
                  debugPrint(
                      'FINN_HEIC skipped HEIC at $path (stb_image unsupported)');
                  continue;
                }
                if (!_bytesLookLikeImage(fileBytes, path) && isHeic) {
                  skippedHeicPaths.add(path);
                  continue;
                }
                mediaList.add(LlamaMedia.imageBytes(fileBytes));
                validImageIndices.add(i);
              } catch (e) {
                if (isHeic) {
                  skippedHeicPaths.add(path);
                  debugPrint('FINN_HEIC failed for $path: $e');
                } else {
                  debugPrint('FINN_MEDIA load failed for $path: $e');
                }
              }
            }
          }

          final hasAttachedImage = mediaList.isNotEmpty;
          final useMediaMarker =
              hasAttachedImage && runtime.engine.multimodalLoaded;
          // Cap at reasonable N for prompt token budget; native supports N
          final cappedMediaList =
              mediaList.length > 4 ? mediaList.sublist(0, 4) : mediaList;
          final effectiveMediaList = cappedMediaList;

          String? attachedDocContext;
          // Handle single non-image doc attachment (text files)
          final docPath = history.reversed
              .where((t) => t.imagePath != null && t.imagePath!.isNotEmpty)
              .firstOrNull
              ?.imagePath;
          if (docPath != null &&
              !_isImageFile(docPath) &&
              !_isHeicPath(docPath)) {
            try {
              final exists = await File(docPath).exists();
              if (exists) {
                final content = await File(docPath).readAsString();
                final docName = docPath.split(Platform.pathSeparator).last;
                final truncated = content.length > 4000
                    ? '${content.substring(0, 4000)}\n[... content truncated]'
                    : content;
                attachedDocContext =
                    'Attached document ($docName):\n```\n$truncated\n```';
              }
            } catch (_) {}
          }
          if (skippedHeicPaths.isNotEmpty && !useMediaMarker) {
            final heicNote =
                'Note: ${skippedHeicPaths.length} HEIC image(s) could not be decoded on this device (unsupported format). Ask the user to share as JPEG/PNG.';
            final previousContext = attachedDocContext;
            attachedDocContext =
                (previousContext == null || previousContext.isEmpty)
                    ? heicNote
                    : '$previousContext\n\n$heicNote';
          }

          final taskInstruction = PromptIntentPolicy.taskInstruction(
            promptAnalysis,
          );
          final includeTaskInstruction =
              !entry.primed || entry.lastTaskInstruction != taskInstruction;
          // This runtime is intentionally single-model (LFM2.5-VL 1.6B). Its
          // non-thinking ChatML template
          // needs an empty reasoning block to avoid hidden-chain generation
          // while keeping everyday replies fast.
          const primeEmptyThinking = true;
          var renderedPrompt = _renderPrompt(
            entry,
            prompt,
            history,
            systemContext: systemContext,
            groundedContext: groundedContext,
            analysis: promptAnalysis,
            includeTaskInstruction: includeTaskInstruction,
            primeEmptyThinking: primeEmptyThinking,
            includeMediaMarker: useMediaMarker,
            mediaCount: useMediaMarker ? effectiveMediaList.length : 0,
            attachedDocContext: attachedDocContext,
          );
          // The token-breakdown re-renders the prompt a second time purely
          // for diagnostics. Skip it (and the full-prompt log) in release
          // builds: it is duplicate prefill-side work on every generation,
          // and the full prompt must never reach production logs.
          if (!kReleaseMode) {
            final promptBreakdown = promptTokenBreakdownForTest(
              prompt: prompt,
              history: history,
              systemContext: combinedContext,
              primed: entry.primed,
              basePrefixReady: entry.basePrefixReady,
              includeTaskInstruction: includeTaskInstruction,
              primeEmptyThinking: primeEmptyThinking,
            );
            debugPrint('FINN_PROMPT ${jsonEncode(promptBreakdown)}');
          }
          final profile = _deviceProfile;
          final plan = _plan;
          trace
            ?..promptTokenCount = (renderedPrompt.length / 3.2).ceil()
            ..availableRamBytes = profile?.availableRamBytes
            ..lowMemory = profile?.lowMemory ?? false
            ..threads = plan?.threads
            ..batchThreads = plan?.batchThreads
            ..batchSize = plan?.batchSize
            ..microBatchSize = plan?.microBatchSize
            ..kvType = runtime.compactKv ? runtime.kvType.name : 'f16'
            ..flashAttention = plan?.flashAttention == true ? 'on' : 'off'
            ..mark(TtftPhase.promptRendered);

          // Model-driven browser search: the AI model itself evaluates whether
          // to perform a tool call. When the model emits a tool call, we execute
          // the browser search, feed the tool response back into the session,
          // and let the model generate the grounded answer.
          // When an image is attached, skip the search pass to answer immediately from vision.
          var effectiveGroundedContext = groundedContext;
          var effectiveSources = const <WebSource>[];
          final decisionEnabled = enableSearchDecision &&
              !hasAttachedImage &&
              PromptIntentPolicy.needsSearchDecision(promptAnalysis);
          if (decisionEnabled) {
            final decision = await _runSearchDecision(
              session,
              prompt,
              promptAnalysis,
              generationEpoch,
              history: history,
              primed: entry.primed,
              basePrefixReady: entry.basePrefixReady,
              includeTaskInstruction: includeTaskInstruction,
              trace: trace,
            );
            effectiveGroundedContext = decision.groundedContext;
            effectiveSources = decision.sources;
            _throwIfGenerationCancelled(generationEpoch);
            if (decision.toolCallMade) {
              final continuation = StringBuffer()..write('<|im_end|>\n');
              if (!entry.primed && systemContext.trim().isNotEmpty) {
                PromptFormatter.writePrivateContext(
                    continuation, systemContext);
              }
              if (effectiveGroundedContext.isNotEmpty) {
                continuation.write(
                  '<|im_start|>tool\n'
                  '<tool_response>\n'
                  '$effectiveGroundedContext\n'
                  '</tool_response>\n'
                  '<|im_end|>\n',
                );
              }
              continuation.write(
                '<|im_start|>assistant\n<think>\n\n</think>\n\n',
              );
              renderedPrompt = continuation.toString();
            } else {
              // The search decision concluded with ANSWER. Reset the session
              // so the main answer generation starts cleanly from the user's
              // actual prompt rather than appending to the temporary decision tokens.
              await session.clear();
              entry.primed = false;
              entry.basePrefixReady = false;
              renderedPrompt = _renderPrompt(
                entry,
                prompt,
                history,
                systemContext: systemContext,
                groundedContext: groundedContext,
                analysis: promptAnalysis,
                includeTaskInstruction: includeTaskInstruction,
                primeEmptyThinking: primeEmptyThinking,
                includeMediaMarker: useMediaMarker,
                mediaCount: useMediaMarker ? effectiveMediaList.length : 0,
                attachedDocContext: attachedDocContext,
              );
            }
          }
          // If multimodal not loaded but user attached image, surface fallback
          if (hasAttachedImage && !runtime.engine.multimodalLoaded) {
            debugPrint(
                'FINN_MEDIA fallback: multimodal not loaded, answering without image');
            // Inject a system note so answer acknowledges missing vision capability
            final fallbackNote =
                'Note: The user attached ${effectiveMediaList.length} image(s) but the image component is not installed. Explain that image analysis is unavailable on this device and ask them to describe the image or install the image component.';
            final previousContext = attachedDocContext;
            attachedDocContext =
                (previousContext == null || previousContext.isEmpty)
                    ? fallbackNote
                    : '$previousContext\n\n$fallbackNote';
            // Re-render without media marker so text path still works
            renderedPrompt = _renderPrompt(
              entry,
              prompt,
              history,
              systemContext: systemContext,
              groundedContext: groundedContext,
              analysis: promptAnalysis,
              includeTaskInstruction: includeTaskInstruction,
              primeEmptyThinking: primeEmptyThinking,
              includeMediaMarker: false,
              mediaCount: 0,
              attachedDocContext: attachedDocContext,
            );
          }
          // HEIC graceful fallback: if we had skipped HEICs, note it
          if (skippedHeicPaths.isNotEmpty &&
              effectiveMediaList.isEmpty &&
              hasAttachedImage == false) {
            // Already noted in attachedDocContext above
          }
          _setStatus(
            InferencePhase.generating,
            'Thinking on this device',
            key: FinnStatusKey.thinkingOnDevice,
          );
          trace?.mark(TtftPhase.generationRequested);
          _generation = session
              .generate(
            prompt: renderedPrompt,
            addSpecial: !entry.primed && !entry.basePrefixReady,
            parseSpecial: true,
            maxTokens: outputBudget,
            media: (hasAttachedImage && runtime.engine.multimodalLoaded)
                ? effectiveMediaList
                : const <LlamaMedia>[],
            shiftPolicy: runtime.engine.canShift && effectiveMediaList.isEmpty
                ? ContextShiftPolicy.auto
                : ContextShiftPolicy.off,
            shift: ContextShift(
              nKeep: entry.basePrefixReady ? 321 : 0,
            ),
            sampler: PromptIntentPolicy.sampler(
              promptAnalysis.intent,
            ).params.copyWith(seed: _nextGenerationSeed()),
          )
              .listen(
            (event) {
              if (generationEpoch != _generationEpoch) return;
              if (event case TokenEvent(:final text)) {
                emittedTokens++;
                trace?.mark(TtftPhase.nativeToken);
                if (text.isNotEmpty && firstTokenAt == null) {
                  firstTokenAt = runWatch.elapsed;
                  if (!kReleaseMode) {
                    debugPrint(
                      'FINN_PERF first_token_ms=${firstTokenAt!.inMilliseconds} '
                      'model=${model.tier.name} '
                      'ctx=${_plan?.contextSize} threads=${_plan?.threads}',
                    );
                  }
                }
                if (text.isNotEmpty) {
                  output.add(text);
                }
              } else if (event
                  case DoneEvent(
                    :final trailingText,
                    :final generatedCount,
                    :final reason,
                  )) {
                nativeFinished = true;
                if (trailingText.isNotEmpty) output.add(trailingText);
                final total = runWatch.elapsed;
                final decodeMs = total.inMilliseconds -
                    (firstTokenAt?.inMilliseconds ?? total.inMilliseconds);
                final decodeTokens = math.max(0, generatedCount - 1);
                final tokensPerSecond =
                    decodeMs <= 0 ? 0.0 : decodeTokens * 1000 / decodeMs;
                _lastGenerationReport = GenerationReport(
                  model: model,
                  intent: promptAnalysis.intent,
                  route: model.tier,
                  outputBudget: outputBudget,
                  finishReason: finishReasonFromStopReason(reason),
                  firstTokenLatency: firstTokenAt,
                  totalGenerationTime: total,
                  outputTokens: generatedCount,
                  tokensPerSecond: tokensPerSecond,
                );
                if (!kReleaseMode) {
                  final totalMs = total.inMilliseconds;
                  debugPrint(
                    'FINN_PERF done total_ms=$totalMs decode_ms=$decodeMs '
                    'tokens=$generatedCount emitted=$emittedTokens '
                    'tps=${tokensPerSecond.toStringAsFixed(2)}',
                  );
                }
              }
            },
            onError: (Object error, StackTrace stack) {
              _lastGenerationReport = GenerationReport(
                model: model,
                intent: promptAnalysis.intent,
                route: model.tier,
                outputBudget: outputBudget,
                finishReason: GenerationFinishReason.error,
                firstTokenLatency: firstTokenAt,
                totalGenerationTime: runWatch.elapsed,
                outputTokens: emittedTokens,
                tokensPerSecond: 0,
              );
              _setStatus(
                InferencePhase.error,
                _friendlyError(error),
                key: FinnStatusKey.error,
              );
              output.addError(error, stack);
              unawaited(output.close());
              unawaited(_recoverAfterError());
            },
            onDone: () {
              _generation = null;
              if (identical(_activeOutput, output)) {
                _activeOutput = null;
              }
              _lastSources = effectiveSources;
              entry.primed = true;
              entry.lastTaskInstruction = taskInstruction;
              entry.messageCount = history.length + 2;
              entry.lastUsed = ++runtime.useSequence;
              _setStatus(
                InferencePhase.idle,
                'Generated locally',
                key: FinnStatusKey.generatedLocally,
              );
              unawaited(output.close());
            },
            cancelOnError: true,
          );
        } on _GenerationCancelled {
          if (identical(_activeOutput, output)) _activeOutput = null;
          if (!output.isClosed) await output.close();
        } catch (error, stack) {
          if (identical(_activeOutput, output)) _activeOutput = null;
          _lastGenerationReport = GenerationReport(
            model: model,
            intent: promptAnalysis.intent,
            route: model.tier,
            outputBudget: outputBudget,
            finishReason: GenerationFinishReason.error,
            firstTokenLatency: firstTokenAt,
            totalGenerationTime: runWatch.elapsed,
            outputTokens: emittedTokens,
            tokensPerSecond: 0,
          );
          _setStatus(
            InferencePhase.error,
            _friendlyError(error),
            key: FinnStatusKey.error,
          );
          output.addError(error, stack);
          await output.close();
          unawaited(_recoverAfterError());
        }
      },
      onCancel: () async {
        _generationEpoch++;
        if (!nativeFinished) _markCancelled();
        await _generation?.cancel();
        _generation = null;
        if (identical(_activeOutput, output)) _activeOutput = null;
        if (_phase == InferencePhase.generating ||
            _phase == InferencePhase.loading) {
          _setStatus(
            InferencePhase.idle,
            'Stopped',
            key: FinnStatusKey.stopped,
          );
        }
      },
    );
    return output.stream;
  }

  Future<void> stopGeneration() async {
    _generationEpoch++;
    _markCancelled();
    await _generation?.cancel();
    _generation = null;
    final output = _activeOutput;
    _activeOutput = null;
    if (output != null && !output.isClosed) await output.close();
    if (_phase == InferencePhase.generating ||
        _phase == InferencePhase.loading) {
      _setStatus(
        InferencePhase.idle,
        'Stopped',
        key: FinnStatusKey.stopped,
      );
    }
  }

  /// Quarantines a generator that did not acknowledge cancellation promptly.
  ///
  /// [LlamaEngine.dispose] closes its streams and kills the worker isolate
  /// after its own bounded two-second shutdown handshake. The runtime map is
  /// cleared before awaiting disposal, so stale sessions cannot be reused.
  Future<void> resetAfterCancellationTimeout() async {
    _generationEpoch++;
    final generation = _generation;
    _generation = null;
    unawaited(generation?.cancel());
    final output = _activeOutput;
    _activeOutput = null;
    if (output != null && !output.isClosed) await output.close();

    _runtimeEpoch++;
    final runtimes = _runtimes.values.toList(growable: false);
    _runtimes.clear();
    _loadJobs.clear();
    for (final runtime in runtimes) {
      await runtime.engine.dispose();
    }
    _replyInFlight = false;
    _setStatus(
      InferencePhase.idle,
      'Ready after runtime reset',
      key: FinnStatusKey.readyAfterRuntimeReset,
    );
  }

  /// Clears the in-flight generation state after a native error so the app
  /// never stays stuck on the failed task.
  ///
  /// A decode or context-overflow failure leaves the affected session's KV
  /// cache in an unknown (usually full) state, so conversation sessions are
  /// dropped. The loaded engines stay resident and the next request simply
  /// re-primes the shared prefix. The friendly error status is intentionally
  /// left in place for the controller to surface on the failed message.
  Future<void> _recoverAfterError() async {
    try {
      _generationEpoch++;
      final generation = _generation;
      _generation = null;
      unawaited(generation?.cancel());
      final output = _activeOutput;
      _activeOutput = null;
      if (output != null && !output.isClosed) await output.close();
      await releaseConversationSessions();
    } catch (_) {
      // Recovery is best-effort; the controller already surfaces the original
      // error on the failed message.
    }
  }

  /// One-time, post-download benchmark that measures every available backend
  /// and caches the fastest one. Runs the CPU baseline first so the app always
  /// has a working engine even if every accelerator candidate fails.
  ///
  /// Callers surface the work through the normal [status] listener: the phase
  /// is [InferencePhase.loading] and the status reads
  /// "Setting up FinnAI for optimal performance…".
  Future<void> optimizeForDevice() async {
    if (_benchmarkRunning || _replyInFlight || _runtimes.isNotEmpty) return;
    if (!Platform.isAndroid && !Platform.isLinux) return;
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
      if (!debugForceCpu &&
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

  /// True when the benchmark should run again: no valid cached backend
  /// selection exists for this device, model, and app build (e.g. after an
  /// app update that changed the runtime).
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
    final mmprojFile = await _mmprojFile();
    final hasMmproj = await mmprojFile.exists() &&
        await mmprojFile.length() == finnMmproj.expectedBytes;
    return LlamaEngine.spawn(
      libraryPath: 'libllama.so',
      backendDirectory: profile.nativeLibraryDir,
      multimodalParams: hasMmproj
          ? MultimodalParams(
              mmprojPath: mmprojFile.path,
              useGpu: hasOffloadHeadroom(
                  profile: profile, modelBytes: model.expectedBytes),
              nThreads: config.batchThreads > 0 ? config.batchThreads : 8,
              imageMinTokens: (DeviceProfiler.isLowEnd(profile) ||
                      (profile.availableRamBytes != null &&
                          profile.availableRamBytes! < 1800 * 1024 * 1024))
                  ? 96
                  : 64,
              imageMaxTokens: (DeviceProfiler.isLowEnd(profile) ||
                      (profile.availableRamBytes != null &&
                          profile.availableRamBytes! < 1800 * 1024 * 1024))
                  ? 192
                  : 256,
            )
          : null,
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

  void _markCancelled() {
    final previous = _lastGenerationReport;
    if (previous == null) return;
    _lastGenerationReport = GenerationReport(
      model: previous.model,
      intent: previous.intent,
      route: previous.route,
      outputBudget: previous.outputBudget,
      finishReason: GenerationFinishReason.userCancellation,
      firstTokenLatency: previous.firstTokenLatency,
      totalGenerationTime: previous.totalGenerationTime,
      outputTokens: previous.outputTokens,
      tokensPerSecond: previous.tokensPerSecond,
    );
  }

  void _throwIfGenerationCancelled(int epoch) {
    if (epoch != _generationEpoch) throw const _GenerationCancelled();
  }

  Future<File> _ensureDownloaded(FinnModelSpec model) async {
    final target = await _modelFile(model);
    if (_verifiedModels.contains(model.tier) ||
        await _isVerifiedModelFile(model, target)) {
      _verifiedModels.add(model.tier);
      return target;
    }

    final partial = File('${target.path}.part');
    var existing = await partial.exists() ? await partial.length() : 0;
    if (existing > model.expectedBytes) {
      await partial.delete();
      existing = 0;
    }
    if (existing == model.expectedBytes) {
      _setStatus(
        InferencePhase.loading,
        'Checking the download',
        key: FinnStatusKey.checkingDownload,
      );
      final promoted = await promoteVerifiedModelPartial(
        partial: partial,
        target: target,
        expectedBytes: model.expectedBytes,
      );
      if (promoted) {
        _verifiedModels.add(model.tier);
        _completeInstallArtifact(model.expectedBytes);
        return target;
      }
      existing = 0;
    }
    if (Platform.isAndroid) {
      final freshProfile = await DeviceProfiler.read();
      final available = freshProfile.availableStorageBytes;
      final remaining = math.max(0, model.expectedBytes - existing);
      final reserve = math.max(256 * 1024 * 1024, model.expectedBytes ~/ 20);
      if (available != null && available < remaining + reserve) {
        throw const FileSystemException(
          'Not enough storage for the model and safety reserve.',
        );
      }
      return _ensureArtifactWithService(
        url: model.downloadUrl,
        target: target,
        partial: partial,
        expectedBytes: model.expectedBytes,
        label: 'FinnAI model',
        sha256Digest: model.sha256Digest,
      );
    }
    // Default certificate validation stays enabled: the production model is
    // additionally pinned via its SHA-256 digest after the transfer, but TLS
    // must not be weakened for every other request on this client.
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    _downloadClient = client;
    try {
      _setStatus(
        InferencePhase.downloading,
        'Downloading the AI model',
        key: FinnStatusKey.downloadingModel,
        progress: 0,
        totalBytes: model.expectedBytes,
      );
      final modelUri = Uri.parse(model.downloadUrl);
      final request = await client.getUrl(modelUri);
      request.followRedirects = true;
      if (existing > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existing-');
      }
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw HttpException(
          'Model download failed (${response.statusCode})',
          uri: modelUri,
        );
      }
      if (response.statusCode == HttpStatus.ok && existing > 0) {
        await partial.writeAsBytes(const [], flush: true);
        existing = 0;
      }
      final total = _contentTotal(response, existing) ?? model.expectedBytes;
      final sink = partial.openWrite(
        mode: existing > 0 ? FileMode.append : FileMode.write,
      );
      var received = existing;
      var lastNotification = DateTime.fromMillisecondsSinceEpoch(0);
      final updateInterval = Duration(
        milliseconds: switch (_deviceProfile?.processor) {
          ProcessorClass.flagship => 140,
          ProcessorClass.balanced => 190,
          _ => 260,
        },
      );
      try {
        await for (final bytes in response) {
          if (_cancelDownload) throw const HttpException('Download paused');
          sink.add(bytes);
          received += bytes.length;
          final now = DateTime.now();
          if (now.difference(lastNotification) > updateInterval) {
            lastNotification = now;
            _setStatus(
              InferencePhase.downloading,
              'Downloading the AI model',
              key: FinnStatusKey.downloadingModel,
              progress: (received / total).clamp(0, 1),
              totalBytes: total,
            );
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      if (_cancelDownload) throw const HttpException('Download paused');
      _setStatus(
        InferencePhase.loading,
        'Checking the download',
        key: FinnStatusKey.checkingDownload,
      );
      if (await partial.length() != model.expectedBytes) {
        await partial.delete();
        throw const FormatException('Downloaded model has an invalid size');
      }
      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
      if (!await _looksLikeGguf(target)) {
        await target.delete();
        throw const FormatException(
          'Downloaded model is not a valid GGUF file',
        );
      }
      await _verifyArtifactDigest(target, model.sha256Digest);
      _verifiedModels.add(model.tier);
      _completeInstallArtifact(model.expectedBytes);
      return target;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _sha256File(File file) async {
    try {
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString();
    } on StateError {
      throw const FormatException('Downloaded file is empty or unreadable');
    }
  }

  Future<void> _verifyArtifactDigest(File file, String expectedDigest) async {
    if (expectedDigest.isEmpty) return;
    final actual = await _sha256File(file);
    if (actual.toLowerCase() != expectedDigest.toLowerCase()) {
      throw const FormatException(
        'Downloaded artifact failed SHA-256 verification',
      );
    }
  }

  Future<File> _ensureArtifactWithService({
    required String url,
    required File target,
    required File partial,
    required int expectedBytes,
    required String label,
    required String sha256Digest,
  }) async {
    // A process can be killed after the final byte lands but before the
    // Android service is asked to promote the file. Verify that state locally
    // so a corrupt full-length partial is not resumed with an unsatisfiable
    // range request.
    if (await partial.exists()) {
      final partialLength = await partial.length();
      if (partialLength >= expectedBytes) {
        if (await promoteVerifiedModelPartial(
          partial: partial,
          target: target,
          expectedBytes: expectedBytes,
        )) {
          if (sha256Digest.isNotEmpty) {
            await _verifyArtifactDigest(target, sha256Digest);
          }
          _completeInstallArtifact(expectedBytes);
          return target;
        }
        if (partialLength > expectedBytes && await partial.exists()) {
          await partial.delete();
        }
      }
    }
    _setStatus(
      InferencePhase.downloading,
      'Downloading $label',
      key: FinnStatusKey.downloadingArtifact,
      progress: 0,
      totalBytes: expectedBytes,
    );
    Future<void> requestStart() =>
        _backgroundDownloadChannel.invokeMethod<void>('start', {
          'url': url,
          'target': target.path,
          'expectedBytes': expectedBytes,
          'label': label,
        });
    await requestStart();
    var restarts = 0;
    DateTime? lastRestartAt;
    bool restarting = false;
    int? lastHeartbeat;
    DateTime? lastProgressAt;
    var sawProgress = false;
    while (true) {
      if (_cancelDownload) {
        await _cancelAndroidDownload(target.path);
        throw const HttpException('Download paused');
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final raw = await _backgroundDownloadChannel
          .invokeMapMethod<String, dynamic>('status');
      if (raw == null || raw['target'] != target.path) continue;
      final progress = (raw['progress'] as num?)?.toDouble() ?? 0;
      final speedBps = (raw['speedBps'] as num?)?.toDouble() ?? 0;
      final remainingBytes = (raw['remainingBytes'] as num?)?.toInt() ?? 0;
      final active = raw['active'] == true;
      final failed = raw['failed'] == true;
      final cancelled = raw['cancelled'] == true;
      final heartbeat = (raw['heartbeat'] as num?)?.toInt();
      if (progress > 0) sawProgress = true;
      if (!restarting) {
        _setStatus(
          InferencePhase.downloading,
          'Downloading $label',
          key: FinnStatusKey.downloadingArtifact,
          progress: progress,
          totalBytes: expectedBytes,
          speedBps: speedBps,
          remainingBytes: remainingBytes,
        );
      }
      if (raw['complete'] == true) break;

      final now = DateTime.now();
      // A dead, wedged, or failed service is restarted so the partial resumes
      // from its persisted per-range progress. Restarts are cheap, and only a
      // string of quick consecutive failures surfaces as an error — a single
      // transient blip (a read timeout, a dropped connection, a momentary DNS
      // miss) must never interrupt an in-flight download with an internet
      // error. The heartbeat advances only while a transfer is actually
      // writing bytes, so fresh progress also resets the failure counter.
      final stalled = sawProgress &&
          active &&
          lastProgressAt != null &&
          now.difference(lastProgressAt) > const Duration(seconds: 20);
      final needsRestart = !active || stalled || failed || cancelled;
      if (!needsRestart) {
        if (heartbeat != null && heartbeat != lastHeartbeat) {
          lastHeartbeat = heartbeat;
          lastProgressAt = now;
          restarts = 0;
        }
        continue;
      }
      if (restarting) {
        // A restart is already in flight. The service ignores a start while
        // its old thread is still alive (the Kotlin isRunning guard), so wait
        // for the thread to die — visible as active=false — before starting
        // the replacement.
        if (!active) {
          restarting = false;
          await requestStart();
        }
        continue;
      }
      if (lastRestartAt != null &&
          now.difference(lastRestartAt) < const Duration(seconds: 4)) {
        // Backoff: the replacement service may still be starting up.
        continue;
      }
      restarts++;
      if (restarts > 6) {
        throw HttpException(
          (raw['error'] as String?) ?? 'Model download kept stopping',
        );
      }
      lastRestartAt = now;
      restarting = true;
      lastHeartbeat = null;
      lastProgressAt = null;
      sawProgress = false;
      if (failed) {
        // The thread already finished (failure was recorded); a replacement
        // can start immediately.
        restarting = false;
        await requestStart();
        continue;
      }
      if (stalled) {
        // Ask the wedged service to stop; it observes the cancel on its next
        // read timeout and releases the liveness flag.
        await _cancelAndroidDownload(target.path);
      }
      if (!active) {
        restarting = false;
        await requestStart();
      }
    }
    _setStatus(
      InferencePhase.loading,
      'Verifying $label',
      key: FinnStatusKey.verifyingArtifact,
    );
    if (!await promoteVerifiedModelPartial(
      partial: partial,
      target: target,
      expectedBytes: expectedBytes,
    )) {
      throw const FormatException('Downloaded file failed verification');
    }
    if (sha256Digest.isNotEmpty) {
      await _verifyArtifactDigest(target, sha256Digest);
    }
    _completeInstallArtifact(expectedBytes);
    return target;
  }

  /// Number of parallel HTTP range segments for non-Android downloads.
  /// The Android path uses the foreground service's own segment count; this
  /// keeps desktop/macOS model + projector transfers fast too. Sixteen
  /// segments keeps high-latency and lossy links saturated the way the
  /// Android foreground service does.
  static const int _dartDownloadSegments = 16;

  Future<File> _ensureArtifactDart({
    required String url,
    required File target,
    required int expectedBytes,
    required String label,
    required String sha256Digest,
  }) async {
    final partial = File('${target.path}.part');
    var existing = await partial.exists() ? await partial.length() : 0;
    if (existing > expectedBytes) {
      await partial.delete();
      existing = 0;
    }
    if (existing == expectedBytes) {
      if (!await _looksLikeGguf(partial)) {
        await partial.delete();
        existing = 0;
      } else {
        if (await target.exists()) await target.delete();
        await partial.rename(target.path);
        if (sha256Digest.isNotEmpty) {
          await _verifyArtifactDigest(target, sha256Digest);
        }
        _completeInstallArtifact(expectedBytes);
        return target;
      }
    }
    // Default certificate validation stays enabled (see _ensureDownloaded).
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..maxConnectionsPerHost = _dartDownloadSegments + 2;
    _downloadClient = client;
    try {
      _setStatus(
        InferencePhase.downloading,
        'Downloading $label',
        progress: 0,
        key: FinnStatusKey.downloadingArtifact,
      );

      // Probe for range support + total size.
      final probeRequest = await client.getUrl(Uri.parse(url));
      probeRequest.followRedirects = true;
      probeRequest.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      final probe = await probeRequest.close();
      final ranged = probe.statusCode == HttpStatus.partialContent;
      final total = ranged
          ? _contentTotal(probe, 0) ?? expectedBytes
          : probe.contentLength > 0
              ? probe.contentLength
              : expectedBytes;
      await probe.drain<void>();

      if (!ranged || total <= 0) {
        // Server doesn't support ranges: fall back to a single stream.
        await _downloadSingleStream(
          client,
          url: url,
          partial: partial,
          total: total,
          expectedBytes: expectedBytes,
          existing: existing,
          label: label,
        );
      } else {
        await _downloadSegmented(
          client,
          url: url,
          partial: partial,
          total: total,
          existing: existing,
          expectedBytes: expectedBytes,
          label: label,
        );
      }

      if (_cancelDownload) throw const HttpException('Download paused');
      _setStatus(
        InferencePhase.loading,
        'Verifying $label',
        key: FinnStatusKey.verifyingArtifact,
      );
      if (await partial.length() != expectedBytes) {
        await partial.delete();
        throw const FormatException('Downloaded file has an invalid size');
      }
      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
      if (!await _looksLikeGguf(target)) {
        await target.delete();
        throw const FormatException('Downloaded file is not a valid GGUF file');
      }
      if (sha256Digest.isNotEmpty) {
        await _verifyArtifactDigest(target, sha256Digest);
      }
      _completeInstallArtifact(expectedBytes);
      return target;
    } finally {
      client.close(force: true);
    }
  }

  /// Single-stream (non-range) fallback for [ _ensureArtifactDart].
  Future<void> _downloadSingleStream(
    HttpClient client, {
    required String url,
    required File partial,
    required int total,
    required int expectedBytes,
    required int existing,
    required String label,
  }) async {
    final request = await client.getUrl(Uri.parse(url));
    request.followRedirects = true;
    if (existing > 0) {
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existing-');
    }
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.partialContent) {
      throw HttpException('Download failed (${response.statusCode})');
    }
    if (response.statusCode == HttpStatus.ok && existing > 0) {
      await partial.writeAsBytes(const [], flush: true);
      existing = 0;
    }
    final effectiveTotal = _contentTotal(response, existing) ?? total;
    final sink = partial.openWrite(
      mode: existing > 0 ? FileMode.append : FileMode.write,
    );
    var received = existing;
    var lastNotification = DateTime.fromMillisecondsSinceEpoch(0);
    final updateInterval = Duration(
      milliseconds: switch (_deviceProfile?.processor) {
        ProcessorClass.flagship => 140,
        ProcessorClass.balanced => 190,
        _ => 260,
      },
    );
    try {
      await for (final bytes in response) {
        if (_cancelDownload) throw const HttpException('Download paused');
        sink.add(bytes);
        received += bytes.length;
        final now = DateTime.now();
        if (now.difference(lastNotification) > updateInterval) {
          lastNotification = now;
          _setStatus(
            InferencePhase.downloading,
            'Downloading $label',
            key: FinnStatusKey.downloadingArtifact,
            progress: (received / effectiveTotal).clamp(0, 1),
          );
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  /// Parallel HTTP-range downloader used by the non-Android path.
  ///
  /// Splits [total] bytes into [_dartDownloadSegments] ranges fetched
  /// concurrently (the same strategy the Android foreground service uses),
  /// writing each range to its own offset in the `.part` file. Progress is
  /// reported from the sum of completed range bytes; a failed range retries
  /// in place so a single flaky stream can't abort the whole transfer.
  Future<void> _downloadSegmented(
    HttpClient client, {
    required String url,
    required File partial,
    required int total,
    required int existing,
    required int expectedBytes,
    required String label,
  }) async {
    final count = _dartDownloadSegments;
    final chunkSize = (total + count - 1) ~/ count;
    final startOffsets = List<int>.generate(count, (i) => i * chunkSize);
    final endOffsets = List<int>.generate(
      count,
      (i) => math.min((i + 1) * chunkSize - 1, total - 1),
    );
    // Resume: an existing partial is a contiguous prefix. Ranges fully
    // covered by it are skipped; the first partially covered range resumes
    // from its byte offset; ranges after it start from their own start.
    final receivedByRange = List<int>.filled(count, 0);
    var covered = 0;
    if (existing > 0 && existing <= total) {
      for (var i = 0; i < count; i++) {
        final rangeLen = endOffsets[i] - startOffsets[i] + 1;
        if (covered + rangeLen <= existing) {
          receivedByRange[i] = rangeLen;
          covered += rangeLen;
        } else {
          final resume = math.max(0, existing - covered);
          if (resume > 0) {
            // Advance the range's start past the already-downloaded bytes.
            // receivedByRange stays 0 relative to the new start, so the
            // fetch writes from startOffsets[i] and counts only new bytes.
            startOffsets[i] += resume;
            covered += resume;
          }
          break;
        }
      }
    }
    var lastNotification = DateTime.fromMillisecondsSinceEpoch(0);
    final updateInterval = Duration(
      milliseconds: switch (_deviceProfile?.processor) {
        ProcessorClass.flagship => 140,
        ProcessorClass.balanced => 190,
        _ => 260,
      },
    );
    // Ranges write disjoint byte offsets, so a single RandomAccessFile is
    // safe: every write happens at a distinct position and Dart's isolate
    // event loop never interleaves two writes to the same offset.
    // Keep a contiguous resumable prefix intact while range requests fill
    // the remaining disjoint offsets.
    final raf = partial.openSync(mode: FileMode.writeOnly);
    Future<void> fetchRange(int index) async {
      if (receivedByRange[index] >=
          endOffsets[index] - startOffsets[index] + 1) {
        return;
      }
      var attempt = 0;
      while (true) {
        try {
          final request = await client.getUrl(Uri.parse(url));
          request.followRedirects = true;
          request.headers.set(
            HttpHeaders.rangeHeader,
            'bytes=${startOffsets[index]}-${endOffsets[index]}',
          );
          final response = await request.close();
          if (response.statusCode != HttpStatus.partialContent &&
              response.statusCode != HttpStatus.ok) {
            throw HttpException('Range $index failed (${response.statusCode})');
          }
          await for (final bytes in response) {
            if (_cancelDownload) throw const HttpException('Download paused');
            raf.setPositionSync(startOffsets[index] + receivedByRange[index]);
            raf.writeFromSync(bytes);
            receivedByRange[index] += bytes.length;
            final now = DateTime.now();
            if (now.difference(lastNotification) > updateInterval) {
              lastNotification = now;
              final received = receivedByRange.fold<int>(0, (a, b) => a + b);
              _setStatus(
                InferencePhase.downloading,
                'Downloading $label',
                key: FinnStatusKey.downloadingArtifact,
                progress: (received / total).clamp(0, 1),
              );
            }
          }
          final expectedLen = endOffsets[index] - startOffsets[index] + 1;
          if (receivedByRange[index] < expectedLen) {
            throw HttpException(
              'Range $index truncated '
              '(${receivedByRange[index]}/$expectedLen)',
            );
          }
          return;
        } catch (error) {
          if (_cancelDownload) rethrow;
          if (attempt >= 2) rethrow;
          attempt++;
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        }
      }
    }

    try {
      await Future.wait([for (var i = 0; i < count; i++) fetchRange(i)]);
    } finally {
      raf.flushSync();
      raf.closeSync();
    }
  }

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
      // Projector GPU offload and token caps derived from device profile
      // (constrained: 96 min/192 max; otherwise 64 min/256 max).
      final useProjectorGpu = hasOffloadHeadroom(
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
      debugPrint('FINN_LOADMODEL_ERROR $e');
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

    final primaryEngine = engine;
    _lastKnownLlamaCppCommit = primaryEngine.llamaCppCommit;
    adaptive.attachLlamaCppCommit(_lastKnownLlamaCppCommit);

    // The engine is now live. Inspect the backends the runtime actually
    // loaded and upgrade to the best NPU/GPU when available. A failed
    // accelerated spawn keeps the working CPU engine. Skip discovery when the
    // benchmark already cached a decision (including a deliberate CPU pick) or
    // when we just fell back from a cached accelerator that could not spawn.
    if (!debugForceCpu &&
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
        ? (debugSkipSha256
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

  /// Human-readable adaptive engine diagnostics (device, model, backends,
  /// benchmarks, selected config, reason).
  String diagnostics() =>
      AdaptiveInferenceEngine.instance.diagnostics().toDiagnosticsString();

  /// The adaptive engine's current device profile.
  Future<DeviceProfile> deviceInfo() =>
      AdaptiveInferenceEngine.instance.deviceInfo();

  /// The cached adaptive benchmark profile (null before the first run).
  Future<BenchmarkProfile?> performanceProfile() =>
      AdaptiveInferenceEngine.instance.performanceProfile();

  /// The adaptive engine's current status.
  EngineStatus adaptiveStatus() => AdaptiveInferenceEngine.instance.status();

  Future<_PreparedSession> _prepareSession(
    _ModelRuntime runtime,
    String conversationId,
    List<LocalChatTurn> history,
    String systemContext,
  ) =>
      runtime.sessionSetupGate.run(
        () => _prepareSessionUnlocked(
          runtime,
          conversationId,
          history,
          systemContext,
        ),
      );

  Future<_PreparedSession> _prepareSessionUnlocked(
    _ModelRuntime runtime,
    String conversationId,
    List<LocalChatTurn> history,
    String systemContext,
  ) async {
    final privateContextHash =
        sha256.convert(utf8.encode(systemContext.trim())).toString();
    final commonConfiguration = _prefixCacheKey(runtime);
    final configuration = sha256
        .convert(
          utf8.encode(
            '${commonConfiguration.stableHash}|$privateContextHash|mode=chat',
          ),
        )
        .toString();
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
      commonConfiguration,
    );
    final entry = _ConversationSession(
      session: session,
      sequenceId: sequenceId,
      conversationId: conversationId,
      promptConfigurationHash: configuration,
      messageCount: history.length,
      lastUsed: ++runtime.useSequence,
      basePrefixReady:
          _persistentPrefixCacheEnabled && !debugDisablePrefixCache,
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
      systemPromptVersion: systemPromptVersion,
      chatTemplateVersion: chatTemplateVersion,
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
    if (!_persistentPrefixCacheEnabled || debugDisablePrefixCache) {
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
    if (!_persistentPrefixCacheEnabled || runtime.sessions.isNotEmpty) {
      return const PrefixStateReport(cacheHit: false, tokens: 0, fileBytes: 0);
    }
    final session = await runtime.engine.createSession(seqId: 0);
    try {
      final report = await _restoreOrPrepareBasePrefix(
        runtime,
        session,
        _prefixCacheKey(runtime),
      );
      if (!kReleaseMode) {
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

  String get _baseSystemPrefix => PromptFormatter.baseSystemPrefix;

  /// Kept as a public alias of [PromptFormatter.finnSafetySystemPrompt] (the
  /// single source of truth for the safety prefix text) so diagnostics and
  /// tests keep reading it off the accelerator facade.
  static const finnSafetySystemPrompt = PromptFormatter.finnSafetySystemPrompt;

  static bool _isImageFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.gif');
  }

  static bool _isHeicPath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.heic') || lower.endsWith('.heif');
  }

  static bool _bytesLookLikeImage(Uint8List bytes, String path) {
    if (bytes.length < 4) return false;
    final lower = path.toLowerCase();
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return false;
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // PNG: 89 50 4E 47
    final isPng = bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    if (isPng) return true;
    // GIF: 47 49 46
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    // WEBP: 52 49 46 46 ... 57 45 42 50
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      final isWebp = bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50;
      if (isWebp) return true;
    }
    // BMP: 42 4D
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true;
    // Fallback: treat as image if extension is image-like and not plain text
    return _isImageFile(path);
  }

  String _renderPrompt(
    _ConversationSession entry,
    String prompt,
    List<LocalChatTurn> history, {
    String systemContext = '',
    String groundedContext = '',
    PromptAnalysis? analysis,
    bool includeTaskInstruction = true,
    required bool primeEmptyThinking,
    bool includeMediaMarker = false,
    int? mediaCount,
    String? attachedDocContext,
  }) {
    return _renderPromptText(
      primed: entry.primed,
      prompt: prompt,
      history: history,
      systemContext: systemContext,
      groundedContext: groundedContext,
      analysis: analysis,
      includeTaskInstruction: includeTaskInstruction,
      basePrefixReady: entry.basePrefixReady,
      primeEmptyThinking: primeEmptyThinking,
      includeMediaMarker: includeMediaMarker,
      mediaCount: mediaCount,
      attachedDocContext: attachedDocContext,
    );
  }

  /// Renders the prompt for the search-decision pass: the same structure as
  /// [_renderPromptText] but with the decision directive as an extra system
  /// message and no think-block priming (the model must emit a plain
  /// sentence). The generated decision tokens stay in the session KV cache;
  /// the answer generation continues after them.
  String _renderDecisionPromptText({
    required bool primed,
    required bool basePrefixReady,
    required bool includeTaskInstruction,
    required PromptAnalysis analysis,
    required String prompt,
    required List<LocalChatTurn> history,
    required String directive,
  }) {
    return PromptFormatter.renderDecisionPromptText(
      primed: primed,
      basePrefixReady: basePrefixReady,
      includeTaskInstruction: includeTaskInstruction,
      analysis: analysis,
      prompt: prompt,
      history: history,
      directive: directive,
    );
  }

  String _renderPromptText({
    required bool primed,
    required String prompt,
    required List<LocalChatTurn> history,
    String systemContext = '',
    String groundedContext = '',
    PromptAnalysis? analysis,
    bool includeTaskInstruction = true,
    bool basePrefixReady = false,
    bool primeEmptyThinking = true,
    bool includeMediaMarker = false,
    int? mediaCount,
    String? attachedDocContext,
  }) {
    // Single source of truth for prompt rendering lives in [PromptFormatter];
    // the runtime only contributes its planned context size so history
    // trimming matches the context the engine will actually run with.
    return PromptFormatter.renderPromptText(
      primed: primed,
      prompt: prompt,
      history: history,
      contextTokens: _plan?.contextSize ?? 2048,
      systemContext: systemContext,
      groundedContext: groundedContext,
      analysis: analysis,
      includeTaskInstruction: includeTaskInstruction,
      basePrefixReady: basePrefixReady,
      primeEmptyThinking: primeEmptyThinking,
      includeMediaMarker: includeMediaMarker,
      mediaCount: mediaCount,
      attachedDocContext: attachedDocContext,
    );
  }

  @visibleForTesting
  String renderPromptForTest({
    required String prompt,
    List<LocalChatTurn> history = const [],
    String systemContext = '',
    String groundedContext = '',
    bool includeTaskInstruction = true,
    bool primed = false,
    bool basePrefixReady = false,
    bool primeEmptyThinking = true,
  }) {
    return _renderPromptText(
      primed: primed,
      prompt: prompt,
      history: history,
      systemContext: systemContext,
      groundedContext: groundedContext,
      analysis: const PromptIntentClassifier().classify(prompt),
      includeTaskInstruction: includeTaskInstruction,
      basePrefixReady: basePrefixReady,
      primeEmptyThinking: primeEmptyThinking,
    );
  }

  @visibleForTesting
  Map<String, int> promptTokenBreakdownForTest({
    required String prompt,
    List<LocalChatTurn> history = const [],
    String systemContext = '',
    bool primed = false,
    bool includeTaskInstruction = true,
    bool basePrefixReady = false,
    bool primeEmptyThinking = true,
  }) {
    int tokens(String value) => (value.length / 3.2).ceil();
    final analysis = const PromptIntentClassifier().classify(prompt);
    final priorRecipe = history.any(
      (turn) =>
          turn.role == 'assistant' &&
          PromptFormatter.isRecipeAnswer(turn.content),
    );
    final isRecipeFollowUp = analysis.intent == PromptIntent.recipe &&
        priorRecipe &&
        PromptFormatter.freshRecipeRequest.hasMatch(prompt);
    final rebuildContext = primed && isRecipeFollowUp;
    final task = (includeTaskInstruction || rebuildContext)
        ? PromptIntentPolicy.taskInstruction(analysis)
        : '';
    final replayHistory = isRecipeFollowUp
        ? PromptFormatter.historyWithoutRecipes(history)
        : history;
    final recent = (primed && !rebuildContext)
        ? const <LocalChatTurn>[]
        : _recentHistory(prompt, replayHistory, systemContext: systemContext);
    final base = primed || basePrefixReady ? '' : finnSafetySystemPrompt;
    final privateText = primed ? '' : systemContext.trim();
    final historyText = recent.map((turn) => turn.content).join('\n');
    final rendered = _renderPromptText(
      primed: primed,
      prompt: prompt,
      history: history,
      systemContext: systemContext,
      analysis: analysis,
      includeTaskInstruction: includeTaskInstruction,
      basePrefixReady: basePrefixReady,
      primeEmptyThinking: primeEmptyThinking,
    );
    final baseTokens = tokens(base);
    final taskTokens = tokens(task);
    final privateTokens = tokens(privateText);
    final historyTokens = tokens(historyText);
    final promptTokens = tokens(prompt);
    final totalTokens = tokens(rendered);
    return <String, int>{
      'base_system': baseTokens,
      'task_instruction': taskTokens,
      'private_context': privateTokens,
      'history': historyTokens,
      'user_prompt': promptTokens,
      'template_wrappers': math.max(
        0,
        totalTokens -
            baseTokens -
            taskTokens -
            privateTokens -
            historyTokens -
            promptTokens,
      ),
      'total': totalTokens,
    };
  }

  /// Bounds cold/reopened-chat prefill. Live chats still retain their KV cache
  /// between turns; restored chats replay only the newest useful context.
  List<LocalChatTurn> _recentHistory(
    String prompt,
    List<LocalChatTurn> history, {
    String systemContext = '',
  }) {
    return PromptFormatter.recentHistory(
      prompt,
      history,
      contextTokens: _plan?.contextSize ?? 2048,
      systemContext: systemContext,
    );
  }

  int _outputBudget(PromptAnalysis analysis) {
    // No per-intent output ceiling: long-form answers (writing, coding,
    // analysis) must not be truncated mid-thought. The only bound is the
    // device's context window, so maxTokens stays a runaway-safety bound
    // rather than a truncation target — a normal answer ends at EOG long
    // before this is reached.
    final contextSize = _plan?.contextSize ?? 2048;
    return math.max(
      PromptIntentPolicy.desiredOutputTokens(analysis.intent),
      contextSize - 96,
    );
  }

  @visibleForTesting
  int outputBudgetForTest(
    String prompt, {
    int? deviceCeiling,
    bool supported = true,
  }) {
    // Mirrors _outputBudget: no device-class ceiling; the desired intent
    // budget is only a floor beneath the context-derived bound.
    final analysis = const PromptIntentClassifier().classify(prompt);
    final contextSize = deviceCeiling ?? _plan?.contextSize ?? 2048;
    return math.max(
      PromptIntentPolicy.desiredOutputTokens(analysis.intent),
      contextSize - 96,
    );
  }

  Future<void> _unload() async {
    await _generation?.cancel();
    _generation = null;
    final output = _activeOutput;
    _activeOutput = null;
    if (output != null && !output.isClosed) await output.close();
    final runtimes = _runtimes.values.toList(growable: false);
    _runtimes.clear();
    for (final runtime in runtimes) {
      for (final entry in runtime.sessions.values) {
        await entry.session.dispose();
      }
      await runtime.engine.dispose();
    }
  }

  void _queueUnload() {
    _runtimeEpoch++;
    _pendingUnload = _pendingUnload.then((_) => _unload());
  }

  Future<void> _unloadModel(FinnModelTier tier) async {
    final runtime = _runtimes.remove(tier);
    if (runtime == null) return;
    for (final entry in runtime.sessions.values) {
      await entry.session.dispose();
    }
    await runtime.engine.dispose();
  }

  Future<File> _modelFile(FinnModelSpec model) async {
    final directory = await (_modelDirectoryJob ??= _createModelDirectory());
    return File('${directory.path}${Platform.pathSeparator}${model.fileName}');
  }

  Future<File> _mmprojFile() async {
    final directory = await (_modelDirectoryJob ??= _createModelDirectory());
    return File(
      '${directory.path}${Platform.pathSeparator}${finnMmproj.fileName}',
    );
  }

  /// True when the reserved post-model artifact is downloaded. The transfer
  /// enforces the exact byte count, so size is the integrity gate here;
  /// full-file SHA-256 was dropped to keep verification fast on budget devices.
  /// Lightweight existence check (no SHA) for UI toast path.
  Future<bool> hasMmprojFile() async {
    final file = await _mmprojFile();
    return await file.exists() &&
        await file.length() == finnMmproj.expectedBytes;
  }

  Future<bool> isMmprojInstalled() async {
    final file = await _mmprojFile();
    if (!await file.exists() ||
        await file.length() != finnMmproj.expectedBytes) {
      return false;
    }
    try {
      await _verifyArtifactDigest(file, finnMmproj.sha256Digest);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Downloads and verifies the reserved LFM2.5-VL projector artifact. It is
  /// intentionally not passed to llama.cpp until a later vision release.
  Future<void> installMmproj() async {
    if (await isMmprojInstalled()) return;
    if (Platform.isAndroid) {
      final storageProfile = await DeviceProfiler.read();
      final availableStorage = storageProfile.availableStorageBytes;
      const reserve = 256 * 1024 * 1024;
      if (availableStorage != null &&
          availableStorage < finnMmproj.expectedBytes + reserve) {
        throw const FileSystemException(
          'Not enough storage for the multimodal component and safety reserve.',
        );
      }
    }
    final target = await _mmprojFile();
    if (!await isInstalled(finnModels.single)) {
      throw StateError(
        'Download the language model before its component.',
      );
    }
    if (Platform.isAndroid) {
      final partial = File('${target.path}.part');
      await _ensureArtifactWithService(
        url: finnMmproj.downloadUrl,
        target: target,
        partial: partial,
        expectedBytes: finnMmproj.expectedBytes,
        label: 'Multimodal vision component',
        sha256Digest: finnMmproj.sha256Digest,
      );
      return;
    }
    await _ensureArtifactDart(
      url: finnMmproj.downloadUrl,
      target: target,
      expectedBytes: finnMmproj.expectedBytes,
      label: 'Multimodal vision component',
      sha256Digest: finnMmproj.sha256Digest,
    );
  }

  Future<Directory> _createModelDirectory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}${Platform.pathSeparator}models');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<void> _removePrefixStatesFor(String modelSha256) async {
    if (modelSha256.isEmpty) return;
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}prefix_states'
      '${Platform.pathSeparator}$modelSha256',
    );
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> _removeRetiredModelArtifacts() async {
    try {
      final modelDirectory =
          await (_modelDirectoryJob ??= _createModelDirectory());
      for (final fileName in _retiredModelFiles) {
        for (final suffix in const ['', '.part']) {
          final file = File(
            '${modelDirectory.path}${Platform.pathSeparator}$fileName$suffix',
          );
          if (await file.exists()) await file.delete();
        }
      }
      final support = await getApplicationSupportDirectory();
      for (final hash in _retiredPrefixHashes) {
        final directory = Directory(
          '${support.path}${Platform.pathSeparator}prefix_states'
          '${Platform.pathSeparator}$hash',
        );
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    } on FileSystemException catch (error) {
      debugPrint('Retired model cleanup failed: $error');
    }
  }

  Future<bool> _isVerifiedModelFile(FinnModelSpec model, File file) async {
    if (!await file.exists() || await file.length() != model.expectedBytes) {
      return false;
    }
    return _looksLikeGguf(file);
  }

  Future<bool> _looksLikeGguf(File file) async {
    if (!await file.exists() || await file.length() < 1024 * 1024) return false;
    final handle = await file.open();
    try {
      final magic = await handle.read(4);
      return magic.length == 4 &&
          magic[0] == 0x47 &&
          magic[1] == 0x47 &&
          magic[2] == 0x55 &&
          magic[3] == 0x46;
    } finally {
      await handle.close();
    }
  }

  int? _contentTotal(HttpClientResponse response, int existing) {
    final range = response.headers.value(HttpHeaders.contentRangeHeader);
    if (range != null) {
      final slash = range.lastIndexOf('/');
      if (slash >= 0) return int.tryParse(range.substring(slash + 1));
    }
    final length = response.contentLength;
    return length >= 0 ? length + existing : null;
  }

  /// Updates the user-visible status. [key] is the stable machine-readable
  /// counterpart of [status] (see [FinnStatusKey]); the display text itself
  /// is unchanged behavior.
  void _setStatus(
    InferencePhase phase,
    String status, {
    required FinnStatusKey key,
    double? progress,
    int? totalBytes,
    double? speedBps,
    int? remainingBytes,
  }) {
    if (phase == InferencePhase.downloading) {
      if (_phase != InferencePhase.downloading) {
        // A new download started: discard stale speed samples.
        _downloadTotalBytes = 0;
        _downloadReceivedBytes = 0;
        _downloadRemainingBytes = 0;
        _downloadSampleAt = null;
        _downloadSpeedBps = 0;
      }
      if (progress != null) {
        if (speedBps != null) {
          // The Android foreground service is authoritative: adopt its speed
          // and remaining-byte estimate verbatim so the app matches the
          // notification instead of re-smoothing a second, offset window.
          if (totalBytes != null && totalBytes > 0) {
            _downloadTotalBytes = totalBytes;
          }
          _downloadReceivedBytes =
              progress.clamp(0.0, 1.0) * _downloadTotalBytes;
          _downloadRemainingBytes = remainingBytes ?? 0;
          _downloadSpeedBps = speedBps;
          _downloadSampleAt = null;
        } else {
          _trackDownloadSpeed(progress, totalBytes);
        }
      }
    }
    final nextProgress = phase == InferencePhase.downloading ? progress : null;
    if (_phase == phase &&
        _status == status &&
        _downloadProgress == nextProgress) {
      return;
    }
    _phase = phase;
    _status = status;
    _statusKey = key;
    _downloadProgress = nextProgress;
    notifyListeners();
  }

  /// Maintains a smoothed bytes-per-second estimate so the install card can
  /// show live speed and a rough time remaining.
  void _trackDownloadSpeed(double progress, int? totalBytes) {
    if (totalBytes != null && totalBytes > 0) {
      _downloadTotalBytes = totalBytes;
    }
    final total = _downloadTotalBytes;
    if (total <= 0) return;
    final received = progress.clamp(0.0, 1.0) * total;
    final now = DateTime.now();
    final sampleAt = _downloadSampleAt;
    if (sampleAt == null || received < _downloadReceivedBytes) {
      _downloadSampleAt = now;
      _downloadReceivedBytes = received;
      return;
    }
    final elapsed = now.difference(sampleAt).inMicroseconds / 1e6;
    if (elapsed < 0.3) return;
    final deltaBytes = received - _downloadReceivedBytes;
    final instant = deltaBytes / elapsed;
    _downloadSpeedBps = _downloadSpeedBps <= 0
        ? instant
        : _downloadSpeedBps * 0.65 + instant * 0.35;
    _downloadSampleAt = now;
    _downloadReceivedBytes = received;
  }

  String _friendlyError(Object error) {
    debugPrint('FINN_RAW_ERROR $error');
    final text = error.toString();
    final lower = text.toLowerCase();
    if (text.contains('Unable to resolve host') ||
        lower.contains('resolve host') ||
        lower.contains('no address associated with hostname') ||
        lower.contains('unknownhostexception') ||
        lower.contains('name or service not known')) {
      return 'Couldn\'t reach the model server. Check your internet or Wi-Fi and retry.';
    }
    if (text.contains('SocketException') || text.contains('HttpException')) {
      return 'Could not download the model. Check your connection.';
    }
    if (text.contains('LlamaDecodeException') ||
        text.contains('LlamaContextException') ||
        lower.contains('context full') ||
        lower.contains('decode failed') ||
        lower.contains('prefill decode failed') ||
        lower.contains('cannot shift')) {
      return 'This chat got too long for this device. Start a new chat or shorten your message.';
    }
    if (text.contains('LlamaModelLoadException') ||
        lower.contains('failed to load model') ||
        lower.contains('load_model')) {
      return 'The AI model couldn\'t load on this device. Try again, or remove and re-download the model.';
    }
    if (text.toLowerCase().contains('memory') || text.contains('alloc')) {
      return 'Not enough free memory. Close other apps and try again.';
    }
    if (text.toLowerCase().contains('storage') ||
        text.toLowerCase().contains('space')) {
      return 'Not enough free storage to download this model.';
    }
    if (!Platform.isAndroid && !Platform.isLinux) {
      return 'Local inference is available in the mobile build.';
    }
    return 'The local model could not start on this device.';
  }
}

Future<bool> _looksLikeGgufFile(File file) async {
  if (!await file.exists() || await file.length() < 4) return false;
  final handle = await file.open();
  try {
    final magic = await handle.read(4);
    return magic.length == 4 &&
        magic[0] == 0x47 &&
        magic[1] == 0x47 &&
        magic[2] == 0x55 &&
        magic[3] == 0x46;
  } finally {
    await handle.close();
  }
}

/// Promotes a complete resumable download without making another network
/// request.
///
/// A process can be killed after the final byte is flushed but before the
/// `.part` file is renamed. Treating that state as another range request
/// causes some CDNs to return an unsatisfiable range response. The exact byte
/// count enforced by the transfer is the integrity gate here, and callers
/// verify the GGUF magic right after promotion. Full-file SHA-256 is
/// deliberately skipped because it made the post-download "Verifying" step
/// take tens of seconds on budget devices.
@visibleForTesting
Future<bool> promoteVerifiedModelPartial({
  required File partial,
  required File target,
  required int expectedBytes,
}) async {
  if (!await partial.exists() || await partial.length() != expectedBytes) {
    return false;
  }
  if (await target.exists()) await target.delete();
  await partial.rename(target.path);
  if (!await _looksLikeGgufFile(target)) {
    await target.delete();
    return false;
  }
  return true;
}

typedef FinnEngine = FinnAccelerator;
typedef FinnInference = FinnAccelerator;

/// Bounded FIFO turn gate for queued generations (see
/// [FinnAccelerator.generateReplyQueued]).
///
/// [waitTurn] reserves a place in line and resolves when [signalNext] hands
/// the turn over (the engine became free). Reservations are capped at
/// [capacity]; beyond that [waitTurn] throws [StateError] so callers get a
/// clear failure instead of unbounded queue growth. A waiter that gives up
/// before its turn arrives calls [abandon] to restore capacity; abandoning
/// after the turn was granted is a no-op.
@visibleForTesting
class ReplyTurnGate {
  ReplyTurnGate({this.capacity = 2});

  /// Maximum number of callers that can wait at once.
  final int capacity;

  final List<Completer<void>> _waiters = [];

  /// Number of callers currently waiting for their turn.
  int get waitingCount => _waiters.length;

  /// Reserves a place in line; resolves when the turn is granted.
  Future<void> waitTurn() {
    if (_waiters.length >= capacity) {
      throw StateError(
        'Finn already has $capacity queued generations; '
        'try again when the current answer finishes.',
      );
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  /// Gives up a reserved [turn] that was not granted yet (no-op afterwards).
  void abandon(Future<void> turn) {
    _waiters.removeWhere((completer) => identical(completer.future, turn));
  }

  /// Hands the engine to the oldest waiter, if any.
  void signalNext() {
    if (_waiters.isEmpty) return;
    _waiters.removeAt(0).complete();
  }
}
