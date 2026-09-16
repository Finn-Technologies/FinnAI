import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

@immutable
class VoiceSettings {
  const VoiceSettings({this.spokenResponses = true});

  final bool spokenResponses;

  VoiceSettings copyWith({bool? spokenResponses}) => VoiceSettings(
        spokenResponses: spokenResponses ?? this.spokenResponses,
      );

  Map<String, Object?> toJson() => {
        'version': 1,
        'spokenResponses': spokenResponses,
      };

  factory VoiceSettings.fromJson(Map<String, Object?> json) => VoiceSettings(
        spokenResponses: json['spokenResponses'] == true,
      );
}

class VoiceSettingsStore extends ChangeNotifier {
  VoiceSettingsStore({this.directoryProvider});

  static final instance = VoiceSettingsStore();

  @visibleForTesting
  final Future<Directory> Function()? directoryProvider;
  VoiceSettings _settings = const VoiceSettings();
  bool _initialized = false;
  Future<void>? _initializeJob;

  VoiceSettings get settings => _settings;
  bool get initialized => _initialized;
  bool get spokenResponses => _settings.spokenResponses;

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
        _settings = VoiceSettings.fromJson(
          (decoded as Map<Object?, Object?>).cast<String, Object?>(),
        );
      }
    } catch (_) {
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<bool> setSpokenResponses(bool value) async {
    _settings = _settings.copyWith(spokenResponses: value);
    notifyListeners();
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(
        jsonEncode(_settings.toJson()),
        flush: true,
      );
      await temporary.rename(file.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> deleteStorage() async {
    final failures = <String>[];
    _settings = const VoiceSettings();
    try {
      final file = await _file();
      final temporary = File('${file.path}.tmp');
      if (await file.exists()) await file.delete();
      if (await temporary.exists()) await temporary.delete();
    } catch (error) {
      failures.add('Voice settings ($error)');
    }
    _initialized = true;
    notifyListeners();
    return failures;
  }

  Future<File> _file() async {
    final directory = directoryProvider != null
        ? await directoryProvider!()
        : await getApplicationSupportDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}voice_settings.json',
    );
  }
}
