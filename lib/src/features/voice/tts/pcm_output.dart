import 'dart:typed_data';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

/// Speaker output for synthesised speech: a stream of mono samples.
abstract class PcmOutput {
  /// Frames queued and not yet played, as of now (interpolated between the
  /// plugin's own reports, which only come when the buffer runs low).
  int get remainingFrames;

  Future<void> feed(Float32List samples, int sampleRate);

  /// Drops whatever has not played yet.
  Future<void> stop();
}

/// [PcmOutput] over `flutter_pcm_sound` (Android `AudioTrack`).
class PcmSoundOutput implements PcmOutput {
  int? _rate;
  int _reported = 0;
  int _reportedAtMicros = 0;
  final Stopwatch _clock = Stopwatch()..start();

  @override
  int get remainingFrames {
    final rate = _rate;
    if (rate == null) return 0;
    final elapsedFrames =
        (_clock.elapsedMicroseconds - _reportedAtMicros) * rate ~/ 1000000;
    final left = _reported - elapsedFrames;
    return left < 0 ? 0 : left;
  }

  Future<void> _setup(int rate) async {
    if (_rate == rate) return;
    if (_rate != null) await FlutterPcmSound.release();
    await FlutterPcmSound.setup(sampleRate: rate, channelCount: 1);
    // Ask to be told when under a second is queued, so the count stays honest.
    await FlutterPcmSound.setFeedThreshold(rate);
    FlutterPcmSound.setFeedCallback((remaining) {
      _reported = remaining;
      _reportedAtMicros = _clock.elapsedMicroseconds;
    });
    _rate = rate;
  }

  @override
  Future<void> feed(Float32List samples, int sampleRate) async {
    await _setup(sampleRate);
    final pcm = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      pcm[i] = (v * 32767).round();
    }
    // Account for what this adds before the plugin has a chance to report.
    _reported = remainingFrames + pcm.length;
    _reportedAtMicros = _clock.elapsedMicroseconds;
    await FlutterPcmSound.feed(PcmArrayInt16.fromList(pcm));
    FlutterPcmSound.start();
  }

  @override
  Future<void> stop() async {
    if (_rate == null) return;
    await FlutterPcmSound.release();
    _rate = null;
    _reported = 0;
  }
}
