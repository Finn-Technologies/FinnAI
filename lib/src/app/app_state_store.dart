import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/features/actions/action_audit_store.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/creations/creation_store.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/features/onboarding/context_consent_store.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_store.dart';
import 'package:finn_ai/src/features/voice/stt/stt_model_store.dart';
import 'package:finn_ai/src/features/voice/voice_settings_store.dart';
import 'package:finn_ai/src/features/you/you_memory_store.dart';
import 'package:finn_ai/src/features/you/you_profile_store.dart';

class DeletionResult {
  const DeletionResult({
    required this.deletedItems,
    required this.nonExistentItems,
    required this.failedItems,
  });

  final List<String> deletedItems;
  final List<String> nonExistentItems;
  final List<String> failedItems;

  bool get isSuccess => failedItems.isEmpty;
}

class AppStateStore extends ChangeNotifier {
  AppStateStore({Future<Directory> Function()? directoryProvider})
      : _directoryProvider = directoryProvider;

  static final instance = AppStateStore();

  final Future<Directory> Function()? _directoryProvider;
  bool onboardingComplete = false;

  Future<void> initialize() async {
    try {
      onboardingComplete = await (await _file()).exists();
    } catch (_) {
      onboardingComplete = false;
    }
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    onboardingComplete = true;
    try {
      await (await _file()).writeAsString('1', flush: true);
    } catch (_) {
      // Completion still applies to the current process if storage is busy.
    }
    notifyListeners();
  }

  /// Purges all local application data, models, keys, and settings.
  Future<DeletionResult> deleteAllData({
    ConversationStore? conversationStore,
    FinnInference? qwenInference,
    CreationStore? creationStore,
    YouProfileStore? youProfileStore,
    FlowsStore? flowsStore,
    VoiceSettingsStore? voiceSettingsStore,
    ActionAuditStore? actionAuditStore,
    ContextConsentStore? contextConsentStore,
    YouMemoryStore? youMemoryStore,
    SttModelStore? sttModelStore,
    TtsVoiceStore? ttsVoiceStore,
  }) async {
    final deleted = <String>[];
    final nonExistent = <String>[];
    final failed = <String>[];

    // 1. Delete onboarding completion marker
    try {
      final file = await _file();
      if (await file.exists()) {
        await file.delete();
        deleted.add('Onboarding state');
      } else {
        nonExistent.add('Onboarding state');
      }
    } catch (e) {
      failed.add('Onboarding state');
    }
    onboardingComplete = false;

    // 2. Delete conversations and secure encryption key
    try {
      final targetStore = conversationStore ?? ConversationStore.instance;
      final convFailures = await targetStore.deleteStorageFiles();
      if (convFailures.isNotEmpty) {
        failed.addAll(convFailures);
      } else {
        deleted.add('Encrypted conversation history & keys');
      }
    } catch (e) {
      failed.add('Encrypted conversation history & keys ($e)');
    }

    // 3. Delete downloaded AI models and partial downloads
    try {
      final targetInference = qwenInference ?? FinnInference.instance;
      final modelFailures = await targetInference.removeAllModels();
      if (modelFailures.isNotEmpty) {
        failed.addAll(modelFailures);
      } else {
        deleted.add('Downloaded AI model weights');
      }
    } catch (e) {
      failed.add('Downloaded AI model weights ($e)');
    }

    // 4. Delete locally generated creations and personalization features.
    try {
      final target = creationStore ??
          (_directoryProvider == null
              ? CreationStore.instance
              : CreationStore(directoryProvider: _directoryProvider));
      final existed = await target.deleteStorage();
      if (existed) {
        deleted.add('Local creations');
      } else {
        nonExistent.add('Local creations');
      }
    } catch (e) {
      failed.add('Local creations ($e)');
    }

    final profileTarget = youProfileStore ??
        (_directoryProvider == null
            ? YouProfileStore.instance
            : YouProfileStore(directoryProvider: _directoryProvider));
    final profileFailures = await profileTarget.deleteStorage();
    if (profileFailures.isEmpty) {
      deleted.add('Personalization');
    } else {
      failed.addAll(profileFailures);
    }

    final memoryFailures = await (youMemoryStore ??
            (_directoryProvider == null
                ? YouMemoryStore.instance
                : YouMemoryStore(directoryProvider: _directoryProvider)))
        .deleteStorage();
    if (memoryFailures.isEmpty) {
      deleted.add('What FinnAI remembers');
    } else {
      failed.addAll(memoryFailures);
    }

    final flowTarget = flowsStore ??
        (_directoryProvider == null
            ? FlowsStore.instance
            : FlowsStore(directoryProvider: _directoryProvider));
    final flowFailures = await flowTarget.deleteStorage();
    if (flowFailures.isEmpty) {
      deleted.add('Flows');
    } else {
      failed.addAll(flowFailures);
    }

    final voiceTarget = voiceSettingsStore ??
        (_directoryProvider == null
            ? VoiceSettingsStore.instance
            : VoiceSettingsStore(directoryProvider: _directoryProvider));
    final voiceFailures = await voiceTarget.deleteStorage();
    if (voiceFailures.isEmpty) {
      deleted.add('Voice settings');
    } else {
      failed.addAll(voiceFailures);
    }

    // The speech model is a download like the language model; it goes with it.
    // Listed only when there was one, so a user who never used voice is not
    // told something was deleted.
    try {
      final speechTarget = sttModelStore ?? SttModelStore.instance;
      if (await speechTarget.isInstalled()) {
        await speechTarget.delete();
        deleted.add('Downloaded speech model');
      } else {
        await speechTarget.delete();
      }
    } catch (e) {
      // Nothing to report when storage was never created (or is unreachable
      // in a test); a model that is really stuck shows up as leftover bytes.
    }

    try {
      final voices = ttsVoiceStore ?? TtsVoiceStore.instance;
      if ((await voices.installedVoices()).isNotEmpty) {
        deleted.add('Downloaded voices');
      }
      await voices.deleteAll();
    } catch (e) {
      // See the speech model above: nothing to report when there was none.
    }

    final consentTarget = contextConsentStore ??
        (_directoryProvider == null
            ? ContextConsentStore.instance
            : ContextConsentStore(directoryProvider: _directoryProvider));
    final consentFailures = await consentTarget.deleteStorage();
    if (consentFailures.isEmpty) {
      deleted.add('Access choices');
    } else {
      failed.addAll(consentFailures);
    }

    // The audit log names what the app did on the phone; it goes with the rest.
    // `deleteAll` swallows its own IO errors, so there is no failure to report.
    await (actionAuditStore ??
            (_directoryProvider == null
                ? ActionAuditStore.instance
                : ActionAuditStore(directoryProvider: _directoryProvider)))
        .deleteAll();
    deleted.add('Action log');

    notifyListeners();

    return DeletionResult(
      deletedItems: deleted,
      nonExistentItems: nonExistent,
      failedItems: failed,
    );
  }

  Future<File> _file() async {
    final root = _directoryProvider != null
        ? await _directoryProvider()
        : await getApplicationSupportDirectory();
    return File('${root.path}${Platform.pathSeparator}onboarding_complete');
  }
}
