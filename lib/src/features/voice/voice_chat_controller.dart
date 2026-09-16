import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceChatState { idle, listening, thinking, speaking }

enum VoiceChatError { none, micDenied, unavailable }

const double voiceSpeechRate = 0.45;

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
  }) =>
      _speech.listen(
          onResult: onResult, onSoundLevelChange: onSoundLevelChange);

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
    await setSpeechRate(voiceSpeechRate);
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
  Timer? _listenWatchdog;
  final StringBuffer _replyBuffer = StringBuffer();
  String _spokenUpTo = '';
  bool _replyStreamOpen = false;
  bool _replyCancelled = false;
  int _queuedUtterances = 0;

  VoiceChatState get state => _state;
  VoiceChatError get error => _error;
  String get transcript => _transcript;
  double get soundLevel => _soundLevel;
  bool get spokenResponses => _spokenResponses;
  bool get active => _state != VoiceChatState.idle;

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
    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        onSoundLevelChange: (level) {
          _soundLevel = level.clamp(0.0, 1.0);
          notifyListeners();
        },
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

  Future<void> stopListening() async {
    _listenWatchdog?.cancel();
    _listenWatchdog = null;
    try {
      if (_speech.isListening) await _speech.stop();
    } catch (_) {}
  }

  Future<void> cancelListening() async {
    _suppressNextFinal = true;
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

  Future<void> reset() async {
    _listenWatchdog?.cancel();
    _listenWatchdog = null;
    _replyStreamOpen = false;
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
    final chunk = fresh.substring(0, boundary).trim();
    if (chunk.isEmpty) return null;
    _spokenUpTo += fresh.substring(0, boundary);
    return chunk;
  }

  String _unspeakableRemainder(String fullText) {
    if (fullText.length <= _spokenUpTo.length) return '';
    return fullText.substring(_spokenUpTo.length);
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
      if (_queuedUtterances > 0) _queuedUtterances--;
    }
  }

  @override
  void dispose() {
    _listenWatchdog?.cancel();
    super.dispose();
  }
}
