import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'package:finn_ai/src/features/voice/stt/audio_math.dart';
import 'package:finn_ai/src/features/voice/stt/stt_events.dart';
import 'package:finn_ai/src/features/voice/stt/stt_model_store.dart';
import 'package:finn_ai/src/features/voice/stt/transcript_filter.dart';

const _threads = 4;

/// Whisper handles 30s at a time. The detector cuts speech at this length so
/// a long monologue becomes several segments instead of a truncated one.
const _maxSpeechSeconds = 25.0;

/// Silence that ends an utterance. Replaces the platform recogniser's
/// `pauseFor`: long enough not to cut someone off mid-thought, short enough
/// that the reply starts promptly.
const _endSilenceSeconds = 0.7;

/// The voice activity detector and the recogniser, on their own isolate.
///
/// Both are synchronous native calls, and one Whisper decode takes long
/// enough to drop frames if it ran on the UI isolate. This is the only file
/// that imports `package:sherpa_onnx`.
class SttWorker implements SpeechWorker {
  SttWorker._(this._isolate, this._commands, this.events);

  final Isolate _isolate;
  final SendPort _commands;
  @override
  final Stream<SttEvent> events;

  /// Loads the models on a fresh isolate. Completes when it is ready to take
  /// audio, or throws if the models would not load.
  static Future<SttWorker> spawn(SttModelPaths paths) async {
    final inbox = ReceivePort();
    final isolate = await Isolate.spawn(
      _entry,
      _Boot(inbox.sendPort, paths),
      errorsAreFatal: false,
    );
    final controller = StreamController<SttEvent>.broadcast();
    final ready = Completer<SendPort>();
    inbox.listen((Object? message) {
      if (message is SendPort) {
        if (!ready.isCompleted) ready.complete(message);
      } else if (message is SttEvent) {
        if (message is SttFailed && !ready.isCompleted) {
          ready.completeError(StateError(message.message));
        } else {
          controller.add(message);
        }
      }
    });
    try {
      final commands = await ready.future;
      return SttWorker._(isolate, commands, controller.stream);
    } catch (_) {
      isolate.kill(priority: Isolate.immediate);
      inbox.close();
      await controller.close();
      rethrow;
    }
  }

  @override
  void feed(Float32List samples) => _commands.send(
        TransferableTypedData.fromList([
          samples.buffer.asUint8List(
            samples.offsetInBytes,
            samples.lengthInBytes,
          ),
        ]),
      );

  /// Forces the detector to finish whatever it is holding. A [SttFlushed]
  /// follows once every resulting segment has been sent.
  @override
  void flush() => _commands.send('flush');

  /// Drops audio and detector state without producing results.
  @override
  void reset() => _commands.send('reset');

  @override
  void dispose() {
    _commands.send('dispose');
    // The isolate exits on its own after freeing the native objects; the kill
    // is the backstop for one that is stuck inside a decode.
    Timer(const Duration(seconds: 2), () => _isolate.kill());
  }
}

class _Boot {
  const _Boot(this.reply, this.paths);

  final SendPort reply;
  final SttModelPaths paths;
}

void _entry(_Boot boot) {
  final inbox = ReceivePort();
  late final sherpa.VoiceActivityDetector vad;
  late final sherpa.OfflineRecognizer recognizer;
  try {
    sherpa.initBindings();
    vad = sherpa.VoiceActivityDetector(
      config: sherpa.VadModelConfig(
        sileroVad: sherpa.SileroVadModelConfig(
          model: boot.paths.vad,
          minSilenceDuration: _endSilenceSeconds,
          minSpeechDuration: 0.25,
          maxSpeechDuration: _maxSpeechSeconds,
        ),
        sampleRate: sttSampleRate,
        numThreads: 1,
        debug: false,
      ),
      bufferSizeInSeconds: 30,
    );
    recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: boot.paths.encoder,
            decoder: boot.paths.decoder,
            // Empty means "detect the language", so one model serves every
            // locale the app ships in and the languages beyond them.
            language: '',
            task: 'transcribe',
          ),
          tokens: boot.paths.tokens,
          numThreads: _threads,
          debug: false,
          modelType: 'whisper',
        ),
      ),
    );
  } catch (error) {
    boot.reply.send(SttFailed('$error'));
    return;
  }

  var speaking = false;

  void drain() {
    while (!vad.isEmpty()) {
      final segment = vad.front();
      // Taken before the decode: a decode is long, and whether the speaker is
      // still talking is a fact about this moment, not about when it ends.
      final more = vad.isDetected();
      vad.pop();
      final watch = Stopwatch()..start();
      final stream = recognizer.createStream();
      stream.acceptWaveform(
          samples: segment.samples, sampleRate: sttSampleRate);
      recognizer.decode(stream);
      final result = recognizer.getResult(stream);
      final text = cleanTranscript(result.text);
      stream.free();
      boot.reply.send(
        SttSegment(
          text,
          more: more,
          millis: watch.elapsedMilliseconds,
          language: result.lang,
        ),
      );
    }
  }

  inbox.listen((Object? message) {
    try {
      if (message is TransferableTypedData) {
        final bytes = message.materialize().asUint8List();
        vad.acceptWaveform(
          bytes.buffer.asFloat32List(
            bytes.offsetInBytes,
            bytes.lengthInBytes ~/ 4,
          ),
        );
        final now = vad.isDetected();
        if (now && !speaking) boot.reply.send(const SttSpeechStarted());
        speaking = now;
        drain();
      } else if (message == 'flush') {
        vad.flush();
        drain();
        speaking = false;
        boot.reply.send(const SttFlushed());
      } else if (message == 'reset') {
        vad.clear();
        vad.reset();
        speaking = false;
        boot.reply.send(const SttResetDone());
      } else if (message == 'dispose') {
        vad.free();
        recognizer.free();
        inbox.close();
      }
    } catch (error) {
      boot.reply.send(SttFailed('$error'));
    }
  });
  boot.reply.send(inbox.sendPort);
}
