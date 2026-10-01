import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/voice/reply_chunker.dart';
import 'package:finn_ai/src/features/voice/stt/sherpa_speech_backend.dart';
import 'package:finn_ai/src/features/voice/stt/speech_backend.dart';
import 'package:finn_ai/src/features/voice/tts/fallback_tts_backend.dart';
import 'package:finn_ai/src/features/voice/tts/language_pick.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_catalog.dart';
import 'package:finn_ai/src/features/voice/tts_backend.dart';

export 'package:finn_ai/src/features/voice/stt/speech_backend.dart';
export 'package:finn_ai/src/features/voice/tts_backend.dart';

enum VoiceChatState { idle, listening, thinking, speaking }

enum VoiceChatError {
  none,
  micDenied,
  unavailable,

  /// The on-device speech model has not been downloaded. The sheet offers it.
  modelMissing,
}

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

class VoiceChatController extends ChangeNotifier {
  VoiceChatController({
    SpeechBackend? speech,
    TtsBackend? tts,
    this.onTranscript,
    String? deviceLanguage,
  })  : _speech = speech ?? SherpaSpeechBackend(),
        _tts = tts ?? FallbackTtsBackend(),
        _deviceLanguage = deviceLanguage;

  static final instance = VoiceChatController(
    deviceLanguage: PlatformDispatcher.instance.locale.languageCode,
  );

  final SpeechBackend _speech;
  final TtsBackend _tts;
  final String? _deviceLanguage;

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
  final ReplyChunker _chunker = ReplyChunker();
  bool _replyStreamOpen = false;
  bool _replyCancelled = false;
  int _queuedUtterances = 0;

  // The live conversation: listen, send, think, speak, listen again.
  bool _live = false;
  int _liveGeneration = 0;
  bool _spokeThisTurn = false;

  /// Bumped when speech is stopped, so an utterance that was still waiting to
  /// start does not start after the interruption.
  int _speakEpoch = 0;
  String? _heardLanguage;
  Timer? _speakWatchdog;

  // Where a turn's time goes, logged as `FINN_VOICE`: from the moment the
  // transcript lands to the first text from the model and to the first sound.
  final Stopwatch _turn = Stopwatch();
  bool _firstTextLogged = false;
  bool _firstAudioLogged = false;

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

  /// True while a hands-free conversation is going: after each spoken reply
  /// the microphone opens again by itself, until the user ends it.
  bool get live => _live;

  /// True when the last listen finished without catching anything.
  bool get didNotCatchAnything => _lastListenOutcome.didCatchNothing;

  void Function(String text)? onTranscript;

  void setSpokenResponses(bool value) {
    _spokenResponses = value;
    notifyListeners();
  }

  Future<bool> ensureReady() async {
    await _ensureSpeech();
    await _ensureTts();
    return _sttAvailable || _ttsReady;
  }

  /// Checks the microphone and the speech model. This is all listening needs,
  /// so it is all that listening waits for.
  Future<void> _ensureSpeech() async {
    if (_sttAvailable) return;
    SpeechInit init;
    try {
      init = await _speech.initialize(onFailure: _onSpeechFailure);
    } catch (_) {
      init = SpeechInit.unavailable;
    }
    _sttAvailable = init == SpeechInit.ready;
    final next = switch (init) {
      SpeechInit.ready => VoiceChatError.none,
      SpeechInit.micDenied => VoiceChatError.micDenied,
      SpeechInit.needsModel => VoiceChatError.modelMissing,
      SpeechInit.unavailable => VoiceChatError.unavailable,
    };
    if (_error != next) {
      _error = next;
      notifyListeners();
    }
  }

  Future<void>? _ttsInit;

  /// Sets the voice up. Started when listening starts and finished well before
  /// there is anything to say, so it is never on the path to the first word.
  Future<void> _ensureTts() =>
      _ttsReady ? Future.value() : _ttsInit ??= _initTts();

  Future<void> _initTts() async {
    try {
      await _tts.initialize(
        onStart: _onTtsStart,
        onComplete: _onTtsUtteranceComplete,
        onCancel: _onTtsStop,
        onError: (_) => _onTtsStop(),
      );
      _tts.level.addListener(_onTtsLevel);
      _ttsReady = true;
    } catch (_) {
      _ttsReady = false;
    }
    _ttsInit = null;
  }

