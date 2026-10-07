import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:finn_ai/src/engine/backends/llama_shim.dart';
import 'package:finn_ai/src/engine/prompt/agent_prompt.dart';
import 'package:finn_ai/src/engine/prompt/bare_tool_call_filter.dart';
import 'package:finn_ai/src/engine/prompt/prompt_formatter.dart';
import 'package:finn_ai/src/engine/prompt/tool_tag_filter.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/engine/profiler/device_profile.dart';
import 'package:finn_ai/src/engine/profiler/model_tier_policy.dart';
import 'package:finn_ai/src/engine/metrics/perf_logging.dart';
import 'package:finn_ai/src/engine/metrics/ttft_metrics.dart';
import 'package:finn_ai/src/engine/policy/residency_policy.dart';
import 'package:finn_ai/src/engine/adaptive/adaptive.dart';
import 'package:finn_ai/src/engine/finn_engine_types.dart';
import 'package:finn_ai/src/engine/generate/loop_guard.dart';
import 'package:finn_ai/src/engine/prompt/prompt_intent.dart';
import 'package:finn_ai/src/engine/api/web_source.dart';

export 'package:finn_ai/src/engine/finn_engine_types.dart';

part 'install/install_lifecycle.dart';
part 'install/model_tier.dart';
part 'loader/residency.dart';
part 'loader/projector.dart';
part 'generate/reply_api.dart';
part 'generate/turn.dart';
part 'generate/cancellation.dart';
part 'loader/device_optimizer.dart';
part 'download/artifact.dart';
part 'download/service_download.dart';
part 'download/dart_download.dart';
part 'loader/model_loader.dart';
part 'session/session_prep.dart';
part 'generate/prompt_render.dart';
part 'loader/model_files.dart';
part 'download/progress.dart';
part 'download/model_artifacts.dart';
part 'session/session_key.dart';
part 'generate/reply_gate.dart';
part 'generate/empty_reply_retry.dart';

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
  bool taskPrefixReady = false; // the restored state holds the task block too
  String? lastTaskInstruction;
  int lastUsed;

  /// Tokens of the cached prefix (base, plus the task block when cached) at
  /// the start of the KV cache: what a context shift must keep. Measured, not
  /// assumed: it depends on the model's tokenizer. 0 when unknown.
  int basePrefixTokens = 0;

  /// For an agent session ([AgentPrompt]): what the KV cache holds, so the
  /// next step can be appended instead of re-reading the conversation.
  String? agentHistoryKey;
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

  FinnAccelerator._();

  static final FinnAccelerator instance = FinnAccelerator._();

  /// Sources attached to the last completed answer (from web search), or
  /// empty when the answer did not use the web.
  List<WebSource> _lastSources = const [];
  List<WebSource> get lastSources => _lastSources;

  static const continuationPrompt =
      'Continue exactly where the previous response stopped. Do not repeat '
      'the introduction or completed sections. Finish the requested answer '
      'in the same language and format.';
  static const systemPromptVersion = 12;
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

  /// Suffixes that belong to an installed model file and must go when it does.
  ///
  /// `''` is the GGUF itself, `.part` an interrupted download, and
  /// `.finn_repack` the repacked-weight disk cache the vendored native build
  /// writes next to the model (see `tool/llama_android_native.patch`; ~693MB
  /// on the 1.6B, which "Delete All Local Data" used to leave behind).
  static const modelFileSuffixes = <String>['', '.part', '.finn_repack'];

  FinnModelSpec _selected = finnModels.first;
  FinnModelSpec get selected => _selected;

  /// Only the selected tier is ever downloaded.
  List<FinnModelSpec> get requiredModels => [_selected];

  /// The vision projector that belongs to the selected tier.
  FinnModelArtifact get activeProjector => _selected.projector ?? finnMmproj;

  /// What [ModelTierPolicy] recommends for this device; set by [initialize].
  FinnModelTier _recommendedTier = FinnModelTier.standard;

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
  /// Bytes fully downloaded so far in the current install run.
  /// Bytes still to download in the current install run.
  /// Bytes-per-second for the active download; 0 when idle. On Android this is
  /// the foreground service's own estimate, so it matches the notification.
  /// Rough time remaining for the active download; null when unknown or idle.
  /// Human-readable transfer speed for the active download; null when the
  /// estimate is not ready yet. Shared by the install card and settings card.
  /// Human-readable time remaining for the active download; null when the
  /// estimate is not ready yet.
  /// Test hook: simulates a download progress tick so the speed/ETA math can
  /// be verified without a real network transfer.
  /// Test hook: returns the download phase to idle after simulated progress.
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

  /// Idle stall budget for the pure-Dart (non-Android) downloads: when no
  /// bytes arrive on a range/stream for this long, the attempt is aborted and
  /// retried from the persisted offset instead of hanging forever with a
  /// frozen progress bar. The Android path has its own stall detector in the
  /// foreground service; the Dart path previously had none, so one wedged
  /// TCP stream (common with many parallel ranges through emulator NAT or a
  /// throttling CDN) froze the whole transfer with no error and no recovery.
  static const Duration _dartDownloadIdleTimeout = Duration(seconds: 25);

  /// Bounded attempts per range/stream before a stalled transfer surfaces as
  /// a real error (with Retry in the UI) instead of retrying forever.
  static const int _dartDownloadMaxAttempts = 5;

  /// HttpClients with in-flight download reads, so [pauseDownload] can abort
  /// them even when no bytes are arriving to observe the cancel flag.
  final Set<HttpClient> _activeDownloadClients = <HttpClient>{};
  bool _benchmarkRunning = false;

  /// Set when an image arrives on a Lite device, so the next (re)load brings
  /// the projector in. Cleared when the runtime is released.
  bool _projectorRequested = false;
  final Set<FinnModelTier> _verifiedModels = <FinnModelTier>{};
  Future<Directory>? _modelDirectoryJob;

  /// Resumes a partially-downloaded required model after an app restart,
  /// without waiting for the user to reach the install screen again. Only a
  /// model that already has bytes on disk is resumed, so a fresh install never
  /// starts a surprise download. install() is idempotent, so this also no-ops
  /// if the same model is already being installed by the onboarding flow.
  /// Resumes an interrupted multimodal-component transfer after an app restart.
  ///
  /// The projector is the second and larger artifact (≈854 MB), so a process
  /// kill during setup most often lands mid-projector. It is not required for
  /// text chat, so `_runInstall` tolerates its absence — which means without
  /// this hook the app would start normally, report the model as installed, and
  /// leave vision permanently unavailable while the `.part` file sat unused.
  /// Only a partial that already has bytes on disk is resumed, so a fresh
  /// install never starts a surprise download.
  /// Records a fully-downloaded artifact in the aggregate install progress so
  /// the next artifact's bytes count on top of it instead of restarting the
  /// bar at zero.
  /// Stops an in-flight install before its files are deleted.
  ///
  /// Without this, the Android foreground service keeps writing to
  /// `<target>.part` and can rename it into place *after* the removal, which
  /// resurrected the supposedly erased model (and projector) during
  /// "Delete All Local Data" — silently breaking the data-sovereignty promise.
  /// The in-flight job is awaited so its transfer loop has exited before the
  /// files are unlinked.
  /// Maps the recommended/default model. Direct Plus requests therefore reuse
  /// this exact load instead of first paying for an unrelated Lite engine.
  /// Releases the large native context when the app leaves the foreground.
  /// Also drops the cached device profile: after a resume the first turn
  /// must observe fresh memory/storage values.
  /// Memory-pressure order: inactive sessions, active sessions, secondary
  /// engines, and finally the selected/default engine.
  /// Removes the downloaded projector separately from the language model.
  /// Vision is not exposed by this release, but data deletion must still
  /// remove the reserved artifact if it was installed.
  FinnModelSpec? _lastGeneratingModel;
  FinnModelSpec get lastGeneratingModel => _lastGeneratingModel ?? selected;
  GenerationReport? _lastGenerationReport;
  GenerationReport? get lastGenerationReport => _lastGenerationReport;

  /// The context window the current engine plan was built with.
  ///
  /// 2048 and 4096 are both shipped depending on the device class, and the
  /// same prompt produces different answers at each, so every quality baseline
  /// has to record which one it ran at (see `eval/`).
  int get contextSize => _plan?.contextSize ?? 2048;

  /// Generates a reply for [prompt].
  ///
  /// [samplerProfile] overrides the sampler that would otherwise be derived from
  /// the prompt's classified intent. Secondary callers such as the creation
  /// pipeline use it to ask for near-deterministic decoding when the output has
  /// to parse as JSON; chat passes `null` and is unaffected.
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
  /// Quarantines a generator that did not acknowledge cancellation promptly.
  ///
  /// [LlamaEngine.dispose] closes its streams and kills the worker isolate
  /// after its own bounded two-second shutdown handshake. The runtime map is
  /// cleared before awaiting disposal, so stale sessions cannot be reused.
  /// Clears the in-flight generation state after a native error so the app
  /// never stays stuck on the failed task.
  ///
  /// A decode or context-overflow failure leaves the affected session's KV
  /// cache in an unknown (usually full) state, so conversation sessions are
  /// dropped. The loaded engines stay resident and the next request simply
  /// re-primes the shared prefix. The friendly error status is intentionally
  /// left in place for the controller to surface on the failed message.
  /// One-time, post-download benchmark that measures every available backend
  /// and caches the fastest one. Runs the CPU baseline first so the app always
  /// has a working engine even if every accelerator candidate fails.
  ///
  /// Callers surface the work through the normal [status] listener: the phase
  /// is [InferencePhase.loading] and the status reads
  /// "Setting up FinnAI for optimal performance…".
  /// True when the benchmark should run again: no valid cached backend
  /// selection exists for this device, model, and app build (e.g. after an
  /// app update that changed the runtime).
  /// Verifies an already-promoted [target] and deletes it when the digest does
  /// not match. Without the delete, a right-sized-but-corrupt artifact would be
  /// accepted as installed by [_isVerifiedModelFile] (size + GGUF magic only)
  /// on every later run and could never be re-downloaded, so the app would
  /// silently keep loading a corrupt model forever.
  /// Number of parallel HTTP range segments for non-Android downloads.
  /// The Android path uses the foreground service's own segment count; this
  /// keeps desktop/macOS model + projector transfers fast too. Sixteen
  /// segments keeps high-latency and lossy links saturated the way the
  /// Android foreground service does.
  static const int dartDownloadSegments = 16;

  /// Single-stream (non-range) fallback for [ _ensureArtifactDart].
  ///
  /// Transient stalls are retried with an idle watchdog: when no bytes arrive
  /// for [_dartDownloadIdleTimeout] the attempt is aborted and resumed from
  /// the persisted prefix, so a wedged connection surfaces as progress or —
  /// after [_dartDownloadMaxAttempts] — as a real error instead of a bar
  /// frozen forever.
  /// Parallel HTTP-range downloader used by the non-Android path.
  ///
  /// Splits [total] bytes into [dartDownloadSegments] ranges fetched
  /// concurrently (the same strategy the Android foreground service uses).
  /// Each range accumulates sequentially into its own `${partial.path}.r$index`
  /// file; when every range file is complete they are concatenated into
  /// [partial] in order. Per-range files (instead of positional writes into
  /// one shared file) make resume safe: no open mode truncates another
  /// range's bytes, and a retried range always re-requests from its own
  /// persisted offset, so bytes can never land misaligned.
  ///
  /// Every range attempt carries an idle watchdog: when no bytes arrive for
  /// [_dartDownloadIdleTimeout] the attempt is aborted and retried, so a
  /// stalled stream surfaces as progress or — after
  /// [_dartDownloadMaxAttempts] — as a real error, never a frozen bar.
  /// Copies a legacy contiguous `.part` prefix into per-range files so an
  /// in-flight download from before the per-range layout resumes instead of
  /// restarting. Ranges that already have content are left untouched.
  /// Human-readable adaptive engine diagnostics (device, model, backends,
  /// benchmarks, selected config, reason).
  /// The adaptive engine's current device profile.
  /// The cached adaptive benchmark profile (null before the first run).
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

  /// Bounds cold/reopened-chat prefill. Live chats still retain their KV cache
  /// between turns; restored chats replay only the newest useful context.
  /// True when the reserved post-model artifact is downloaded. The transfer
  /// enforces the exact byte count, so size is the integrity gate here;
  /// full-file SHA-256 was dropped to keep verification fast on budget devices.
  /// Lightweight existence check (no SHA) for UI toast path.
  /// Downloads and verifies the reserved LFM2.5-VL projector artifact. It is
  /// intentionally not passed to llama.cpp until a later vision release.
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
}

typedef FinnEngine = FinnAccelerator;
typedef FinnInference = FinnAccelerator;
