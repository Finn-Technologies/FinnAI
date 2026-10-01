import 'package:finn_ai/src/features/voice/voice_chat_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_speech_backend.dart';

class FakeTtsBackend implements TtsBackend {
  @override
  final ValueNotifier<double> level = ValueNotifier(0);

  String? language;
  int prepareCalls = 0;
  int releaseCalls = 0;

  @override
  Future<void> setLanguage(String? language) async => this.language = language;

  @override
  Future<void> prepare() async => prepareCalls++;

  @override
  Future<void> release() async => releaseCalls++;
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

Future<void> settle() => Future<void>.delayed(Duration.zero);

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
      final speech = FakeSpeechBackend()..initResult = SpeechInit.micDenied;
      final controller = makeController(speech: speech);

      await controller.startListening();

      expect(controller.error, VoiceChatError.micDenied);
      expect(controller.state, VoiceChatState.idle);
      expect(speech.listenCalls, 0);
    });

    test('an unusable recogniser surfaces unavailable', () async {
      final speech = FakeSpeechBackend()..initResult = SpeechInit.unavailable;
      final controller = makeController(speech: speech);

      await controller.startListening();

      expect(controller.error, VoiceChatError.unavailable);
    });

    test('a failing microphone start surfaces unavailable', () async {
      final speech = FakeSpeechBackend()..throwOnListen = true;
      final controller = makeController(speech: speech);

      await controller.startListening();

      expect(controller.error, VoiceChatError.unavailable);
      expect(controller.state, VoiceChatState.idle);
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

    test('a silent session returns to idle with no error', () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      await controller.startListening();

      speech.fail(SpeechFailureKind.noSpeech);

      expect(controller.state, VoiceChatState.idle);
      expect(controller.error, VoiceChatError.none);
      expect(controller.didNotCatchAnything, isTrue);
    });

    test('a permission failure mid-session sets micDenied', () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      await controller.startListening();

      speech.fail(SpeechFailureKind.permission);

      expect(controller.state, VoiceChatState.idle);
      expect(controller.error, VoiceChatError.micDenied);
    });

    test('a recogniser failure mid-session sets unavailable', () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      await controller.startListening();

      speech.fail(SpeechFailureKind.unavailable);

      expect(controller.state, VoiceChatState.idle);
      expect(controller.error, VoiceChatError.unavailable);
    });

    test('the recogniser is released when the controller resets', () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      await controller.startListening();

      await controller.reset();

      expect(speech.releaseCalls, 1);
      expect(controller.state, VoiceChatState.idle);
    });

    test('listening again after a reset loads the recogniser again', () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      await controller.startListening();
      await controller.reset();

      await controller.startListening();

      expect(speech.listenCalls, 2);
      expect(controller.state, VoiceChatState.listening);
    });
  });

  group('VoiceChatController speech model', () {
    test('a missing model surfaces modelMissing and does not listen', () async {
      final speech = FakeSpeechBackend()..initResult = SpeechInit.needsModel;
      final controller = makeController(speech: speech);

      await controller.startListening();

      expect(controller.error, VoiceChatError.modelMissing);
      expect(controller.state, VoiceChatState.idle);
      expect(speech.listenCalls, 0);
    });

    test('downloading the model clears the error and starts listening',
        () async {
      final speech = FakeSpeechBackend()..initResult = SpeechInit.needsModel;
      final controller = makeController(speech: speech);
      await controller.startListening();

      await controller.downloadSpeechModel();

      expect(speech.downloadCalls, 1);
      expect(controller.error, VoiceChatError.none);
      expect(controller.state, VoiceChatState.listening);
    });

    test('a failed download keeps modelMissing so the sheet can retry',
        () async {
      final speech = FakeSpeechBackend()
        ..initResult = SpeechInit.needsModel
        ..throwOnDownload = true;
      final controller = makeController(speech: speech);
      await controller.startListening();

      await controller.downloadSpeechModel();

      expect(controller.error, VoiceChatError.modelMissing);
      expect(controller.speechModel.value.phase, SpeechModelPhase.failed);
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
      await settle();
      expect(tts.spoken, isEmpty);

      controller.speakReplyChunk('Hello there. How can I');
      await settle();
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

    group('a reply is sanitised before it is spoken', () {
      test('a code block is announced, not recited', () async {
        final tts = FakeTtsBackend();
        final controller = makeController(tts: tts);
        await controller.ensureReady();

        controller.beginThinking();
        controller
            .speakReplyChunk('Here it is:\n\n```dart\nfinal x = 1;\n```\n');
        controller.finishReply(
          'Here it is:\n\n```dart\nfinal x = 1;\n```\nThat is all.',
        );
        await settle();

        final spoken = tts.spoken.join(' ');
        expect(spoken, contains('Here it is'));
        expect(spoken, contains('That is all'));
        expect(spoken, isNot(contains('final x')),
            reason: 'reading code aloud character by character is the failure '
                'this exists to prevent');
        expect(spoken, isNot(contains('```')));
      });

      test('a markup-only chunk is silent rather than read as symbols',
          () async {
        final tts = FakeTtsBackend();
        final controller = makeController(tts: tts);
        await controller.ensureReady();

        controller.beginThinking();
        // A line that is only bold markers, then a real sentence.
        controller.speakReplyChunk('**\nReal sentence here.');
        controller.finishReply('**\nReal sentence here.');
        await settle();

        expect(tts.spoken, isNotEmpty);
        for (final chunk in tts.spoken) {
          expect(chunk.trim(), isNot('**'));
        }
        expect(tts.spoken.join(' '), contains('Real sentence here'));
      });
    });

    group('"did not catch that" is a real state', () {
      test('a clean empty result reports it', () async {
        final speech = FakeSpeechBackend();
        final controller = makeController(speech: speech);
        await controller.ensureReady();
        expect(controller.didNotCatchAnything, isFalse);

        await controller.startListening();
        speech.emitResult('   ', finalResult: true);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(controller.didNotCatchAnything, isTrue);
        expect(controller.state, VoiceChatState.idle);
      });

      test('a silent session reports it', () async {
        final speech = FakeSpeechBackend();
        final controller = makeController(speech: speech);
        await controller.ensureReady();
        await controller.startListening();
        expect(controller.didNotCatchAnything, isFalse);

        speech.fail(SpeechFailureKind.noSpeech);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(controller.didNotCatchAnything, isTrue);
      });

      test('a successful listen clears it', () async {
        final speech = FakeSpeechBackend();
        final controller = makeController(speech: speech);
        await controller.ensureReady();
        await controller.startListening();
        speech.emitResult('', finalResult: true);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(controller.didNotCatchAnything, isTrue);

        // Trying again must clear it, or the message sticks to the user
        // through a successful attempt.
        await controller.startListening();
        expect(controller.didNotCatchAnything, isFalse);
      });

      test('a heard transcript does not set it', () async {
        final speech = FakeSpeechBackend();
        final controller = makeController(speech: speech);
        await controller.ensureReady();
        await controller.startListening();

        speech.emitResult('what is the weather', finalResult: true);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(controller.didNotCatchAnything, isFalse);
        expect(controller.state, VoiceChatState.thinking);
      });

      test('reset clears it', () async {
        final speech = FakeSpeechBackend();
        final controller = makeController(speech: speech);
        await controller.ensureReady();
        await controller.startListening();
        speech.emitResult('', finalResult: true);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await controller.reset();
        expect(controller.didNotCatchAnything, isFalse);
      });
    });

    test('finishReply after interrupt stays silent', () async {
      final tts = FakeTtsBackend();
      final controller = makeController(tts: tts);
      await controller.ensureReady();

      controller.beginThinking();
      controller.speakReplyChunk('A long reply. Still going.');
      await settle();
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

  group('VoiceChatController live conversation', () {
    Future<void> afterBeat() =>
        Future<void>.delayed(const Duration(milliseconds: 450));

    /// One full turn: the user speaks, the model answers, Finn speaks.
    Future<void> turn(
      VoiceChatController controller,
      FakeSpeechBackend speech, {
      String heard = 'what is two plus two',
      String reply = 'It is four. Anything else?',
      String? language,
    }) async {
      speech.emitResult(heard, finalResult: true, language: language);
      controller.beginThinking();
      controller.speakReplyChunk(reply);
      controller.finishReply(reply);
      await settle();
    }

    test('startLive listens, marks the conversation live and warms the voice',
        () async {
      final speech = FakeSpeechBackend();
      final tts = FakeTtsBackend();
      final controller = makeController(speech: speech, tts: tts);

      await controller.startLive();

      expect(controller.live, isTrue);
      expect(controller.state, VoiceChatState.listening);
      await settle();
      expect(tts.prepareCalls, greaterThanOrEqualTo(1));
    });

    test('endLive stops everything and lets go of the mic and the voice',
        () async {
      final speech = FakeSpeechBackend();
      final tts = FakeTtsBackend();
      final controller = makeController(speech: speech, tts: tts);
      await controller.startLive();

      await controller.endLive();

      expect(controller.live, isFalse);
      expect(controller.state, VoiceChatState.idle);
      expect(speech.releaseCalls, 1);
      expect(tts.releaseCalls, 1);
    });

    test('after a spoken reply the microphone opens again by itself', () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      await controller.startLive();
      expect(speech.listenCalls, 1);

      await turn(controller, speech);
      await afterBeat();

      expect(speech.listenCalls, 2);
      expect(controller.state, VoiceChatState.listening);
      expect(controller.live, isTrue);
    });

    test('and again after the next one: it is a conversation, not one shot',
        () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      await controller.startLive();

      await turn(controller, speech);
      await afterBeat();
      await turn(controller, speech, heard: 'and times three');
      await afterBeat();

      expect(speech.listenCalls, 3);
    });

    test('it does not listen while the reply is still being spoken', () async {
      final speech = FakeSpeechBackend();
      final tts = _NeverCompletingTts();
      final controller = makeController(speech: speech, tts: tts);
      await controller.startLive();

      speech.emitResult('hello', finalResult: true);
      controller.beginThinking();
      controller.speakReplyChunk('Hi there. More');
      await afterBeat();

      expect(controller.state, VoiceChatState.speaking);
      expect(speech.listenCalls, 1, reason: 'Finn would hear itself');
    });

    test('with spoken replies off it does not reopen the microphone', () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      controller.setSpokenResponses(false);
      await controller.startLive();

      await turn(controller, speech);
      await afterBeat();

      expect(speech.listenCalls, 1);
    });

    test('an interrupted reply does not reopen the microphone by itself',
        () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      await controller.startLive();
      speech.emitResult('tell me a story', finalResult: true);
      controller.beginThinking();

      await controller.interrupt();
      controller.finishReply('Once upon a time. The end.');
      await afterBeat();

      expect(speech.listenCalls, 1);
    });

    test('a reply with nothing to say does not loop the microphone', () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      await controller.startLive();
      speech.emitResult('hm', finalResult: true);
      controller.beginThinking();

      controller.finishReply('');
      await afterBeat();

      expect(speech.listenCalls, 1);
      expect(controller.state, VoiceChatState.idle);
    });

    test('leaving mid-reply cancels the pending reopen', () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      await controller.startLive();
      await turn(controller, speech);

      await controller.endLive();
      await afterBeat();

      expect(speech.listenCalls, 1);
      expect(controller.live, isFalse);
    });

    test('silence ends the conversation rather than listening for ever',
        () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      await controller.startLive();

      speech.fail(SpeechFailureKind.noSpeech);

      expect(controller.live, isFalse);
      expect(controller.state, VoiceChatState.idle);
      expect(controller.didNotCatchAnything, isTrue);
    });

    test('a denied microphone ends it too', () async {
      final speech = FakeSpeechBackend()..initResult = SpeechInit.micDenied;
      final controller = makeController(speech: speech);

      await controller.startLive();

      expect(controller.live, isFalse);
      expect(controller.error, VoiceChatError.micDenied);
    });

    test('so does a missing speech model', () async {
      final speech = FakeSpeechBackend()..initResult = SpeechInit.needsModel;
      final controller = makeController(speech: speech);

      await controller.startLive();

      expect(controller.live, isFalse);
      expect(controller.error, VoiceChatError.modelMissing);
    });

    test('reset (the app was backgrounded) ends the conversation', () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      await controller.startLive();

      await controller.reset();

      expect(controller.live, isFalse);
    });

    test('listeners hear when the conversation ends on its own', () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      await controller.startLive();
      var heardEnd = false;
      controller.addListener(() {
        if (!controller.live) heardEnd = true;
      });

      speech.fail(SpeechFailureKind.noSpeech);

      expect(heardEnd, isTrue);
    });
  });

  group('VoiceChatController tapMic', () {
    test('while listening it finishes what was said', () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      await controller.startListening();

      await controller.tapMic();

      expect(speech.stopCalls, 1);
    });

    test('while Finn speaks it cuts in, stops the model and listens', () async {
      final speech = FakeSpeechBackend();
      final tts = _NeverCompletingTts();
      final controller = makeController(speech: speech, tts: tts);
      await controller.startLive();
      speech.emitResult('hello', finalResult: true);
      controller.beginThinking();
      controller.speakReplyChunk('Hi there. More');
      await settle();
      expect(controller.state, VoiceChatState.speaking);
      var stoppedModel = false;

      await controller.tapMic(onStopGeneration: () => stoppedModel = true);

      expect(stoppedModel, isTrue);
      expect(tts.stopCalls, greaterThanOrEqualTo(1));
      expect(speech.listenCalls, 2);
      expect(controller.state, VoiceChatState.listening);
    });

    test('while thinking it stops the model and listens', () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);
      await controller.startListening();
      speech.emitResult('hello', finalResult: true);
      controller.beginThinking();
      var stoppedModel = false;

      await controller.tapMic(onStopGeneration: () => stoppedModel = true);

      expect(stoppedModel, isTrue);
      expect(speech.listenCalls, 2);
    });

    test('when idle it starts listening', () async {
      final speech = FakeSpeechBackend();
      final controller = makeController(speech: speech);

      await controller.tapMic();

      expect(speech.listenCalls, 1);
    });
  });

  group('VoiceChatController speaking language', () {
    test('a Latin reply follows the language that was heard', () async {
      final speech = FakeSpeechBackend();
      final tts = FakeTtsBackend();
      final controller = makeController(speech: speech, tts: tts);
      await controller.startListening();

      speech.emitResult('wie spät ist es', finalResult: true, language: 'de');
      controller.beginThinking();
      controller.speakReplyChunk('Es ist drei Uhr. Noch etwas?');
      await settle();

      expect(tts.language, 'de');
    });

    test('a Russian reply is spoken in Russian whatever was heard', () async {
      final speech = FakeSpeechBackend();
      final tts = FakeTtsBackend();
      final controller = makeController(speech: speech, tts: tts);
      await controller.startListening();

      speech.emitResult('hello', finalResult: true, language: 'en');
      controller.beginThinking();
      controller.speakReplyChunk('Столица Франции — Париж. Что-нибудь ещё?');
      await settle();

      expect(tts.language, 'ru');
    });

    test('with nothing heard it follows the phone', () async {
      final tts = FakeTtsBackend();
      final controller = VoiceChatController(
        speech: FakeSpeechBackend(),
        tts: tts,
        deviceLanguage: 'it',
      );
      addTearDown(controller.dispose);
      await controller.ensureReady();

      controller.beginThinking();
      controller.speakReplyChunk('Parigi è la capitale. Altro?');
      await settle();

      expect(tts.language, 'it');
    });
  });

  group('VoiceChatController level', () {
    test('while Finn speaks, the level is the voice, not the microphone',
        () async {
      final speech = FakeSpeechBackend();
      final tts = FakeTtsBackend();
      final controller = makeController(speech: speech, tts: tts);
      await controller.startListening();
      speech.onSoundLevel?.call(0.2);
      expect(controller.soundLevel, closeTo(0.2, 1e-9));

      speech.emitResult('hello', finalResult: true);
      controller.beginThinking();
      // A voice that is mid-sentence.
      final slow = _NeverCompletingTts();
      final speaking = makeController(speech: speech, tts: slow);
      await speaking.ensureReady();
      speaking.beginThinking();
      speaking.speakReplyChunk('Hi there. More');
      await settle();
      slow.level.value = 0.8;

      expect(speaking.state, VoiceChatState.speaking);
      expect(speaking.soundLevel, closeTo(0.8, 1e-9));
    });
  });
}

/// A voice that starts and never finishes, to hold the controller in
/// "speaking".
class _NeverCompletingTts extends FakeTtsBackend {
  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    onStart?.call();
  }
}
