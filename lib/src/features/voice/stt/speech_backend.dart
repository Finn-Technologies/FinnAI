import 'package:flutter/foundation.dart';

/// What the recogniser has heard so far in one listen session.
@immutable
class SpeechResult {
  const SpeechResult(this.words, {required this.isFinal, this.language});

  final String words;
  final bool isFinal;

  /// The language detected in the speech, when the recogniser knows it.
  final String? language;
}

enum SpeechFailureKind {
  /// The microphone permission is off.
  permission,

  /// Nothing was said before the session gave up. Not an error to show.
  noSpeech,

  /// The recogniser or its model cannot run on this device.
  unavailable,
}

@immutable
class SpeechFailure {
  const SpeechFailure(this.kind, [this.message = '']);

  final SpeechFailureKind kind;
  final String message;
}

/// The outcome of preparing the recogniser, before any listening starts.
enum SpeechInit {
  ready,
  micDenied,

  /// The on-device speech model has not been downloaded yet.
  needsModel,
  unavailable,
}

enum SpeechModelPhase { missing, downloading, ready, failed }

/// The state of the on-device speech model, for the UI to render.
@immutable
class SpeechModelStatus {
  const SpeechModelStatus(this.phase, {this.progress = 0, this.totalBytes = 0});

  static const missing = SpeechModelStatus(SpeechModelPhase.missing);
  static const ready = SpeechModelStatus(SpeechModelPhase.ready);

  final SpeechModelPhase phase;

  /// 0..1 while [phase] is [SpeechModelPhase.downloading].
  final double progress;
  final int totalBytes;

  @override
  bool operator ==(Object other) =>
      other is SpeechModelStatus &&
      other.phase == phase &&
      other.progress == progress &&
      other.totalBytes == totalBytes;

  @override
  int get hashCode => Object.hash(phase, progress, totalBytes);
}

/// Speech in. The controller depends on this, never on a recogniser package.
abstract class SpeechBackend {
  /// Checks the microphone permission and that the speech model is installed.
  /// Cheap: nothing heavy is loaded until [listen].
  Future<SpeechInit> initialize(
      {void Function(SpeechFailure failure)? onFailure});

  bool get isListening;

  /// Starts one utterance. [onResult] fires with `isFinal: true` exactly once,
  /// when the speaker stops (or after [stop]).
  Future<void> listen({
    void Function(SpeechResult result)? onResult,
    void Function(double level)? onSoundLevelChange,
  });

  /// Ends the session and delivers whatever was heard as the final result.
  Future<void> stop();

  /// Ends the session and discards anything heard.
  Future<void> cancel();

  /// Frees the recogniser and everything it holds. Safe to call at any time;
  /// the next [listen] loads it again.
  Future<void> release();

  ValueListenable<SpeechModelStatus> get model;

  /// Downloads the speech model. Completes when it is installed, throws when
  /// it could not be.
  Future<void> downloadModel();
}
