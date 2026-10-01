import 'dart:async';
import 'dart:typed_data';

import 'package:finn_ai/src/features/voice/tts/pcm_output.dart';
import 'package:finn_ai/src/features/voice/tts/sherpa_tts_backend.dart';
import 'package:finn_ai/src/features/voice/tts/tts_events.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_catalog.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store extends TtsVoiceStore {
  _Store(this.installed);

  Set<String> installed;

  @override
  Future<bool> isInstalled(TtsVoice voice) async =>
      installed.contains(voice.language);

  @override
  Future<TtsVoicePaths?> paths(TtsVoice voice) async =>
      installed.contains(voice.language)
          ? TtsVoicePaths(
              model: '${voice.language}.onnx',
              tokens: 't',
              dataDir: 'd',
            )
          : null;
}

class _Engine implements TtsEngine {
  _Engine(this.paths);

  final TtsVoicePaths paths;
  final _events = StreamController<TtsEvent>.broadcast(sync: true);
  final requests = <({int id, String text, double speed})>[];
  int cancels = 0;
  bool disposed = false;

  @override
  Stream<TtsEvent> get events => _events.stream;

  @override
  void synth(int id, String text, double speed) =>
      requests.add((id: id, text: text, speed: speed));

  @override
  void cancelAll() => cancels++;

  @override
  void dispose() => disposed = true;

  void chunk(int id, int frames, {double amplitude = 0.2, int rate = 22050}) =>
      _events.add(TtsChunk(
        id,
        Float32List.fromList(List.filled(frames, amplitude)),
        rate,
      ));

  void done(int id) =>
      _events.add(TtsSynthDone(id, millis: 100, audioMillis: 1000));

  void fail(int id) => _events.add(TtsFailed('boom', id: id));
}

class _Output implements PcmOutput {
  int fed = 0;
  int played = 0;
  int stops = 0;
  final rates = <int>[];

  @override
  int get remainingFrames => fed - played;

  @override
  Future<void> feed(Float32List samples, int sampleRate) async {
    fed += samples.length;
    rates.add(sampleRate);
  }

  @override
  Future<void> stop() async {
    stops++;
    fed = 0;
    played = 0;
  }
}

class _Harness {
  _Harness({Set<String> voices = const {'en'}})
      : store = _Store(voices),
        output = _Output() {
    backend = SherpaTtsBackend(
      store: store,
      output: output,
      tick: const Duration(milliseconds: 5),
      spawn: (paths) async {
        final engine = _Engine(paths);
        engines.add(engine);
        return engine;
      },
    );
  }

  final _Store store;
  final _Output output;
  final engines = <_Engine>[];
  late final SherpaTtsBackend backend;
  int starts = 0;
  int completes = 0;
  int cancels = 0;
  final errors = <dynamic>[];

  _Engine get engine => engines.last;

  Future<void> init() => backend.initialize(
        onStart: () => starts++,
        onComplete: () => completes++,
        onCancel: () => cancels++,
        onError: errors.add,
      );
}

