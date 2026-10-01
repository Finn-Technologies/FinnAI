import 'dart:math' as math;
import 'dart:typed_data';

/// Sample rate the recogniser and the voice activity detector both expect.
const int sttSampleRate = 16000;

/// Converts little-endian signed 16-bit PCM to the -1..1 floats sherpa takes.
///
/// A trailing odd byte (half a sample) is dropped; the recorder hands whole
/// samples, so that only guards a malformed buffer.
Float32List pcm16ToFloat32(Uint8List bytes) {
  final count = bytes.length ~/ 2;
  final out = Float32List(count);
  final view = ByteData.sublistView(bytes);
  for (var i = 0; i < count; i++) {
    out[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

/// Loudness of a buffer as 0..1, for the orb. RMS with a gain, because speech
/// sits around 0.02-0.2 and the orb needs the whole range to look alive.
double soundLevelOf(Float32List samples) {
  if (samples.isEmpty) return 0;
  var sum = 0.0;
  for (final s in samples) {
    sum += s * s;
  }
  final rms = math.sqrt(sum / samples.length);
  return (rms * 8).clamp(0.0, 1.0);
}
