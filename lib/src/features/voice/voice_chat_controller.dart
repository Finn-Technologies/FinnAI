import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:finn_ai/src/features/voice/speakable_text.dart';
import 'package:finn_ai/src/features/voice/voice_settings_store.dart';

enum VoiceChatState { idle, listening, thinking, speaking }

enum VoiceChatError { none, micDenied, unavailable }

const double voiceSpeechRate = 0.45;

/// Whether the last listen session heard anything.
///
/// A state the UI can show, not an error: the recogniser finished cleanly and
/// there was nothing in the microphone. Without it, "the mic worked but caught
/// nothing" and "the user cancelled" were the same screen — the status line
/// simply reverted to "tap to speak". The sheet shows it and offers a retry.
enum VoiceListenOutcome { none, heardNothing }

extension VoiceListenOutcomeX on VoiceListenOutcome {
  bool get didCatchNothing => this == VoiceListenOutcome.heardNothing;
}

abstract class SpeechBackend {
  Future<bool> initialize({
    void Function(SpeechRecognitionError error)? onError,
    void Function(String status)? onStatus,
  });
  Future<bool> get hasPermission;
  bool get isListening;
  Future<void> listen({
    void Function(SpeechRecognitionResult result)? onResult,
    void Function(double level)? onSoundLevelChange,
    bool preferOnDevice = false,
  });
  Future<void> stop();
  Future<void> cancel();
}

class SpeechToTextBackend implements SpeechBackend {
  SpeechToTextBackend({SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  @override
  Future<bool> initialize({
    void Function(SpeechRecognitionError error)? onError,
    void Function(String status)? onStatus,
  }) =>
      _speech.initialize(
        onError: onError,
        onStatus: onStatus,
        options: [
          SpeechToText.androidIntentLookup,
          SpeechToText.androidNoBluetooth,
        ],
      );

  @override
  Future<bool> get hasPermission => _speech.hasPermission;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<void> listen({
    void Function(SpeechRecognitionResult result)? onResult,
    void Function(double level)? onSoundLevelChange,
    bool preferOnDevice = false,
  }) =>
      _speech.listen(
        onResult: onResult,
        onSoundLevelChange: onSoundLevelChange,
        listenOptions: SpeechListenOptions(
          onDevice: preferOnDevice,
          // Explicit rather than plugin defaults. The defaults are 60s and 3s,
          // and the 60s is a long time to hold the microphone open in a
          // foreground-only feature while the user thinks; 30s is past any
          // question anyone asks out loud. `pauseFor` is how long the engine
          // waits after a pause before finalising, so 1.2s stops it cutting
          // a speaker off mid-thought and still ends the turn promptly.
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(milliseconds: 1200),
          partialResults: true,
        ),
      );

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}

abstract class TtsBackend {
  Future<void> initialize({
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onCancel,
    void Function(dynamic message)? onError,
  });
  Future<void> setSpeechRate(double rate);
  Future<void> setQueueAdd();
  Future<void> speak(String text);
  Future<void> stop();
}

class FlutterTtsBackend implements TtsBackend {
  FlutterTtsBackend({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<void> initialize({
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onCancel,
    void Function(dynamic message)? onError,
  }) async {
    _tts.setStartHandler(onStart ?? () {});
    _tts.setCompletionHandler(onComplete ?? () {});
    _tts.setCancelHandler(onCancel ?? () {});
    if (onError != null) _tts.setErrorHandler(onError);
    await _tts.awaitSpeakCompletion(false);
    await _tts.setVolume(1.0);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final engines = await _tts.getEngines;
        if (engines is List && engines.contains('com.google.android.tts')) {
          await _tts.setEngine('com.google.android.tts');
        }
      } catch (_) {}
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      } catch (_) {}
    }
    try {
      final tag = PlatformDispatcher.instance.locale.toLanguageTag();
      if (await _tts.isLanguageAvailable(tag) == true) {
        await _tts.setLanguage(tag);
      }
    } catch (_) {}
    await setQueueAdd();
    await setSpeechRate(VoiceSettingsStore.instance.speed.rate);
  }

  @override
  Future<void> setSpeechRate(double rate) => _tts.setSpeechRate(rate);

  @override
  Future<void> setQueueAdd() => _tts.setQueueMode(1);

  @override
  Future<void> speak(String text) => _tts.speak(text, focus: true);

  @override
  Future<void> stop() => _tts.stop();
}

class VoiceChatController extends ChangeNotifier {
  VoiceChatController({
    SpeechBackend? speech,
    TtsBackend? tts,
    this.onTranscript,
  })  : _speech = speech ?? SpeechToTextBackend(),
        _tts = tts ?? FlutterTtsBackend();

  static final instance = VoiceChatController();

