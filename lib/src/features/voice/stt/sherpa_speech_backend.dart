import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:finn_ai/src/features/voice/stt/audio_math.dart';
import 'package:finn_ai/src/features/voice/stt/mic_source.dart';
import 'package:finn_ai/src/features/voice/stt/speech_backend.dart';
import 'package:finn_ai/src/features/voice/stt/stt_events.dart';
import 'package:finn_ai/src/features/voice/stt/stt_model_store.dart';
import 'package:finn_ai/src/features/voice/stt/stt_worker.dart';

/// Speech recognition that never leaves the device and never asks the
/// platform for a recogniser: the microphone feeds a voice activity detector,
/// which cuts the stream into utterances, and Whisper transcribes each one.
///
/// Whisper is not a streaming model, so there are no partial words: the
/// result arrives once, shortly after the speaker stops.
class SherpaSpeechBackend implements SpeechBackend {
  SherpaSpeechBackend({
    SttModelStore? store,
    MicSource Function()? micFactory,
    Future<SpeechWorker> Function(SttModelPaths paths)? spawnWorker,
    this.noSpeechTimeout = const Duration(seconds: 10),
    this.maxSession = const Duration(seconds: 60),
  })  : _store = store ?? SttModelStore.instance,
        _micFactory = micFactory ?? RecordMicSource.new,
        _spawnWorker = spawnWorker ?? SttWorker.spawn;

  /// How long to wait for the first word before giving up quietly.
  final Duration noSpeechTimeout;

  /// A session ends by itself at this length, so a hot mic is never left open.
  final Duration maxSession;

  final SttModelStore _store;
  final MicSource Function() _micFactory;
  MicSource? _mic;
  final Future<SpeechWorker> Function(SttModelPaths paths) _spawnWorker;

  void Function(SpeechFailure failure)? _onFailure;
  SpeechWorker? _worker;
  Future<SpeechWorker>? _loading;
  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription<SttEvent>? _eventSub;

  // One listen session.
  bool _listening = false;
  int _session = 0;
  void Function(SpeechResult result)? _onResult;
  final StringBuffer _heard = StringBuffer();
  bool _speechSeen = false;
  String? _heardLanguage;
  bool _finishing = false;
  Timer? _noSpeechTimer;
  Timer? _maxTimer;
  final List<Float32List> _pending = [];
  Stopwatch? _sinceStop;

  /// Resets sent to the worker whose acknowledgement has not come back. Events
  /// that arrive before it were produced for a session that is already over —
  /// a decode still running when the user cancelled — and must not leak into
  /// the next one.
  int _resetsPending = 0;

  @override
  ValueListenable<SpeechModelStatus> get model => _store.status;

  @override
  bool get isListening => _listening;

  @override
  Future<SpeechInit> initialize({
    void Function(SpeechFailure failure)? onFailure,
  }) async {
    _onFailure = onFailure;
    try {
      // `hasPermission` asks when it has not been asked, so this is also the
      // permission prompt rather than a side effect of the first recording.
      if (!await (_mic ??= _micFactory()).hasPermission()) {
        return SpeechInit.micDenied;
      }
      await _store.refresh();
      return await _store.isInstalled()
          ? SpeechInit.ready
          : SpeechInit.needsModel;
    } catch (error) {
      debugPrint('FINN_STT init failed: $error');
      return SpeechInit.unavailable;
    }
  }

  @override
  Future<void> downloadModel() => _store.download();

  @override
  Future<void> listen({
    void Function(SpeechResult result)? onResult,
    void Function(double level)? onSoundLevelChange,
  }) async {
    await _endSession(discard: true);
    final session = ++_session;
    _onResult = onResult;
    _heard.clear();
    _pending.clear();
    _speechSeen = false;
    _heardLanguage = null;
    _finishing = false;
    _sinceStop = null;

    final recorder = _mic ??= _micFactory();
    final Stream<Uint8List> mic;
    try {
      mic = await recorder.start();
    } catch (error) {
      debugPrint('FINN_STT mic failed: $error');
      throw StateError('microphone unavailable');
    }
    _listening = true;
    _micSub = mic.listen((bytes) {
      if (session != _session || _finishing) return;
      final samples = pcm16ToFloat32(bytes);
      onSoundLevelChange?.call(soundLevelOf(samples));
      final worker = _worker;
      if (worker == null) {
        // The models are still loading. Keep the audio rather than lose the
        // first words of the question.
        _pending.add(samples);
      } else {
        worker.feed(samples);
      }
    });
    _noSpeechTimer = Timer(noSpeechTimeout, () {
      if (session == _session && !_speechSeen) {
        _fail(const SpeechFailure(SpeechFailureKind.noSpeech));
      }
    });
    _maxTimer = Timer(maxSession, () {
      if (session == _session) unawaited(stop());
    });
    unawaited(_attachWorker(session));
  }

