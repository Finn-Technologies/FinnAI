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
  ContextConsentStore({this.directoryProvider, this.fileResolver});

  static final instance = ContextConsentStore();

  @visibleForTesting
  final Future<Directory> Function()? directoryProvider;

  /// Overrides the whole file lookup, not just the directory.
  ///
  /// Widget tests drive this store from `initState`, and a widget test runs its
  /// body in a fake-async zone where a real `File.exists`/`readAsString` never
  /// completes — the unawaited initialize would hang the test rather than fail
  /// it. A test can therefore supply either an in-memory resolver or a
  /// `directoryProvider` backed by a temp dir, and the choice is explicit.
  @visibleForTesting
  final File Function()? fileResolver;

  bool _granted = true;

  /// What the user lets FinnAI see, per kind of context. Every kind is on until
  /// switched off, and all of them are moot while [granted] is false.
  final Map<String, bool> _categories = {
    for (final key in categoryKeys) key: true,
  };

  /// Whether FinnAI may look things up online, when a question needs it.
  bool _webLookups = true;
  bool _initialized = false;
  Future<void>? _initializeJob;

  /// The kinds of device context the user can allow individually.
  static const categoryKeys = [
    'calendar',
    'contacts',
    'notifications',
    'photos',
    'files',
    'location',
  ];

  bool get granted => _granted;
  bool get initialized => _initialized;
  bool get webLookups => _webLookups;

  /// Whether [key] is allowed: the master switch and the kind both say yes.
  bool allows(String key) => _granted && (_categories[key] ?? false);
  bool categoryOn(String key) => _categories[key] ?? false;

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
        if (json['webLookups'] is bool) {
          _webLookups = json['webLookups']! as bool;
        }
        final saved = json['categories'];
        if (saved is Map) {
          for (final key in categoryKeys) {
            if (saved[key] is bool) _categories[key] = saved[key]! as bool;
          }
        }
      }
    } catch (_) {
      // An unreadable file keeps the default rather than blocking onboarding.
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<bool> setGranted(bool value) {
    _granted = value;
    return _save();
  }

  Future<bool> setCategory(String key, bool value) {
    if (!_categories.containsKey(key)) return Future.value(false);
    _categories[key] = value;
    return _save();
  }

  Future<bool> setWebLookups(bool value) {
    _webLookups = value;
    return _save();
  }

  Future<bool> _save() async {
    notifyListeners();
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(
        jsonEncode({
          'version': 2,
          'granted': _granted,
          'webLookups': _webLookups,
          'categories': _categories,
        }),
        flush: true,
      );
      await temporary.rename(file.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Removes the saved choices and returns to the defaults.
  Future<List<String>> deleteStorage() async {
    final failures = <String>[];
    _granted = true;
    _webLookups = true;
    for (final key in categoryKeys) {
      _categories[key] = true;
    }
    try {
      final file = await _file();
      final temporary = File('${file.path}.tmp');
      if (await file.exists()) await file.delete();
      if (await temporary.exists()) await temporary.delete();
    } catch (error) {
      failures.add('Access choices ($error)');
    }
    notifyListeners();
    return failures;
  }

  Future<File> _file() async {
    final override = fileResolver;
    if (override != null) return override();
    final directory = directoryProvider != null
        ? await directoryProvider!()
        : await getApplicationSupportDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}context_consent.json',
    );
  }
}
