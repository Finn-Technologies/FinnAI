import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppStateStore {
  AppStateStore._();

  static final instance = AppStateStore._();

  bool onboardingComplete = false;

  Future<void> initialize() async {
    try {
      onboardingComplete = await (await _file()).exists();
    } catch (_) {
      onboardingComplete = false;
    }
  }

  Future<void> completeOnboarding() async {
    onboardingComplete = true;
    try {
      await (await _file()).writeAsString('1', flush: true);
    } catch (_) {
      // Completion still applies to the current process if storage is busy.
    }
  }

  Future<File> _file() async {
    final root = await getApplicationSupportDirectory();
    return File('${root.path}${Platform.pathSeparator}onboarding_complete');
  }
}