  final SpeechBackend _speech;
  final TtsBackend _tts;

  VoidCallback? _onStateChangedForTest;
  bool _spokenResponses = true;
  VoiceChatState _state = VoiceChatState.idle;
  VoiceChatError _error = VoiceChatError.none;
  String _transcript = '';
  double _soundLevel = 0;
  bool _sttAvailable = false;
  bool _ttsReady = false;
  bool _suppressNextFinal = false;
  bool _onDeviceOnly = false;
  Timer? _listenWatchdog;
  final StringBuffer _replyBuffer = StringBuffer();
  String _spokenUpTo = '';
  bool _replyStreamOpen = false;
  bool _replyCancelled = false;
  int _queuedUtterances = 0;

  /// What the last listen session produced. Cleared when a new session starts,
  /// so the "didn't catch that" line disappears the moment the user tries
  /// again rather than lingering over a successful attempt.
  VoiceListenOutcome _lastListenOutcome = VoiceListenOutcome.none;

  VoiceChatState get state => _state;
  VoiceChatError get error => _error;
  String get transcript => _transcript;
  double get soundLevel => _soundLevel;
  bool get spokenResponses => _spokenResponses;
  bool get active => _state != VoiceChatState.idle;

  /// True when the last listen finished without catching anything.
  bool get didNotCatchAnything => _lastListenOutcome.didCatchNothing;

  void Function(String text)? onTranscript;

  void setSpokenResponses(bool value) {
    _spokenResponses = value;
    notifyListeners();
  }

  Future<bool> ensureReady() async {
    if (_sttAvailable && _ttsReady) return true;
    if (!_sttAvailable) {
      try {
        _sttAvailable = await _speech.initialize(
          onError: _onSpeechError,
          onStatus: _onSpeechStatus,
        );
      } catch (_) {
        _sttAvailable = false;
      }
      if (!_sttAvailable) {
        try {
          final granted = await _speech.hasPermission;
          _error =
              granted ? VoiceChatError.unavailable : VoiceChatError.micDenied;
        } catch (_) {
          _error = VoiceChatError.unavailable;
        }
        notifyListeners();
      } else if (_error == VoiceChatError.unavailable ||
          _error == VoiceChatError.micDenied) {
        _error = VoiceChatError.none;
        notifyListeners();
      }
    }
    try {
      await _tts.initialize(
        onStart: _onTtsStart,
        onComplete: _onTtsUtteranceComplete,
        onCancel: _onTtsStop,
        onError: (_) => _onTtsStop(),
      );
      _ttsReady = true;
    } catch (_) {
      _ttsReady = false;
    }
    return _sttAvailable || _ttsReady;
  }

  Future<void> startListening() async {
    final ready = await ensureReady();
    if (!ready || !_sttAvailable) {
      if (_error == VoiceChatError.none) {
        _error = VoiceChatError.unavailable;
      }
      notifyListeners();
      return;
    }
    await stopSpeaking();
    _error = VoiceChatError.none;
    _transcript = '';
    _suppressNextFinal = false;
    _onDeviceOnly = true;
    // A fresh attempt clears the previous "didn't catch that", so the message
    // is about the last try rather than sticking to the user.
    _lastListenOutcome = VoiceListenOutcome.none;
    _lastSoundLevelAt = null;
    await _beginListening(preferOnDevice: true);
  }

  /// Starts a recognition session and arms the listen watchdog.
  ///
  /// [preferOnDevice] asks the platform for offline recognition; the caller
  /// falls back once without it when the platform cannot recognise offline.
  Future<void> _beginListening({required bool preferOnDevice}) async {
    try {
      await _speech.listen(
        preferOnDevice: preferOnDevice,
        onResult: _onSpeechResult,
        onSoundLevelChange: _onSoundLevel,
      );
    } catch (_) {
      _error = VoiceChatError.unavailable;
      _setState(VoiceChatState.idle);
      return;
    }
    _setState(VoiceChatState.listening);
    _listenWatchdog?.cancel();
    _listenWatchdog = Timer(const Duration(seconds: 60), () {
      if (_state == VoiceChatState.listening) stopListening();
    });
  }

  /// The sound level that drives the orb's breathing animation.
  ///
  /// `speech_to_text` reports an amplitude on every audio buffer — tens of
  /// times a second — and every one of those was a `notifyListeners()`. The
  /// sheet's `ListenableBuilder` wraps the whole page, so each frame rebuilt
  /// two nested `LayoutBuilder`s, a scroll view and three `AnimatedContainer`s,
  /// each restarting its own tween before it could finish. The visible result
  /// was a stutter, not a breath.
  ///
  /// Publishing at a frame-ish rate is enough: an animation cannot show more
  /// than the display can, and the sheet costs a full rebuild per publish.
  static const Duration _soundLevelInterval = Duration(milliseconds: 60);
  DateTime? _lastSoundLevelAt;

