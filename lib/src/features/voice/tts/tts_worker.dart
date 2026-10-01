import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'package:finn_ai/src/features/voice/tts/tts_events.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_store.dart';

/// Two, not more: the language model is generating while this runs, and the
/// two compete for the same cores. Measured on a Snapdragon 778G, three
/// threads here took the model from ~16 to ~10 tokens a second.
const _threads = 2;

/// One voice, loaded on its own isolate.
///
/// A synthesis is one long synchronous native call, so it cannot hear a
/// "cancel" message that arrives while it runs. The cancel flag therefore
/// lives in native memory both isolates can see, and the chunk callback reads
/// it between chunks. This and `stt_worker.dart` are the only files that
/// import `package:sherpa_onnx`.
class TtsWorker implements TtsEngine {
  TtsWorker._(this._isolate, this._commands, this.events, this._epoch);

  final Isolate _isolate;
  final SendPort _commands;

  /// Native memory both isolates read. Bumping it cancels everything sent
  /// before: the synthesis in flight stops at its next chunk, and queued
  /// requests, which carry the epoch they were sent in, are skipped.
  final Pointer<Int32> _epoch;

  @override
  final Stream<TtsEvent> events;

  static Future<TtsWorker> spawn(TtsVoicePaths paths) async {
    final inbox = ReceivePort();
    final flag = calloc<Int32>();
    flag.value = 0;
    final isolate = await Isolate.spawn(
      _entry,
      _Boot(inbox.sendPort, paths, flag.address),
      errorsAreFatal: false,
    );
    final controller = StreamController<TtsEvent>.broadcast();
    final ready = Completer<SendPort>();
    inbox.listen((Object? message) {
      if (message is SendPort) {
        if (!ready.isCompleted) ready.complete(message);
      } else if (message is TtsEvent) {
        if (message is TtsFailed && !ready.isCompleted) {
          ready.completeError(StateError(message.message));
        } else {
          controller.add(message);
        }
      }
    });
    try {
      final commands = await ready.future;
      return TtsWorker._(isolate, commands, controller.stream, flag);
    } catch (_) {
      isolate.kill(priority: Isolate.immediate);
      inbox.close();
      calloc.free(flag);
      await controller.close();
      rethrow;
    }
  }

  @override
  void synth(int id, String text, double speed) =>
      _commands.send([id, text, speed, _epoch.value]);

  @override
  void cancelAll() => _epoch.value = _epoch.value + 1;

  @override
  void dispose() {
    cancelAll();
    _commands.send('dispose');
    Timer(const Duration(seconds: 2), () {
      _isolate.kill();
      calloc.free(_epoch);
    });
  }
}

class _Boot {
  const _Boot(this.reply, this.paths, this.epochAddress);

  final SendPort reply;
  final TtsVoicePaths paths;
  final int epochAddress;
}

void _entry(_Boot boot) {
  final inbox = ReceivePort();
  final epoch = Pointer<Int32>.fromAddress(boot.epochAddress);
  late final sherpa.OfflineTts tts;
  try {
    sherpa.initBindings();
    tts = sherpa.OfflineTts(
      sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: boot.paths.model,
            tokens: boot.paths.tokens,
            dataDir: boot.paths.dataDir,
          ),
          numThreads: _threads,
          debug: false,
        ),
        maxNumSenetences: 1,
      ),
    );
  } catch (error) {
    boot.reply.send(TtsFailed('$error'));
    return;
  }

  inbox.listen((Object? message) {
    if (message == 'dispose') {
      tts.free();
      inbox.close();
      return;
    }
    if (message is! List) return;
    final id = message[0] as int;
    final text = message[1] as String;
    final speed = message[2] as double;
    final sentIn = message[3] as int;
    // Cancelled before it started.
    if (sentIn != epoch.value) {
      boot.reply.send(TtsSynthDone(id, millis: 0, audioMillis: 0));
      return;
    }
    final watch = Stopwatch()..start();
    var samples = 0;
    var rate = tts.sampleRate;
    try {
      tts.generateWithCallback(
        text: text,
        speed: speed,
        callback: (chunk) {
          samples += chunk.length;
          boot.reply.send(TtsChunk(id, chunk, rate));
          // 1 keeps going, 0 asks the native side to stop.
          return epoch.value == sentIn ? 1 : 0;
        },
      );
      boot.reply.send(
        TtsSynthDone(
          id,
          millis: watch.elapsedMilliseconds,
          audioMillis: rate == 0 ? 0 : samples * 1000 ~/ rate,
        ),
      );
    } catch (error) {
      boot.reply.send(TtsFailed('$error', id: id));
    }
  });
  boot.reply.send(inbox.sendPort);
}
