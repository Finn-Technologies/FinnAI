import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'package:finn_ai/src/features/voice/tts/supertonic_native.dart';
import 'package:finn_ai/src/features/voice/tts/supertonic_text.dart';
import 'package:finn_ai/src/features/voice/tts/tts_events.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_catalog.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_store.dart';

/// Two, not more: the language model is generating while this runs, and the two
/// compete for the same cores. Measured on a Snapdragon 778G, three threads for
/// the old voice took the model from ~16 to ~10 tokens a second.
const _threads = 2;

/// How many denoising steps the voice takes per piece of speech. More is
/// smoother and slower; the reference defaults to 8, which is more than a phone
/// can afford while the language model is running.
const _steps = 5;

/// The model's own default pace; the app's speed setting scales it.
const _basePace = 1.05;

/// One voice, loaded on its own isolate.
///
/// A synthesis of a sentence is a few synchronous native calls, so it cannot
/// hear a "cancel" message that arrives while it runs. The cancel flag lives in
/// native memory both isolates can see and is read between pieces, so a stop
/// takes effect at the next piece boundary (about a sentence).
class SupertonicWorker implements TtsEngine {
  SupertonicWorker._(this._isolate, this._commands, this.events, this._epoch);

  final Isolate _isolate;
  final SendPort _commands;

  /// Native memory both isolates read. Bumping it cancels everything sent
  /// before it.
  final Pointer<Int32> _epoch;

  @override
  final Stream<TtsEvent> events;

  static Future<SupertonicWorker> spawn(TtsVoicePaths paths) async {
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
      return SupertonicWorker._(isolate, commands, controller.stream, flag);
    } catch (_) {
      isolate.kill(priority: Isolate.immediate);
      inbox.close();
      calloc.free(flag);
      await controller.close();
      rethrow;
    }
  }

  @override
  void synth(int id, String text, double speed,
          {String? language, String? style}) =>
      _commands.send([id, text, speed, _epoch.value, language ?? 'en', style]);

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

/// Reads a style file: `{"style_ttl": {"data": [[[…]]], "dims": [1,50,256]}, …}`.
SupertonicStyle readStyle(String source) {
  final json = jsonDecode(source) as Map<String, Object?>;
  (Float32List, List<int>) tensor(String key) {
    final entry = json[key]! as Map<String, Object?>;
    final values = <double>[];
    void walk(Object? node) {
      if (node is List) {
        node.forEach(walk);
      } else if (node is num) {
        values.add(node.toDouble());
      }
    }

    walk(entry['data']);
    final dims = [for (final d in entry['dims']! as List) (d as num).toInt()];
    return (Float32List.fromList(values), dims);
  }

  final (ttl, ttlDims) = tensor('style_ttl');
  final (dp, dpDims) = tensor('style_dp');
  return SupertonicStyle(ttl: ttl, ttlDims: ttlDims, dp: dp, dpDims: dpDims);
}

void _entry(_Boot boot) {
  final inbox = ReceivePort();
  final epoch = Pointer<Int32>.fromAddress(boot.epochAddress);
  late final SupertonicNative native;
  late final SupertonicConfig config;
  late final List<int> indexer;
  final styles = <String, SupertonicStyle>{};
  try {
    native =
        SupertonicNative.load(boot.paths.modelDirectory, threads: _threads);
    config = SupertonicConfig.fromJson(
      jsonDecode(File(boot.paths.config).readAsStringSync())
          as Map<String, Object?>,
    );
    indexer = [
      for (final v
          in jsonDecode(File(boot.paths.indexer).readAsStringSync()) as List)
        (v as num).toInt(),
    ];
  } catch (error) {
    boot.reply.send(TtsFailed('$error'));
    return;
  }

  SupertonicStyle styleFor(String name) => styles.putIfAbsent(
        name,
        () => readStyle(File(boot.paths.style(name)).readAsStringSync()),
      );

  inbox.listen((Object? message) {
    if (message == 'dispose') {
      native.dispose();
      inbox.close();
      return;
    }
    if (message is! List) return;
    final id = message[0] as int;
    final text = message[1] as String;
    final speed = message[2] as double;
    final sentIn = message[3] as int;
    final language = message[4] as String;
    final requestedStyle = message.length > 5 ? message[5] as String? : null;
    // Cancelled before it started.
    if (sentIn != epoch.value) {
      boot.reply.send(TtsSynthDone(id, millis: 0, audioMillis: 0));
      return;
    }
    final watch = Stopwatch()..start();
    var samples = 0;
    try {
      final style = styleFor(
        requestedStyle != null && ttsStyles.contains(requestedStyle)
            ? requestedStyle
            : defaultTtsStyle,
      );
      for (final piece in SupertonicText.chunk(
        text,
        maxLength: SupertonicText.maxChunk(language),
      )) {
        if (epoch.value != sentIn) break;
        final ids = SupertonicText.ids(
          SupertonicText.preprocess(piece, language),
          indexer,
        );
        if (ids.length < 4) continue;
        final audio = native.infer(
          ids: ids,
          style: style,
          config: config,
          steps: _steps,
          speed: speed * _basePace,
        );
        samples += audio.length;
        boot.reply.send(TtsChunk(id, audio, config.sampleRate));
      }
      boot.reply.send(
        TtsSynthDone(
          id,
          millis: watch.elapsedMilliseconds,
          audioMillis: samples * 1000 ~/ config.sampleRate,
        ),
      );
    } catch (error) {
      boot.reply.send(TtsFailed('$error', id: id));
    }
  });
  boot.reply.send(inbox.sendPort);
}
