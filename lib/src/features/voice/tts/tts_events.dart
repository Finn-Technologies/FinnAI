import 'dart:typed_data';

/// What the synthesis worker tells the backend.
sealed class TtsEvent {
  const TtsEvent();
}

/// Some audio for utterance [id], as -1..1 floats.
class TtsChunk extends TtsEvent {
  const TtsChunk(this.id, this.samples, this.sampleRate);

  final int id;
  final Float32List samples;
  final int sampleRate;
}

/// Utterance [id] has been fully synthesised.
class TtsSynthDone extends TtsEvent {
  const TtsSynthDone(this.id,
      {required this.millis, required this.audioMillis});

  final int id;

  /// How long synthesis took, and how much audio it made: their ratio is the
  /// real-time factor, which is what decides whether speech can keep up.
  final int millis;
  final int audioMillis;
}

class TtsFailed extends TtsEvent {
  const TtsFailed(this.message, {this.id});

  final String message;
  final int? id;
}

/// A loaded voice the backend sends sentences to. The real one lives on its
/// own isolate; the backend's tests use a scripted one.
abstract class TtsEngine {
  Stream<TtsEvent> get events;

  /// Starts synthesising [text]. Chunks and one [TtsSynthDone] follow.
  void synth(int id, String text, double speed);

  /// Stops whatever is being synthesised as soon as the engine can.
  void cancelAll();

  void dispose();
}
