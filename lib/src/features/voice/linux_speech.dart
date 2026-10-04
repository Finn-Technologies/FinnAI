import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Reads text aloud on desktop Linux through the speech synthesiser the
/// distribution already provides.
///
/// `flutter_tts` has no Linux implementation, so there is nothing for it to
/// call. Speech Dispatcher (`spd-say`) is what GNOME and KDE ship; `espeak-ng`
/// is the common bare-bones fallback. Neither is bundled: the text goes to a
/// local process on this computer and nowhere else.
class LinuxSpeech {
  LinuxSpeech({
    Future<Process> Function(String, List<String>)? start,
    Future<bool> Function(String)? exists,
  })  : _start = start ?? Process.start,
        _exists = exists ?? _onPath;

  static final instance = LinuxSpeech();

  final Future<Process> Function(String, List<String>) _start;
  final Future<bool> Function(String) _exists;

  /// In preference order.
  static const synthesisers = ['spd-say', 'espeak-ng', 'espeak'];

  Process? _running;
  String? _engine;
  bool _searched = false;

  /// The synthesiser found on this system, or `null` when there is none.
  Future<String?> engine() async {
    if (_searched) return _engine;
    for (final candidate in synthesisers) {
      if (await _exists(candidate)) {
        _engine = candidate;
        break;
      }
    }
    _searched = true;
    return _engine;
  }

  /// The arguments that make [engine] say [text] and wait until it is done.
  ///
  /// [rate] is the app's text-to-speech rate (0.45 is normal speed) and
  /// [languageCode] a bare language such as `en`. The text follows `--`, so a
  /// reply that begins with a dash is read, not parsed as an option.
  @visibleForTesting
  static List<String> arguments(
    String engine,
    String text, {
    required double rate,
    String? languageCode,
  }) {
    final language = languageCode == null || languageCode.isEmpty
        ? const <String>[]
        : ['-l', languageCode];
    if (engine == 'spd-say') {
      final percent = ((rate - .45) * 330).round().clamp(-100, 100);
      return ['--wait', '-r', '$percent', ...language, '--', text];
    }
    final wordsPerMinute = (175 + (rate - .45) * 350).round().clamp(80, 450);
    return ['-s', '$wordsPerMinute', ...language, '--', text];
  }

  /// Speaks [text], replacing anything already being said. Returns false when
  /// no synthesiser is installed.
  Future<bool> speak(
    String text, {
    required double rate,
    String? languageCode,
  }) async {
    final engine = await this.engine();
    if (engine == null) return false;
    await stop();
    try {
      final process = await _start(
        engine,
        arguments(engine, text, rate: rate, languageCode: languageCode),
      );
      _running = process;
      // Nothing reads the output; an unread pipe would eventually block it.
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      unawaited(process.exitCode.then((_) {
        if (identical(_running, process)) _running = null;
      }));
      return true;
    } catch (error) {
      debugPrint('FINN_LINUX_TTS failed to start $engine: $error');
      return false;
    }
  }

  Future<void> stop() async {
    final process = _running;
    _running = null;
    if (process == null) return;
    process.kill();
    if (_engine == 'spd-say') {
      // The client only queues text on the server, so it has to be cancelled
      // there as well.
      try {
        await Process.run('spd-say', ['-C']);
      } catch (_) {}
    }
  }

  static Future<bool> _onPath(String command) async {
    try {
      final result = await Process.run('which', [command]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