Future<void> tick([int ms = 30]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  test('speaks a sentence: synth, audio, one start, one completion', () async {
    final h = _Harness();
    await h.init();

    await h.backend.speak('Hello there.');
    expect(h.engine.requests.single.text, 'Hello there.');

    h.engine.chunk(1, 2000);
    await tick();
    expect(h.starts, 1);
    expect(h.output.fed, 2000);

    h.engine.done(1);
    await tick();
    expect(h.completes, 0, reason: 'it has not finished playing yet');

    h.output.played = 2000;
    await tick();
    expect(h.completes, 1);
  });

  test('sentences are completed in order, as each is heard', () async {
    final h = _Harness();
    await h.init();
    await h.backend.speak('One.');
    await h.backend.speak('Two.');

    h.engine
      ..chunk(1, 1000)
      ..done(1)
      ..chunk(2, 3000)
      ..done(2);
    await tick();
    expect(h.starts, 1, reason: 'one start for the whole reply');

    h.output.played = 1000;
    await tick();
    expect(h.completes, 1);

    h.output.played = 4000;
    await tick();
    expect(h.completes, 2);
  });

  test('the first sentence is audible while the second is still being made',
      () async {
    final h = _Harness();
    await h.init();
    await h.backend.speak('One.');
    await h.backend.speak('Two.');

    h.engine
      ..chunk(1, 1000)
      ..done(1);
    await tick();

    expect(h.output.fed, 1000);
    expect(h.starts, 1);
    // Sentence two has not produced anything yet and has not completed.
    expect(h.completes, 0);
  });

  test('a sentence with no audio still completes', () async {
    final h = _Harness();
    await h.init();
    await h.backend.speak('...');

    h.engine.done(1);
    await tick();

    expect(h.completes, 1);
  });

  test('the level follows the audio being played', () async {
    final h = _Harness();
    await h.init();
    await h.backend.speak('Loud.');
    // 0.5 s of loud audio then 0.5 s of silence, at 22.05 kHz.
    h.engine
      ..chunk(1, 11025, amplitude: 0.3)
      ..chunk(1, 11025, amplitude: 0.0)
      ..done(1);
    await tick();

    h.output.played = 5000;
    await tick();
    final loud = h.backend.level.value;
    h.output.played = 16000;
    await tick();
    final quiet = h.backend.level.value;

    expect(loud, greaterThan(0.5));
    expect(quiet, lessThan(0.05));
  });

  test('the level is zero once nothing is left to play', () async {
    final h = _Harness();
    await h.init();
    await h.backend.speak('Hi.');
    h.engine
      ..chunk(1, 2000)
      ..done(1);
    await tick();
    h.output.played = 2000;
    await tick();

    expect(h.backend.level.value, 0);
  });

  test('stop cancels synthesis, drops audio and reports a cancel', () async {
    final h = _Harness();
    await h.init();
    await h.backend.speak('A long one.');
    h.engine.chunk(1, 2000);
    await tick();

    await h.backend.stop();

    expect(h.engine.cancels, 1);
    expect(h.output.stops, 1);
    expect(h.cancels, 1);
    expect(h.backend.level.value, 0);

    // A chunk that was already in flight is ignored.
    h.engine.chunk(1, 500);
    await tick();
    expect(h.output.fed, 0);
    expect(h.completes, 0);
  });

  test('stop when nothing is playing is quiet', () async {
    final h = _Harness();
    await h.init();

    await h.backend.stop();

    expect(h.cancels, 0);
  });

  test('speaking after a stop works again', () async {
    final h = _Harness();
    await h.init();
    await h.backend.speak('First.');
    await h.backend.stop();

    await h.backend.speak('Second.');
    h.engine
      ..chunk(2, 1000)
      ..done(2);
    await tick();
    h.output.played = 1000;
    await tick();

    expect(h.completes, 1);
  });

  test('with no voice installed, speak throws and canSpeak is false', () async {
    final h = _Harness(voices: {});
    await h.init();

    expect(await h.backend.canSpeak('en'), isFalse);
    await expectLater(h.backend.speak('Hi.'), throwsA(isA<NoVoiceException>()));
    expect(h.engines, isEmpty);
  });

  test('uses the voice for the language, and English when it is missing',
      () async {
    final h = _Harness(voices: {'en', 'de'});
    await h.init();

    await h.backend.setLanguage('de');
    await h.backend.speak('Hallo.');
    expect(h.engines.single.paths.model, 'de.onnx');

    await h.backend.stop();
    await h.backend.setLanguage('pt'); // Latin script, no Portuguese voice
    await h.backend.speak('Olá.');
    expect(h.engines.last.paths.model, 'en.onnx');
    expect(await h.backend.canSpeak('pt'), isTrue);
  });

  test('a script the English voice cannot read is not spoken with it',
      () async {
    final h = _Harness(voices: {'en'});
    await h.init();

    expect(await h.backend.canSpeak('ru'), isFalse);
    expect(await h.backend.canSpeak('hi'), isFalse);
    await h.backend.setLanguage('ru');
    await expectLater(
        h.backend.speak('Привет.'), throwsA(isA<NoVoiceException>()));
    expect(h.engines, isEmpty);
  });

  test('with the Russian voice installed, Russian is spoken', () async {
    final h = _Harness(voices: {'en', 'ru'});
    await h.init();

    await h.backend.setLanguage('ru');
    await h.backend.speak('Привет.');

    expect(h.engines.single.paths.model, 'ru.onnx');
  });

  test('a language voice is not swapped in mid-reply', () async {
    final h = _Harness(voices: {'en', 'de'});
    await h.init();
    await h.backend.speak('First.');

    await h.backend.setLanguage('de');
    await h.backend.speak('Second.');

    expect(h.engines, hasLength(1),
        reason: 'changing voice would cut the sentence being heard');
    expect(h.engine.requests.map((r) => r.text), ['First.', 'Second.']);
  });

  test('the speed setting maps onto the voice speed', () async {
    final h = _Harness();
    await h.init();

    await h.backend.setSpeechRate(0.45);
    await h.backend.speak('Normal.');
    await h.backend.setSpeechRate(0.32);
    await h.backend.speak('Slow.');
    await h.backend.setSpeechRate(0.6);
    await h.backend.speak('Fast.');

    final speeds = h.engine.requests.map((r) => r.speed).toList();
    expect(speeds[0], closeTo(1.0, 1e-9));
    expect(speeds[1], lessThan(1.0));
    expect(speeds[2], greaterThan(1.0));
  });

  test('a failed synthesis retires its slot and reports', () async {
    final h = _Harness();
    await h.init();
    await h.backend.speak('Oops.');

    h.engine.fail(1);
    await tick();

    expect(h.completes, 1);
    expect(h.errors, ['boom']);
  });

  test('prepare loads the voice before anything is said', () async {
    final h = _Harness();
    await h.init();

    await h.backend.prepare();
    expect(h.engines, hasLength(1));

    await h.backend.speak('Now.');
    expect(h.engines, hasLength(1), reason: 'the loaded voice is reused');
  });

  test('prepare with no voice does nothing', () async {
    final h = _Harness(voices: {});
    await h.init();

    await h.backend.prepare();

    expect(h.engines, isEmpty);
  });

  test('release frees the voice and the speaker', () async {
    final h = _Harness();
    await h.init();
    await h.backend.speak('Hi.');

    await h.backend.release();

    expect(h.engine.disposed, isTrue);
    expect(h.output.stops, greaterThanOrEqualTo(1));
  });

  test('a new sample rate waits for the sentence before it to finish',
      () async {
    final h = _Harness(voices: {'en', 'de'});
    await h.init();
    await h.backend.speak('One.');
    h.engine
      ..chunk(1, 1000, rate: 22050)
      ..done(1);
    await tick();

    // The next sentence arrives at another rate while the first plays.
    h.engine.chunk(1, 10, rate: 16000);
    await tick(10);
    expect(h.output.rates, [22050], reason: 'not mixed into the same buffer');
  });
}
