import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/voice/tts/pcm_output.dart';
import 'package:finn_ai/src/features/voice/tts/tts_events.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_catalog.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_store.dart';
import 'package:finn_ai/src/features/voice/tts/supertonic_worker.dart';
import 'package:finn_ai/src/features/voice/tts_backend.dart';
import 'package:finn_ai/src/features/voice/voice_settings_store.dart';

/// Thrown by [LocalTtsBackend.speak] when no voice is installed.
class NoVoiceException implements Exception {
  const NoVoiceException();

  @override
  String toString() => 'no text-to-speech voice is installed';
}

class _Utterance {
  _Utterance(this.id);

  final int id;
  bool synthDone = false;

  /// Where this utterance ends in the stream of queued frames. Known once its
  /// synthesis is done.
  int endFrame = 0;
}

/// Speaks with the on-device voice and no platform engine.
///
/// Sentences are synthesised one after another on a worker isolate and their
/// audio is fed to the speaker as it arrives, so the first sentence is
/// audible while the second is still being made. What is playing is tracked in
/// frames, which gives both "this sentence has finished" and the loudness of
/// the moment, for the voice animation.
class LocalTtsBackend implements TtsBackend {
  LocalTtsBackend({
    TtsVoiceStore? store,
    PcmOutput? output,
    Future<TtsEngine> Function(TtsVoicePaths paths)? spawn,
    String Function()? styleOf,
    this.tick = const Duration(milliseconds: 40),
  })  : _store = store ?? TtsVoiceStore.instance,
        _output = output ?? PcmSoundOutput(),
        _spawn = spawn ?? SupertonicWorker.spawn,
        _styleOf = styleOf ?? _settingsStyle;

  /// How often playback progress and loudness are sampled.
  final Duration tick;

  final TtsVoiceStore _store;
  final PcmOutput _output;
  final Future<TtsEngine> Function(TtsVoicePaths paths) _spawn;

  /// Where each utterance's speaking style comes from, read live so a change
  /// in settings takes effect without reloading the voice.
  final String Function() _styleOf;

  static String _settingsStyle() => VoiceSettingsStore.instance.ttsStyle;

  VoidCallback? _onStart;
  VoidCallback? _onComplete;
  VoidCallback? _onCancel;
  void Function(dynamic message)? _onError;

  @override
  final ValueNotifier<double> level = ValueNotifier(0);

  String? _language;
  double _speed = 1.0;

  TtsEngine? _engine;
  TtsVoice? _engineVoice;
  Future<TtsEngine>? _loading;
  StreamSubscription<TtsEvent>? _events;

  int _nextId = 1;
  final List<_Utterance> _queue = [];
  bool _active = false;
  Timer? _ticker;

  // Playback accounting. `_totalFed` counts every frame handed to the speaker
  // since the last stop; `_levels` holds one loudness value per window of it.
  int _totalFed = 0;
  int? _rate;
  final List<double> _levels = [];

  /// Whether some installed voice could speak [language] (or the default).
  Future<bool> canSpeak(String? language) async =>
      await _pickVoice(language) != null;

  Future<TtsVoice?> _pickVoice(String? language) async {
    final wanted = ttsVoiceFor(language);
    if (wanted != null && await _store.isInstalled(wanted)) return wanted;
    // The English voice reads any Latin-script reply tolerably; it cannot read
    // Cyrillic or Devanagari at all.
    if (ttsNonLatinLanguages.contains(normalizeLanguage(language))) return null;
    if (await _store.isInstalled(defaultTtsVoice)) return defaultTtsVoice;
    return null;
  }

  @override
  Future<void> initialize({
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onCancel,
    void Function(dynamic message)? onError,
  }) async {
    _onStart = onStart;
    _onComplete = onComplete;
    _onCancel = onCancel;
    _onError = onError;
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    // The settings speeds are flutter_tts rates (.32/.45/.6); 0.45 is normal.
    _speed = (1 + (rate - 0.45) * 1.4).clamp(0.8, 1.3);
  }

  @override
  Future<void> setQueueAdd() async {}

  @override
  Future<void> setLanguage(String? language) async {
    _language = normalizeLanguage(language);
  }

  @override
  Future<void> prepare() async {
    final voice = await _pickVoice(_language);
    if (voice == null) return;
    try {
      await _engineFor(voice);
    } catch (error) {
      debugPrint('FINN_TTS prepare failed: $error');
    }
  }

  @override
  Future<void> speak(String text) async {
    final voice = await _pickVoice(_language);
    if (voice == null) throw const NoVoiceException();
    final utterance = _Utterance(_nextId++);
    _queue.add(utterance);
    try {
      final engine = await _engineFor(voice);
      // The queue may have been stopped while the voice was loading.
      if (!_queue.contains(utterance)) return;
      engine.synth(utterance.id, text, _speed,
          language: _language, style: _styleOf());
    } catch (error) {
      _queue.remove(utterance);
      rethrow;
    }
  }

