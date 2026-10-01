import 'dart:async';
import 'dart:typed_data';

import 'package:finn_ai/src/features/voice/stt/mic_source.dart';
import 'package:finn_ai/src/features/voice/stt/sherpa_speech_backend.dart';
import 'package:finn_ai/src/features/voice/stt/speech_backend.dart';
import 'package:finn_ai/src/features/voice/stt/stt_events.dart';
import 'package:finn_ai/src/features/voice/stt/stt_model_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMic implements MicSource {
  bool permission = true;
  bool throwOnStart = false;
  int starts = 0;
  int stops = 0;
  bool disposed = false;
  StreamController<Uint8List>? _controller;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<Stream<Uint8List>> start() async {
    if (throwOnStart) throw StateError('no mic');
    starts++;
    _controller = StreamController<Uint8List>();
    return _controller!.stream;
  }

  @override
  Future<void> stop() async {
    stops++;
    await _controller?.close();
  }

  @override
  Future<void> dispose() async => disposed = true;

  void speak({int samples = 1600, int amplitude = 4000}) {
    final data = ByteData(samples * 2);
    for (var i = 0; i < samples; i++) {
      data.setInt16(i * 2, amplitude, Endian.little);
    }
    _controller?.add(data.buffer.asUint8List());
  }
}

class _FakeWorker implements SpeechWorker {
  final _events = StreamController<SttEvent>.broadcast(sync: true);
  final List<int> fed = [];
  int flushes = 0;
  int resets = 0;
  bool disposed = false;

  /// The real worker answers a reset only after whatever it was decoding, so
  /// a test can hold the acknowledgement back.
  bool autoAck = true;

  /// What a flush produces, in order, before [SttFlushed].
  List<SttEvent> onFlush = const [];

  @override
  Stream<SttEvent> get events => _events.stream;

  @override
  void feed(Float32List samples) => fed.add(samples.length);

  @override
  void flush() {
    flushes++;
    for (final event in onFlush) {
      _events.add(event);
    }
    _events.add(const SttFlushed());
  }

  @override
  void reset() {
    resets++;
    if (autoAck) _events.add(const SttResetDone());
  }

  @override
  void dispose() => disposed = true;

  void emit(SttEvent event) => _events.add(event);
}

class _FakeStore extends SttModelStore {
  _FakeStore({this.installed = true});

  bool installed;

  @override
  Future<bool> isInstalled() async => installed;

  @override
  Future<void> refresh() async {}

  @override
  Future<SttModelPaths?> paths() async => installed
      ? const SttModelPaths(encoder: 'e', decoder: 'd', tokens: 't', vad: 'v')
      : null;
}

class _Harness {
  _Harness({
    bool installed = true,
    Duration noSpeech = const Duration(seconds: 5),
    Duration max = const Duration(seconds: 5),
    this.loadDelay = Duration.zero,
    this.failLoad = false,
  }) : store = _FakeStore(installed: installed) {
    backend = SherpaSpeechBackend(
      store: store,
      micFactory: () => mic,
      spawnWorker: (_) async {
        spawns++;
        await Future<void>.delayed(loadDelay);
        if (failLoad) throw StateError('model would not load');
        return worker;
      },
      noSpeechTimeout: noSpeech,
      maxSession: max,
    );
  }

  final _FakeStore store;
  final mic = _FakeMic();
  final worker = _FakeWorker();
  final Duration loadDelay;
  final bool failLoad;
  late final SherpaSpeechBackend backend;
  int spawns = 0;
  final results = <SpeechResult>[];
  final failures = <SpeechFailure>[];
  final levels = <double>[];

  Future<SpeechInit> init() => backend.initialize(onFailure: failures.add);

  Future<void> listen() => backend.listen(
        onResult: results.add,
        onSoundLevelChange: levels.add,
      );
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  group('initialize', () {
    test('is ready with permission and an installed model', () async {
      final h = _Harness();
      expect(await h.init(), SpeechInit.ready);
    });

    test('reports a denied microphone', () async {
      final h = _Harness();
      h.mic.permission = false;
      expect(await h.init(), SpeechInit.micDenied);
    });

    test('asks for the model when it is not installed', () async {
      final h = _Harness(installed: false);
      expect(await h.init(), SpeechInit.needsModel);
    });

    test('loads nothing yet', () async {
      final h = _Harness();
      await h.init();
      expect(h.spawns, 0);
      expect(h.mic.starts, 0);
    });
  });

