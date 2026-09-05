import 'package:finn_ai/src/voice/voice_chat_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class FakeSpeechBackend implements SpeechBackend {
  bool initializeResult = true;
  bool permissionResult = true;
  bool listening = false;
  bool throwOnListen = false;
  void Function(SpeechRecognitionResult result)? onResult;
  void Function(double level)? onSoundLevel;
  void Function(SpeechRecognitionError error)? onError;
  void Function(String status)? onStatus;
  int stopCalls = 0;
  int cancelCalls = 0;

  @override
  Future<bool> initialize({
    void Function(SpeechRecognitionError error)? onError,
    void Function(String status)? onStatus,
  }) async {
    this.onError = onError;
    this.onStatus = onStatus;
    return initializeResult;
  }

  @override
  Future<bool> get hasPermission async => permissionResult;

  @override
  bool get isListening => listening;

  @override
  Future<void> listen({
    void Function(SpeechRecognitionResult result)? onResult,
    void Function(double level)? onSoundLevelChange,
  }) async {
    if (throwOnListen) throw StateError('listen failed');
    this.onResult = onResult;
    onSoundLevel = onSoundLevelChange;
    listening = true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    listening = false;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    listening = false;
  }

  void emitResult(String words, {required bool finalResult}) {
    onResult?.call(
      SpeechRecognitionResult(
        [SpeechRecognitionWords(words, const [], 0.9)],
        finalResult ? ResultType.finalResult.value : ResultType.partial.value,
      ),
    );
  }
}

class FakeTtsBackend implements TtsBackend {
  final List<String> spoken = [];
  final List<double> rates = [];
  int queueAddCalls = 0;
  int stopCalls = 0;
  bool throwOnInit = false;
  VoidCallback? onStart;
  VoidCallback? onComplete;

  @override
  Future<void> initialize({
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onCancel,
    void Function(dynamic message)? onError,
  }) async {
    if (throwOnInit) throw StateError('no engine');
    this.onStart = onStart;
    this.onComplete = onComplete;
    await setQueueAdd();
    await setSpeechRate(voiceSpeechRate);
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    rates.add(rate);
  }

  @override
  Future<void> setQueueAdd() async {
    queueAddCalls++;
  }

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    onStart?.call();
    onComplete?.call();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

VoiceChatController makeController({
  FakeSpeechBackend? speech,
  FakeTtsBackend? tts,
}) {
  final controller = VoiceChatController(
    speech: speech ?? FakeSpeechBackend(),
    tts: tts ?? FakeTtsBackend(),
  );
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  group('VoiceChatController listening', () {
    test('final transcript moves listening -> thinking and fires callback',
        () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      var heard = '';
      controller.onTranscript = (text) => heard = text;

      await controller.startListening();
      expect(controller.state, VoiceChatState.listening);

      speech.emitResult('hello finn', finalResult: false);
      expect(controller.state, VoiceChatState.listening);
      expect(controller.transcript, 'hello finn');

      speech.emitResult('hello finn', finalResult: true);
      expect(controller.state, VoiceChatState.thinking);
      expect(heard, 'hello finn');
    });

    test('empty final transcript returns to idle without callback', () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      var calls = 0;
      controller.onTranscript = (_) => calls++;

      await controller.startListening();
      speech.emitResult('   ', finalResult: true);

      expect(controller.state, VoiceChatState.idle);
      expect(calls, 0);
    });

    test('mic denied surfaces micDenied error', () async {
      final speech = FakeSpeechBackend()
        ..initializeResult = false
        ..permissionResult = false;
      final controller = makeController(speech: speech);

      await controller.startListening();

      expect(controller.error, VoiceChatError.micDenied);
      expect(controller.state, VoiceChatState.idle);
    });

    test('init failure with permission granted surfaces unavailable', () async {
      final speech = FakeSpeechBackend()
        ..initializeResult = false
        ..permissionResult = true;
      final controller = makeController(speech: speech);

      await controller.startListening();

      expect(controller.error, VoiceChatError.unavailable);
    });

    test('cancelListening suppresses the pending final result', () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      var calls = 0;
      controller.onTranscript = (_) => calls++;

      await controller.startListening();
      await controller.cancelListening();
      speech.emitResult('late words', finalResult: true);

      expect(calls, 0);
      expect(controller.state, VoiceChatState.idle);
    });
  });

  group('VoiceChatController TTS streaming', () {
    test('speaks completed sentences while the stream is open', () async {
      final tts = FakeTtsBackend();
      final controller = makeController(tts: tts);
      await controller.ensureReady();

      controller.beginThinking();
      controller.speakReplyChunk('Hello there');
      expect(tts.spoken, isEmpty);

      controller.speakReplyChunk('Hello there. How can I');
      expect(tts.spoken, ['Hello there.']);
      expect(controller.state, VoiceChatState.speaking);
    });

    test('finishReply speaks the remainder then goes idle', () async {
      final tts = FakeTtsBackend();
      final controller = makeController(tts: tts);
      await controller.ensureReady();

      controller.beginThinking();
      controller.speakReplyChunk('First sentence. Second');
      controller.finishReply('First sentence. Second part here.');
      await Future<void>.delayed(Duration.zero);

      expect(tts.spoken, ['First sentence.', 'Second part here.']);
      expect(controller.state, VoiceChatState.idle);
    });

    test('spoken responses off keeps everything silent', () async {
      final tts = FakeTtsBackend();
      final controller = makeController(tts: tts);
      await controller.ensureReady();
      controller.setSpokenResponses(false);

      controller.beginThinking();
      controller.speakReplyChunk('Hello. World.');
      controller.finishReply('Hello. World.');

      expect(tts.spoken, isEmpty);
      expect(controller.state, VoiceChatState.idle);
    });

    test('interrupt stops TTS and returns to idle', () async {
      final tts = FakeTtsBackend();
      final controller = makeController(tts: tts);
      await controller.ensureReady();

      controller.beginThinking();
      controller.speakReplyChunk('A long reply. Still going.');
      await controller.interrupt();

      expect(tts.stopCalls, greaterThanOrEqualTo(1));
      expect(controller.state, VoiceChatState.idle);
    });

    test('finishReply after interrupt stays silent', () async {
      final tts = FakeTtsBackend();
      final controller = makeController(tts: tts);
      await controller.ensureReady();

      controller.beginThinking();
      controller.speakReplyChunk('A long reply. Still going.');
      final spokenBefore = tts.spoken.length;
      await controller.interrupt();
      controller.finishReply('A long reply. Still going further.');

      expect(tts.spoken.length, spokenBefore);
      expect(controller.state, VoiceChatState.idle);
    });

    test('TTS init failure still allows listening', () async {
      final tts = FakeTtsBackend()..throwOnInit = true;
      final controller = makeController(tts: tts);

      await controller.startListening();

      expect(controller.state, VoiceChatState.listening);
    });

    test('init applies conversational rate and queue-add mode', () async {
      final tts = FakeTtsBackend();
      final controller = makeController(tts: tts);

      await controller.ensureReady();

      expect(tts.queueAddCalls, 1);
      expect(tts.rates, [voiceSpeechRate]);
      expect(voiceSpeechRate, lessThan(0.6));
    });
  });
}
