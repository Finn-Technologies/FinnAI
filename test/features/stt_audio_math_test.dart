import 'dart:typed_data';

import 'package:finn_ai/src/features/voice/stt/audio_math.dart';
import 'package:finn_ai/src/features/voice/stt/transcript_filter.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _pcm(List<int> samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  group('pcm16ToFloat32', () {
    test('maps the 16-bit range onto -1..1', () {
      final out = pcm16ToFloat32(_pcm([0, 16384, -16384, -32768, 32767]));
      expect(out[0], 0);
      expect(out[1], closeTo(0.5, 1e-6));
      expect(out[2], closeTo(-0.5, 1e-6));
      expect(out[3], -1.0);
      expect(out[4], closeTo(1.0, 1e-4));
    });

    test('reads little-endian samples', () {
      // 0x0100 little-endian is bytes 00 01, which is 256.
      final out = pcm16ToFloat32(Uint8List.fromList([0x00, 0x01]));
      expect(out.single, closeTo(256 / 32768, 1e-9));
    });

    test('drops a trailing half sample instead of throwing', () {
      expect(pcm16ToFloat32(Uint8List.fromList([1, 0, 9])).length, 1);
    });

    test('handles a view into a larger buffer', () {
      final whole = _pcm([100, 200, 300]);
      final view = Uint8List.sublistView(whole, 2, 6);
      final out = pcm16ToFloat32(view);
      expect(out.length, 2);
      expect(out[0], closeTo(200 / 32768, 1e-9));
    });
  });

  group('soundLevelOf', () {
    test('silence is zero', () {
      expect(soundLevelOf(Float32List(160)), 0);
      expect(soundLevelOf(Float32List(0)), 0);
    });

    test('speech-sized signals use a useful part of the range', () {
      final level = soundLevelOf(Float32List.fromList(List.filled(160, 0.05)));
      expect(level, inExclusiveRange(0.2, 0.8));
    });

    test('a loud signal is clamped to one', () {
      expect(soundLevelOf(Float32List.fromList(List.filled(160, 0.9))), 1);
    });
  });

  group('cleanTranscript', () {
    test('keeps ordinary speech, trimmed', () {
      expect(cleanTranscript('  What is the weather today? '),
          'What is the weather today?');
    });

    test('drops bracketed non-speech tags', () {
      expect(cleanTranscript('[BLANK_AUDIO]'), '');
      expect(cleanTranscript('(music)'), '');
      expect(cleanTranscript('*coughs* hello there'), 'hello there');
    });

    test('drops a result with no letters or digits', () {
      expect(cleanTranscript('...'), '');
      expect(cleanTranscript(' - '), '');
    });

    test('keeps non-Latin scripts', () {
      expect(cleanTranscript('Привет, как дела?'), 'Привет, как дела?');
      expect(cleanTranscript('नमस्ते'), 'नमस्ते');
    });

    test('keeps a bare number', () {
      expect(cleanTranscript('42'), '42');
    });
  });
}
