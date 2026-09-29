import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Whether the user lets FinnAI use context from this device.
///
/// Asked once during onboarding and changeable afterwards from Settings. It
/// defaults to allowed: the app only ever reads context on-device, and installs
/// that predate the question never had the chance to answer it.
class ContextConsentStore extends ChangeNotifier {
  ContextConsentStore({this.directoryProvider});

  static final instance = ContextConsentStore();

  @visibleForTesting
  final Future<Directory> Function()? directoryProvider;

  bool _granted = true;
  bool _initialized = false;
  Future<void>? _initializeJob;

  bool get granted => _granted;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    final running = _initializeJob;
    if (running != null) return running;
    final job = _initialize();
    _initializeJob = job;
    try {
      await job;
    } finally {
      if (identical(_initializeJob, job)) _initializeJob = null;
    }
  }

  Future<void> _initialize() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        final json = (decoded as Map<Object?, Object?>).cast<String, Object?>();
        if (json['granted'] is bool) _granted = json['granted']! as bool;
      }
    } catch (_) {
      // An unreadable file keeps the default rather than blocking onboarding.
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<bool> setGranted(bool value) async {
    _granted = value;
    notifyListeners();
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(
        jsonEncode({'version': 1, 'granted': value}),
        flush: true,
      );
      await temporary.rename(file.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<File> _file() async {
    final directory = directoryProvider != null
        ? await directoryProvider!()
        : await getApplicationSupportDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}context_consent.json',
    );
  }
}