  group('a listen session', () {
    test('streams the microphone to the worker and reports loudness', () async {
      final h = _Harness();
      await h.init();
      await h.listen();
      await _settle();

      h.mic.speak(samples: 1600);
      await _settle();

      expect(h.worker.fed, [1600]);
      expect(h.levels, isNotEmpty);
      expect(h.levels.single, greaterThan(0));
      expect(h.backend.isListening, isTrue);
    });

    test('delivers the transcript once the speaker stops', () async {
      final h = _Harness();
      await h.init();
      await h.listen();
      await _settle();

      h.worker
        ..emit(const SttSpeechStarted())
        ..emit(const SttSegment('what is the weather', more: false, millis: 5));
      await _settle();

      // The speaker's silence ended the segment, so the session finishes by
      // itself: flush, then one final result.
      expect(h.worker.flushes, 1);
      expect(h.results, hasLength(1));
      expect(h.results.single.isFinal, isTrue);
      expect(h.results.single.words, 'what is the weather');
      expect(h.backend.isListening, isFalse);
      expect(h.mic.stops, greaterThanOrEqualTo(1));
    });

    test('joins the pieces of a long utterance the detector had to cut',
        () async {
      final h = _Harness();
      await h.init();
      await h.listen();
      await _settle();

      h.worker
        ..emit(const SttSpeechStarted())
        ..emit(const SttSegment('first part', more: true, millis: 5));
      await _settle();
      expect(h.results, isEmpty,
          reason: 'the speaker is still talking; the session is not over');
      expect(h.backend.isListening, isTrue);

      h.worker.emit(const SttSegment('and the rest', more: false, millis: 5));
      await _settle();

      expect(h.results.single.words, 'first part and the rest');
    });

    test('stop() asks the worker to finish and delivers what it heard',
        () async {
      final h = _Harness();
      h.worker.onFlush = const [
        SttSegment('hello finn', more: false, millis: 5),
      ];
      await h.init();
      await h.listen();
      await _settle();
      h.mic.speak();

      await h.backend.stop();
      await _settle();

      expect(h.worker.flushes, 1);
      expect(h.results.single.words, 'hello finn');
      expect(h.results.single.isFinal, isTrue);
    });

    test('a stop with nothing said delivers an empty final result', () async {
      final h = _Harness();
      await h.init();
      await h.listen();
      await _settle();

      await h.backend.stop();
      await _settle();

      expect(h.results.single.words, isEmpty);
      expect(h.results.single.isFinal, isTrue);
    });

    test('cancel discards everything and delivers nothing', () async {
      final h = _Harness();
      await h.init();
      await h.listen();
      await _settle();
      h.worker.emit(const SttSegment('almost', more: true, millis: 5));

      await h.backend.cancel();
      await _settle();

      expect(h.results, isEmpty);
      expect(h.backend.isListening, isFalse);
      expect(h.worker.resets, 1);
      expect(h.mic.stops, greaterThanOrEqualTo(1));
    });

    test('a result still in flight from a cancelled session is dropped',
        () async {
      final h = _Harness();
      h.worker.autoAck = false;
      await h.init();
      await h.listen();
      await _settle();
      await h.backend.cancel();

      // The worker was mid-decode when the user cancelled: its result lands
      // after the next session has begun, and only then is the reset acked.
      await h.listen();
      await _settle();
      h.worker.emit(const SttSegment('stale words', more: false, millis: 5));
      await _settle();
      expect(h.worker.flushes, 0, reason: 'a stale segment must not end it');
      expect(h.backend.isListening, isTrue);

      h.worker.emit(const SttResetDone());
      h.worker.emit(const SttSegment('fresh words', more: false, millis: 5));
      await _settle();

      expect(h.results.single.words, 'fresh words');
    });

    test('silence gives up quietly after the no-speech timeout', () async {
      final h = _Harness(noSpeech: const Duration(milliseconds: 40));
      await h.init();
      await h.listen();

      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(h.failures.single.kind, SpeechFailureKind.noSpeech);
      expect(h.backend.isListening, isFalse);
      expect(h.results, isEmpty);
    });

    test('hearing speech cancels the no-speech timeout', () async {
      final h = _Harness(noSpeech: const Duration(milliseconds: 60));
      await h.init();
      await h.listen();
      await _settle();
      h.worker.emit(const SttSpeechStarted());

      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(h.failures, isEmpty);
      expect(h.backend.isListening, isTrue);
    });

    test('a session ends by itself at the maximum length', () async {
      final h = _Harness(max: const Duration(milliseconds: 40));
      await h.init();
      await h.listen();
      await _settle();

      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(h.worker.flushes, 1);
      expect(h.results, hasLength(1));
      expect(h.backend.isListening, isFalse);
    });

    test('a microphone that will not start throws for the controller',
        () async {
      final h = _Harness();
      h.mic.throwOnStart = true;
      await h.init();

      await expectLater(h.listen(), throwsStateError);
      expect(h.backend.isListening, isFalse);
    });
  });

