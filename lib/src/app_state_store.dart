import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'conversations/conversation_store.dart';
import 'inference/bonsai_inference.dart';

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
  AppStateStore({this._directoryProvider});

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
    BonsaiInference? bonsaiInference,
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
      final targetInference = bonsaiInference ?? BonsaiInference.instance;
      final modelFailures = await targetInference.removeAllModels();
      if (modelFailures.isNotEmpty) {
        failed.addAll(modelFailures);
      } else {
        deleted.add('Downloaded AI model weights');
      }
    } catch (e) {
      failed.add('Downloaded AI model weights ($e)');
    }

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
