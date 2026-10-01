import 'dart:typed_data';

import 'package:record/record.dart';

import 'package:finn_ai/src/features/voice/stt/audio_math.dart';

/// The microphone as 16 kHz mono signed 16-bit PCM.
abstract class MicSource {
  /// Checks the permission, asking for it if it has not been asked.
  Future<bool> hasPermission();

  Future<Stream<Uint8List>> start();

  Future<void> stop();

  Future<void> dispose();
}

class RecordMicSource implements MicSource {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<Stream<Uint8List>> start() => _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sttSampleRate,
          numChannels: 1,
        ),
      );

  @override
  Future<void> stop() => _recorder.stop();

  @override
  Future<void> dispose() => _recorder.dispose();
}
