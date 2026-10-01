import 'dart:typed_data';

/// What the worker tells the backend.
sealed class SttEvent {
  const SttEvent();
}

/// The voice activity detector heard speech start.
class SttSpeechStarted extends SttEvent {
  const SttSpeechStarted();
}

/// One finished stretch of speech, transcribed. [more] is true when the
/// speaker is still talking (the detector cut a very long stretch), so the
/// session is not over.
class SttSegment extends SttEvent {
  const SttSegment(
    this.text, {
    required this.more,
    required this.millis,
    this.language,
  });

  final String text;
  final bool more;

  /// How long the recogniser took on this segment, for `FINN_STT` timing.
  final int millis;

  /// The language Whisper detected (`en`, `<|ru|>`...), if it said.
  final String? language;
}

/// [SttWorker.flush] has been fully processed.
class SttFlushed extends SttEvent {
  const SttFlushed();
}

/// [SpeechWorker.reset] has been processed. Everything the worker sent before
/// this belongs to a session that is over.
class SttResetDone extends SttEvent {
  const SttResetDone();
}

class SttFailed extends SttEvent {
  const SttFailed(this.message);

  final String message;
}

/// A loaded recogniser the backend feeds audio to. The real one lives on its
/// own isolate; the backend's tests use a scripted one.
abstract class SpeechWorker {
  Stream<SttEvent> get events;

  void feed(Float32List samples);

  /// Forces the detector to finish whatever it is holding. A [SttFlushed]
  /// follows once every resulting segment has been sent.
  void flush();

  /// Drops audio and detector state without producing results.
  void reset();

  void dispose();
}