  void _onSoundLevel(double level) {
    final now = DateTime.now();
    final last = _lastSoundLevelAt;
    if (last != null && now.difference(last) < _soundLevelInterval) return;
    _lastSoundLevelAt = now;
    _soundLevel = level.clamp(0.0, 1.0);
    notifyListeners();
  }

  Future<void> stopListening() async {
    _listenWatchdog?.cancel();
    _listenWatchdog = null;
    try {
      if (_speech.isListening) await _speech.stop();
    } catch (_) {}
  }

  Future<void> cancelListening() async {
    _suppressNextFinal = true;
    _onDeviceOnly = false;
    _listenWatchdog?.cancel();
    _listenWatchdog = null;
    try {
      if (_speech.isListening) await _speech.cancel();
    } catch (_) {}
    _setState(VoiceChatState.idle);
  }

  void beginThinking() {
    _replyBuffer.clear();
    _spokenUpTo = '';
    _replyStreamOpen = true;
    _replyCancelled = false;
    _setState(VoiceChatState.thinking);
  }

  void speakReplyChunk(String fullResponseText) {
    if (!_replyStreamOpen) return;
    _replyBuffer
      ..clear()
      ..write(fullResponseText);
    if (!_spokenResponses) return;
    final pending = _nextSpeakableChunk();
    if (pending != null) _enqueueUtterance(pending);
  }

  void finishReply(String fullResponseText) {
    _replyBuffer
      ..clear()
      ..write(fullResponseText);
    _replyStreamOpen = false;
    if (!_spokenResponses || _replyCancelled) {
      _setState(VoiceChatState.idle);
      return;
    }
    final remainder = _unspeakableRemainder(fullResponseText).trim();
    if (remainder.isNotEmpty) {
      _enqueueUtterance(remainder);
    } else if (_queuedUtterances == 0) {
      _setState(VoiceChatState.idle);
    }
  }

  Future<void> interrupt() async {
    _replyStreamOpen = false;
    _replyCancelled = true;
    await stopSpeaking();
    if (_state == VoiceChatState.speaking ||
        _state == VoiceChatState.thinking) {
      _setState(VoiceChatState.idle);
    }
  }

  Future<void> stopSpeaking() async {
    _queuedUtterances = 0;
    try {
      if (_ttsReady) await _tts.stop();
    } catch (_) {}
  }

  /// Returns the controller to a clean slate.
  ///
  /// Called when the app is backgrounded (voice is foreground-only) and when
  /// the sheet is dismissed. Everything that could keep the microphone or the
  /// speaker busy is torn down here, because a partial reset is what left the
  /// orb frozen mid-animation on resume.
  Future<void> reset() async {
    _listenWatchdog?.cancel();
    _listenWatchdog = null;
    _replyStreamOpen = false;
    _onDeviceOnly = false;
    _lastListenOutcome = VoiceListenOutcome.none;
    _lastSoundLevelAt = null;
    try {
      if (_speech.isListening) await _speech.cancel();
    } catch (_) {}
    await stopSpeaking();
    _transcript = '';
    _soundLevel = 0;
    _error = VoiceChatError.none;
    _setState(VoiceChatState.idle);
  }

  @visibleForTesting
  void bindTestHooks({VoidCallback? onStateChanged}) {
    _onStateChangedForTest = onStateChanged;
  }

  void _setState(VoiceChatState next) {
    if (_state == next) return;
    _state = next;
    _onStateChangedForTest?.call();
    notifyListeners();
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _transcript = result.recognizedWords;
    notifyListeners();
    if (!result.finalResult) return;
    if (_suppressNextFinal) {
      _suppressNextFinal = false;
      return;
    }
    _listenWatchdog?.cancel();
    _listenWatchdog = null;
    if (_transcript.trim().isEmpty) {
      // The recogniser finished and heard nothing. Say so, rather than
      // reverting silently to "tap to speak" and leaving the user to guess
      // whether the mic is broken.
      _lastListenOutcome = VoiceListenOutcome.heardNothing;
      _setState(VoiceChatState.idle);
      return;
    }
    _setState(VoiceChatState.thinking);
    onTranscript?.call(_transcript.trim());
  }

