import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// The two apps inside the app.
///
/// FinnAI is the private assistant. FinnAI Code is a coding agent with its own
/// sessions, settings and providers, in the same design language. They share
/// the on-device model, and nothing else: chats stay in FinnAI, sessions stay
/// in FinnAI Code.
enum FinnAppMode { chat, code }

/// Which of the two is showing, remembered across launches.
class AppModeController extends ChangeNotifier {
  AppModeController({this.directoryProvider});

  static final instance = AppModeController();

  @visibleForTesting
  final Future<Directory> Function()? directoryProvider;

  FinnAppMode _mode = FinnAppMode.chat;
  bool _initialized = false;

  FinnAppMode get mode => _mode;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final file = await _file();
      if (await file.exists()) {
        final stored = (await file.readAsString()).trim();
        _mode = FinnAppMode.values.firstWhere(
          (value) => value.name == stored,
          orElse: () => FinnAppMode.chat,
        );
      }
    } catch (_) {
      // Unreadable: start in FinnAI.
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> set(FinnAppMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(mode.name, flush: true);
    } catch (_) {
      // The switch still applies for this run.
    }
  }

  /// Back to FinnAI, forgetting the choice.
  Future<void> deleteStorage() async {
    _mode = FinnAppMode.chat;
    notifyListeners();
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<File> _file() async {
    final directory = directoryProvider != null
        ? await directoryProvider!()
        : await getApplicationSupportDirectory();
    return File('${directory.path}/app_mode.txt');
  }
}