  Future<TtsEngine> _engineFor(TtsVoice voice) async {
    final current = _engine;
    if (current != null && _engineVoice == voice) return current;
    if (_loading != null && _engineVoice == voice) return _loading!;
    // A different voice is only loaded between turns: swapping it mid-speech
    // would cut the sentence being heard.
    if (current != null && _queue.length > 1) return current;
    _disposeEngine();
    _engineVoice = voice;
    final load = _loading = () async {
      final paths = await _store.paths(voice);
      if (paths == null) throw const NoVoiceException();
      final watch = Stopwatch()..start();
      final engine = await _spawn(paths);
      debugPrint('FINN_TTS load_ms=${watch.elapsedMilliseconds} ${voice.id}');
      // The voice was changed (or the backend released) while this loaded.
      if (_engineVoice != voice) {
        engine.dispose();
        throw StateError('voice changed while loading');
      }
      _engine = engine;
      _events = engine.events.listen(_onEvent);
      return engine;
    }();
    load.whenComplete(() => _loading = null).ignore();
    return load;
  }

  void _onEvent(TtsEvent event) {
    switch (event) {
      case TtsChunk():
        final known = _queue.any((u) => u.id == event.id);
        if (!known) return;
        unawaited(_feed(event));
      case TtsSynthDone():
        final utterance = _find(event.id);
        if (utterance == null) return;
        if (event.audioMillis > 0) {
          debugPrint(
            'FINN_TTS synth_ms=${event.millis} audio_ms=${event.audioMillis} '
            'rtf=${(event.millis / event.audioMillis).toStringAsFixed(2)}',
          );
        }
        utterance
          ..synthDone = true
          ..endFrame = _totalFed;
        _ensureTicker();
      case TtsFailed():
        debugPrint('FINN_TTS failed: ${event.message}');
        final id = event.id;
        final utterance = id == null ? null : _find(id);
        if (utterance != null) {
          utterance
            ..synthDone = true
            ..endFrame = _totalFed;
          _ensureTicker();
        }
        _onError?.call(event.message);
    }
  }

  _Utterance? _find(int id) {
    for (final u in _queue) {
      if (u.id == id) return u;
    }
    return null;
  }

  Future<void> _feed(TtsChunk chunk) async {
    if (chunk.samples.isEmpty) return;
    // A new sample rate (another voice) cannot share the speaker's buffer, so
    // the sentence before it is allowed to finish first.
    if (_rate != null && _rate != chunk.sampleRate) {
      while (_output.remainingFrames > 0 && _queue.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await _output.stop();
      _totalFed = 0;
      _levels.clear();
    }
    _rate = chunk.sampleRate;
    if (!_active) {
      _active = true;
      _onStart?.call();
    }
    _recordLevels(chunk.samples, chunk.sampleRate);
    _totalFed += chunk.samples.length;
    // Counted before the await so a completion check sees these frames.
    for (final u in _queue) {
      if (u.id == chunk.id && u.synthDone) u.endFrame = _totalFed;
    }
    await _output.feed(chunk.samples, chunk.sampleRate);
    _ensureTicker();
  }

  /// One RMS value per 50 ms of audio, indexed by position in the stream.
  void _recordLevels(Float32List samples, int rate) {
    final window = rate ~/ 20;
    for (var start = 0; start < samples.length; start += window) {
      final end = math.min(start + window, samples.length);
      var sum = 0.0;
      for (var i = start; i < end; i++) {
        sum += samples[i] * samples[i];
      }
      final rms = math.sqrt(sum / (end - start));
      // Speech sits around 0.05-0.2 RMS; stretch it over the whole range.
      _levels.add((rms * 5).clamp(0.0, 1.0));
    }
  }

  void _ensureTicker() {
    _ticker ??= Timer.periodic(tick, (_) => _onTick());
  }

  void _onTick() {
    final rate = _rate;
    final played = _totalFed - _output.remainingFrames;
    if (rate != null && _levels.isNotEmpty) {
      final index = (played * 20 ~/ rate).clamp(0, _levels.length - 1);
      level.value = _output.remainingFrames > 0 ? _levels[index] : 0;
    }
    // Retire sentences in order as their last frame is heard.
    while (_queue.isNotEmpty) {
      final head = _queue.first;
      if (!head.synthDone || played < head.endFrame) break;
      _queue.removeAt(0);
      _onComplete?.call();
    }
    if (_queue.isEmpty) {
      _ticker?.cancel();
      _ticker = null;
      level.value = 0;
      _active = false;
      _levels.clear();
      _totalFed = 0;
    }
  }

  @override
  Future<void> stop() async {
    final wasActive = _active || _queue.isNotEmpty;
    _queue.clear();
    _ticker?.cancel();
    _ticker = null;
    _engine?.cancelAll();
    await _output.stop();
    _totalFed = 0;
    _levels.clear();
    _rate = null;
    level.value = 0;
    _active = false;
    if (wasActive) _onCancel?.call();
  }

  void _disposeEngine() {
    _events?.cancel();
    _events = null;
    _engine?.dispose();
    _engine = null;
    _loading = null;
  }

  @override
  Future<void> release() async {
    await stop();
    final loading = _loading;
    if (loading != null) {
      try {
        await loading;
      } catch (_) {}
    }
    _disposeEngine();
    _engineVoice = null;
  }
}
