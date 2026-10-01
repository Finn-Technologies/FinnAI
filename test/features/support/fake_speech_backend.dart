import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/voice/voice_chat_controller.dart';

/// A scripted [SpeechBackend] for the controller and the voice sheet.
class FakeSpeechBackend implements SpeechBackend {
  SpeechInit initResult = SpeechInit.ready;
  bool listening = false;
  bool throwOnListen = false;
  bool throwOnDownload = false;
  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int releaseCalls = 0;
  int downloadCalls = 0;
  void Function(SpeechResult result)? onResult;
  void Function(double level)? onSoundLevel;
  void Function(SpeechFailure failure)? onFailure;

  final ValueNotifier<SpeechModelStatus> modelStatus =
      ValueNotifier(SpeechModelStatus.missing);

  @override
  ValueListenable<SpeechModelStatus> get model => modelStatus;

  @override
  Future<SpeechInit> initialize({
    void Function(SpeechFailure failure)? onFailure,
  }) async {
    this.onFailure = onFailure;
    return initResult;
  }

  @override
  bool get isListening => listening;

  @override
  Future<void> listen({
    void Function(SpeechResult result)? onResult,
    void Function(double level)? onSoundLevelChange,
  }) async {
    if (throwOnListen) throw StateError('listen failed');
    listenCalls++;
    this.onResult = onResult;
    onSoundLevel = onSoundLevelChange;
    listening = true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    listening = false;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    listening = false;
  }

  @override
  Future<void> release() async {
    releaseCalls++;
    listening = false;
  }

  @override
  Future<void> downloadModel() async {
    downloadCalls++;
    if (throwOnDownload) {
      modelStatus.value = const SpeechModelStatus(SpeechModelPhase.failed);
      throw StateError('offline');
    }
    modelStatus.value = SpeechModelStatus.ready;
    initResult = SpeechInit.ready;
  }

  void emitResult(
    String words, {
    required bool finalResult,
    String? language,
  }) =>
      onResult?.call(
        SpeechResult(words, isFinal: finalResult, language: language),
      );

  void fail(SpeechFailureKind kind) => onFailure?.call(SpeechFailure(kind));
}