  /// The state of the on-device speech model, for the sheet's download card.
  ValueListenable<SpeechModelStatus> get speechModel => _speech.model;

  /// Downloads the speech model, then starts listening.
  Future<void> downloadSpeechModel() async {
    try {
      await _speech.downloadModel();
    } catch (_) {
      // The status already says `failed`; the sheet shows it and offers a retry.
      return;
    }
    _error = VoiceChatError.none;
    notifyListeners();
    await startListening();
  }

  /// Starts a hands-free conversation: listens now, and again after each
  /// spoken reply. The first call also warms the voice so the first answer is
  /// not waiting on it.
  Future<void> startLive() async {
    _live = true;
    _liveGeneration++;
    notifyListeners();
    unawaited(ensureReady().then((_) => _tts.prepare()).catchError((_) {}));
    await startListening();
    if (_error != VoiceChatError.none) _endLive();
  }

  /// Ends the conversation and lets go of the microphone and the speaker.
  Future<void> endLive() async {
    _endLive();
    await reset();
  }

  void _endLive() {
    if (!_live) return;
    _live = false;
    _liveGeneration++;
    notifyListeners();
  }

  /// What a tap on the microphone means, in whatever state it finds things.
  /// [onStopGeneration] stops the model when a reply is still being written.
  Future<void> tapMic({VoidCallback? onStopGeneration}) async {
    switch (_state) {
      case VoiceChatState.listening:
        await stopListening();
      case VoiceChatState.speaking:
      case VoiceChatState.thinking:
        await interrupt();
        onStopGeneration?.call();
        await startListening();
      case VoiceChatState.idle:
        await startListening();
    }
  }