  Future<void> _attachWorker(int session) async {
    try {
      final worker = await _loadWorker();
      // Kept even if the session ended meanwhile: the next one reuses it and
      // `release` frees it. Dropping it here would leak a loaded model.
      _worker = worker;
      if (session != _session || !_listening) return;
      _eventSub ??= worker.events.listen(_onEvent);
      for (final chunk in _pending) {
        worker.feed(chunk);
      }
      _pending.clear();
      // A stop that landed while the models were loading was waiting on us.
      if (_finishing) worker.flush();
    } catch (error) {
      debugPrint('FINN_STT worker failed: $error');
      if (session == _session) {
        _fail(SpeechFailure(SpeechFailureKind.unavailable, '$error'));
      }
    }
  }

  Future<SpeechWorker> _loadWorker() {
    final existing = _worker;
    if (existing != null) return Future.value(existing);
    return _loading ??= () async {
      final paths = await _store.paths();
      if (paths == null) throw StateError('speech model is not installed');
      final watch = Stopwatch()..start();
      final worker = await _spawnWorker(paths);
      debugPrint('FINN_STT load_ms=${watch.elapsedMilliseconds}');
      return worker;
    }()
      ..whenComplete(() => _loading = null).ignore();
  }

  void _onEvent(SttEvent event) {
    if (event is SttResetDone) {
      if (_resetsPending > 0) _resetsPending--;
      return;
    }
    if (_resetsPending > 0) return;
    switch (event) {
      case SttSpeechStarted():
        _speechSeen = true;
        _noSpeechTimer?.cancel();
      case SttSegment():
        debugPrint(
          'FINN_STT decode_ms=${event.millis} lang=${event.language}',
        );
        final language = event.language?.trim();
        if (event.text.isNotEmpty && language != null && language.isNotEmpty) {
          _heardLanguage = language;
        }
        if (event.text.isNotEmpty) {
          if (_heard.isNotEmpty) _heard.write(' ');
          _heard.write(event.text);
        }
        // The detector cut a very long stretch while the speaker carried on.
        if (!event.more && !_finishing) unawaited(stop());
      case SttFlushed():
        _deliver();
      case SttResetDone():
        break;
      case SttFailed():
        // A worker that has thrown is not trusted again; the next session
        // loads a fresh one.
        unawaited(_dropWorker());
        _fail(SpeechFailure(SpeechFailureKind.unavailable, event.message));
    }
  }

  void _deliver() {
    if (!_listening) return;
    final onResult = _onResult;
    final words = _heard.toString().trim();
    final stopped = _sinceStop;
    if (stopped != null) {
      debugPrint('FINN_STT stop_to_text_ms=${stopped.elapsedMilliseconds}');
    }
    unawaited(_endSession(discard: false));
    onResult?.call(
      SpeechResult(words, isFinal: true, language: _heardLanguage),
    );
  }

  @override
  Future<void> stop() async {
    if (!_listening || _finishing) return;
    _finishing = true;
    _sinceStop = Stopwatch()..start();
    _noSpeechTimer?.cancel();
    _maxTimer?.cancel();
    await _stopMic();
    final worker = _worker;
    if (worker != null) {
      worker.flush();
    } else if (_pending.isEmpty) {
      // Stopped before the models loaded and before any audio: nothing to say.
      _deliver();
    }
    // Otherwise `_attachWorker` flushes once the models are up.
  }

  @override
  Future<void> cancel() => _endSession(discard: true);

  Future<void> _stopMic() async {
    await _micSub?.cancel();
    _micSub = null;
    try {
      await _mic?.stop();
    } catch (_) {}
  }

  Future<void> _endSession({required bool discard}) async {
    _noSpeechTimer?.cancel();
    _maxTimer?.cancel();
    final wasListening = _listening;
    _listening = false;
    _finishing = false;
    await _stopMic();
    _pending.clear();
    if (discard && wasListening) {
      _session++;
      final worker = _worker;
      if (worker != null) {
        _resetsPending++;
        worker.reset();
      }
    }
  }

  Future<void> _dropWorker() async {
    final worker = _worker;
    _worker = null;
    _resetsPending = 0;
    await _eventSub?.cancel();
    _eventSub = null;
    worker?.dispose();
  }

  void _fail(SpeechFailure failure) {
    final onFailure = _onFailure;
    unawaited(_endSession(discard: true));
    onFailure?.call(failure);
  }

  @override
  Future<void> release() async {
    await _endSession(discard: true);
    // A load still in flight would otherwise finish after this and leave a
    // model resident with nobody holding it.
    final loading = _loading;
    if (loading != null) {
      try {
        _worker ??= await loading;
      } catch (_) {}
    }
    await _dropWorker();
    final mic = _mic;
    _mic = null;
    try {
      await mic?.dispose();
    } catch (_) {}
  }
}