  void _onSpeechError(SpeechRecognitionError error) {
    _listenWatchdog?.cancel();
    _listenWatchdog = null;

    final msg = error.errorMsg.toLowerCase();
    if (msg.contains('permission') || msg.contains('not-allowed')) {
      _error = VoiceChatError.micDenied;
      _setState(VoiceChatState.idle);
      return;
    }

    // When this session asked for offline recognition and the platform cannot
    // provide it, retry once against the platform recognizer instead of
    // failing. Timeouts, no-match and other transient errors keep the existing
    // handling, so silence never sends the next attempt to the network.
    if (_onDeviceOnly &&
        (msg.contains('unavailable') ||
            msg.contains('recognizer') ||
            msg.contains('not_supported'))) {
      _onDeviceOnly = false;
      unawaited(_beginListening(preferOnDevice: false));
      return;
    }

    // Conversational pauses, timeouts, no-match, or client cancellations
    // are transient speech events and should not permanently mark speech
    // recognition as unavailable.
    if (msg.contains('timeout') ||
        msg.contains('no_match') ||
        msg.contains('no-match') ||
        msg.contains('busy') ||
        msg.contains('client') ||
        msg.contains('cancel')) {
      if (_state == VoiceChatState.listening && _transcript.trim().isNotEmpty) {
        _setState(VoiceChatState.thinking);
        onTranscript?.call(_transcript.trim());
      } else {
        // A `no_match` or a pause that became a timeout is the recogniser
        // working correctly and hearing nothing, so it is the same "didn't
        // catch that" as a clean empty result.
        _lastListenOutcome = VoiceListenOutcome.heardNothing;
        _setState(VoiceChatState.idle);
      }
      return;
    }

    if (error.permanent) {
      _error = VoiceChatError.unavailable;
      _setState(VoiceChatState.idle);
    }
  }

  void _onSpeechStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      if (_state == VoiceChatState.listening && _transcript.trim().isEmpty) {
        _lastListenOutcome = VoiceListenOutcome.heardNothing;
        _setState(VoiceChatState.idle);
      }
    }
  }

  void _onTtsStart() {
    _setState(VoiceChatState.speaking);
  }

  void _onTtsUtteranceComplete() {
    if (_queuedUtterances > 0) _queuedUtterances--;
    if (_queuedUtterances == 0 && !_replyStreamOpen) {
      _setState(VoiceChatState.idle);
    }
  }

  void _onTtsStop() {
    _queuedUtterances = 0;
    if (_state == VoiceChatState.speaking) {
      _setState(VoiceChatState.idle);
    }
  }

  String? _nextSpeakableChunk() {
    final text = _replyBuffer.toString();
    if (text.length <= _spokenUpTo.length) return null;
    final fresh = text.substring(_spokenUpTo.length);
    final boundary = _lastSentenceBoundary(fresh);
    if (boundary == null) return null;
    // Sanitize *before* deciding there is nothing to say, so a chunk that is
    // only markup is dropped rather than read aloud character by character.
    // A fence is not a sentence boundary, so a code block used to accumulate
    // until the whole reply had finished and then be spoken in one go.
    final chunk = SpeakableText.flatten(fresh.substring(0, boundary));
    _spokenUpTo += fresh.substring(0, boundary);
    if (chunk.isEmpty) return null;
    return chunk;
  }

  String _unspeakableRemainder(String fullText) {
    if (fullText.length <= _spokenUpTo.length) return '';
    // The tail of a streaming reply can be half a word, or a dangling tag from
    // the chat template. Speaking that is worse than not speaking it.
    final tail = fullText.substring(_spokenUpTo.length);
    final cleaned = SpeakableText.flatten(tail);
    if (cleaned.isEmpty) return '';
    return SpeakableText.stripTrailingFragment(cleaned) ?? '';
  }

  int? _lastSentenceBoundary(String text) {
    int? boundary;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '.' || char == '!' || char == '?' || char == '\n') {
        final atEnd = i + 1 == text.length;
        final next = atEnd ? ' ' : text[i + 1];
        if (next == ' ' || next == '\n' || atEnd) {
          boundary = i + 1;
        }
      }
    }
    return boundary;
  }

  Future<void> _enqueueUtterance(String text) async {
    if (!_ttsReady) return;
    _queuedUtterances++;
    _setState(VoiceChatState.speaking);
    try {
      await _tts.speak(text);
    } catch (_) {
      // A failed utterance still has to retire its slot, and if that was the
      // last one the state has to come down with it. Decrementing the counter
      // without doing the second part is how the controller could sit in
      // `speaking` forever with nothing speaking — a spinner that never stops.
      if (_queuedUtterances > 0) _queuedUtterances--;
      if (_queuedUtterances == 0 && !_replyStreamOpen) {
        _setState(VoiceChatState.idle);
      }
    }
  }

  @override
  void dispose() {
    _listenWatchdog?.cancel();
    // Cancelling the watchdog is not enough: a disposed controller must not
    // leave the microphone open or an utterance playing, and the singleton is
    // never disposed by the app, so this is the last line of defence rather
    // than the main one.
    unawaited(_speech.isListening ? _speech.cancel() : Future<void>.value());
    unawaited(stopSpeaking());
    super.dispose();
  }
}