  Future<void> startListening() async {
    await _ensureSpeech();
    unawaited(_ensureTts());
    if (!_sttAvailable) {
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
    // A fresh attempt clears the previous "didn't catch that", so the message
    // is about the last try rather than sticking to the user.
    _lastListenOutcome = VoiceListenOutcome.none;
    _lastSoundLevelAt = null;
    try {
      await _speech.listen(
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
    _listenWatchdog?.cancel();
    _listenWatchdog = null;
    try {
      if (_speech.isListening) await _speech.cancel();
    } catch (_) {}
    _setState(VoiceChatState.idle);
  }

  void beginThinking() {
    _replyBuffer.clear();
    _chunker.reset();
    _replyStreamOpen = true;
    _replyCancelled = false;
    _spokeThisTurn = false;
    _firstTextLogged = false;
    _firstAudioLogged = false;
    _setState(VoiceChatState.thinking);
  }

  void speakReplyChunk(String fullResponseText) {
    if (!_replyStreamOpen) return;
    _replyBuffer
      ..clear()
      ..write(fullResponseText);
    if (fullResponseText.trim().isNotEmpty && !_firstTextLogged) {
      _firstTextLogged = true;
      debugPrint('FINN_VOICE first_text_ms=${_turn.elapsedMilliseconds}');
    }
    if (!_spokenResponses) return;
    final pending = _chunker.next(fullResponseText);
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
    final remainder = _chunker.remainder(fullResponseText).trim();
    if (remainder.isNotEmpty) {
      _enqueueUtterance(remainder);
    } else if (_queuedUtterances == 0) {
      _setState(VoiceChatState.idle);
      _afterTurn();
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
    _speakWatchdog?.cancel();
    _speakEpoch++;
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
    _endLive();
    _lastListenOutcome = VoiceListenOutcome.none;
    _lastSoundLevelAt = null;
    try {
      if (_speech.isListening) await _speech.cancel();
      // The recogniser holds a few hundred MB while loaded, and the language
      // model is the thing that needs that memory once voice mode closes.
      await _speech.release();
    } catch (_) {}
    _sttAvailable = false;
    await stopSpeaking();
    try {
      await _tts.release();
    } catch (_) {}
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

  void _onSpeechResult(SpeechResult result) {
    _transcript = result.words;
    notifyListeners();
    if (!result.isFinal) return;
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
    _heardLanguage = normalizeLanguage(result.language);
    _turn
      ..reset()
      ..start();
    debugPrint('FINN_VOICE transcript lang=$_heardLanguage');
    _setState(VoiceChatState.thinking);
    onTranscript?.call(_transcript.trim());
  }

  void _onSpeechFailure(SpeechFailure failure) {
    _listenWatchdog?.cancel();
    _listenWatchdog = null;
    switch (failure.kind) {
      case SpeechFailureKind.permission:
        _error = VoiceChatError.micDenied;
      case SpeechFailureKind.noSpeech:
        // Silence is the recogniser working and hearing nothing, so it is the
        // same "didn't catch that" as a clean empty result.
        _lastListenOutcome = VoiceListenOutcome.heardNothing;
      case SpeechFailureKind.unavailable:
        _error = VoiceChatError.unavailable;
    }
    // Silence ends a hands-free conversation rather than reopening the
    // microphone forever on someone who has walked away.
    _endLive();
    _setState(VoiceChatState.idle);
  }

  void _onTtsStart() {
    _speakWatchdog?.cancel();
    if (!_firstAudioLogged) {
      _firstAudioLogged = true;
      debugPrint('FINN_VOICE first_audio_ms=${_turn.elapsedMilliseconds}');
    }
    _setState(VoiceChatState.speaking);
  }

  void _onTtsUtteranceComplete() {
    if (_queuedUtterances > 0) _queuedUtterances--;
    if (_queuedUtterances == 0 && !_replyStreamOpen) {
      _setState(VoiceChatState.idle);
      _afterTurn();
    }
  }

  void _onTtsStop() {
    _speakWatchdog?.cancel();
    _queuedUtterances = 0;
    if (_state == VoiceChatState.speaking) {
      _setState(VoiceChatState.idle);
    }
  }

  /// While speaking, the orb follows the voice rather than the microphone.
  void _onTtsLevel() {
    if (_state == VoiceChatState.speaking) _onSoundLevel(_tts.level.value);
  }

  /// A spoken reply is over: in a live conversation, listen again.
  void _afterTurn() {
    if (!_live || !_spokeThisTurn || _replyCancelled) return;
    final generation = _liveGeneration;
    // A beat for the room to go quiet, so the end of the reply is not heard as
    // the start of the next question.
    Timer(const Duration(milliseconds: 350), () {
      if (!_live || generation != _liveGeneration) return;
      if (_state != VoiceChatState.idle) return;
      unawaited(startListening());
    });
  }

  Future<void> _enqueueUtterance(String text) async {
    if (!_ttsReady) await _ensureTts();
    if (!_ttsReady) return;
    _queuedUtterances++;
    _spokeThisTurn = true;
    _setState(VoiceChatState.speaking);
    // A voice that never starts (an engine that is missing, a hung synth)
    // must not hold the controller in "speaking" for ever.
    // Only until the first sound: once it is playing, a long sentence is not
    // a hang.
    if (!_firstAudioLogged) {
      _speakWatchdog?.cancel();
      _speakWatchdog = Timer(const Duration(seconds: 8), () async {
        if (_state != VoiceChatState.speaking) return;
        await stopSpeaking();
        // Nothing could be spoken (no voice for this language, no engine): in
        // a live conversation the next thing is still the user's turn.
        if (!_replyStreamOpen) _afterTurn();
      });
    }
    final epoch = _speakEpoch;
    try {
      await _tts.setLanguage(
        pickSpeechLanguage(
          text,
          heard: _heardLanguage,
          device: _deviceLanguage,
        ),
      );
      if (epoch != _speakEpoch) return;
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
    _speakWatchdog?.cancel();
    _tts.level.removeListener(_onTtsLevel);
    // Cancelling the watchdog is not enough: a disposed controller must not
    // leave the microphone open or an utterance playing, and the singleton is
    // never disposed by the app, so this is the last line of defence rather
    // than the main one.
    unawaited(_speech.release());
    unawaited(stopSpeaking());
    super.dispose();
  }
}
