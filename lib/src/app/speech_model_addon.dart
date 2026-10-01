import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/onboarding/model_install.dart';
import 'package:finn_ai/src/features/voice/stt/speech_backend.dart';
import 'package:finn_ai/src/features/voice/stt/stt_model_store.dart';

/// The on-device speech model, offered during first run and on upgrade.
///
/// Lives in `app/` because it is the one place allowed to know both
/// onboarding (which wants "an add-on") and voice (which owns the files).
class SpeechModelAddon implements InstallAddon {
  SpeechModelAddon({SttModelStore? store})
      : _store = store ?? SttModelStore.instance {
    _store.status.addListener(_sync);
  }

  final SttModelStore _store;
  final ValueNotifier<double> _progress = ValueNotifier(0);

  void _sync() {
    final status = _store.status.value;
    _progress.value = switch (status.phase) {
      SpeechModelPhase.downloading => status.progress,
      SpeechModelPhase.ready => 1,
      _ => _progress.value,
    };
  }

  @override
  int get totalBytes => _store.totalBytes;

  @override
  ValueListenable<double> get progress => _progress;

  @override
  Future<bool> isInstalled() async {
    final installed = await _store.isInstalled();
    if (installed) _progress.value = 1;
    return installed;
  }

  @override
  Future<bool> shouldOfferOnUpgrade() async =>
      !await _store.isInstalled() && !await _store.installFailedBefore();

  @override
  Future<void> install() => _store.download();

  @override
  Future<void> markFailed() => _store.markInstallFailed();
}