  group('while the models are loading', () {
    test('keeps the audio and feeds it once the worker is ready', () async {
      final h = _Harness(loadDelay: const Duration(milliseconds: 40));
      await h.init();
      await h.listen();

      h.mic.speak(samples: 800);
      h.mic.speak(samples: 800);
      await _settle();
      expect(h.worker.fed, isEmpty, reason: 'the worker is not up yet');

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(h.worker.fed, [800, 800],
          reason: 'the first words of the question must not be lost');
    });

    test('a stop during the load flushes once the worker is up', () async {
      final h = _Harness(loadDelay: const Duration(milliseconds: 40));
      h.worker.onFlush = const [
        SttSegment('quick one', more: false, millis: 5),
      ];
      await h.init();
      await h.listen();
      h.mic.speak();
      await _settle();

      await h.backend.stop();
      expect(h.results, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(h.results.single.words, 'quick one');
    });

    test('a model that will not load is reported as unavailable', () async {
      final h = _Harness(failLoad: true);
      await h.init();
      await h.listen();
      await _settle();

      expect(h.failures.single.kind, SpeechFailureKind.unavailable);
      expect(h.backend.isListening, isFalse);
    });

    test('the worker is loaded once and reused across sessions', () async {
      final h = _Harness();
      await h.init();
      await h.listen();
      await _settle();
      await h.backend.cancel();
      await h.listen();
      await _settle();

      expect(h.spawns, 1);
    });
  });

  group('failures and release', () {
    test('a worker error is reported and the worker is not reused', () async {
      final h = _Harness();
      await h.init();
      await h.listen();
      await _settle();

      h.worker.emit(const SttFailed('boom'));
      await _settle();

      expect(h.failures.single.kind, SpeechFailureKind.unavailable);
      expect(h.worker.disposed, isTrue);

      await h.listen();
      await _settle();
      expect(h.spawns, 2);
    });

    test('release frees the worker and the microphone', () async {
      final h = _Harness();
      await h.init();
      await h.listen();
      await _settle();

      await h.backend.release();

      expect(h.worker.disposed, isTrue);
      expect(h.mic.disposed, isTrue);
      expect(h.backend.isListening, isFalse);
    });

    test('release during a load still frees the model that finishes loading',
        () async {
      final h = _Harness(loadDelay: const Duration(milliseconds: 40));
      await h.init();
      await h.listen();

      await h.backend.release();

      expect(h.worker.disposed, isTrue,
          reason: 'a model that finishes loading after release would sit in '
              'memory with nobody holding it');
    });

    test('the backend can listen again after a release', () async {
      final h = _Harness();
      await h.init();
      await h.listen();
      await _settle();
      await h.backend.release();

      await h.init();
      await h.listen();
      await _settle();

      expect(h.backend.isListening, isTrue);
      expect(h.spawns, 2);
    });
  });
}
