import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/features/voice/tts/tts_voice_catalog.dart';

/// How fast replies are read aloud.
enum VoiceSpeed {
  slow(.32),
  normal(.45),
  fast(.6);

  const VoiceSpeed(this.rate);

  /// The text-to-speech rate this speed maps to.
  final double rate;
}

@immutable
class VoiceSettings {
  const VoiceSettings({
    this.spokenResponses = true,
    this.speed = VoiceSpeed.normal,
    this.liveTranscript = true,
    this.ttsStyle = defaultTtsStyle,
  });

  final bool spokenResponses;
  final VoiceSpeed speed;

  /// Whether the words are shown on screen while the user speaks.
  final bool liveTranscript;

  /// The Supertonic speaking style ([ttsStyles]); anything else falls back.
  final String ttsStyle;

  VoiceSettings copyWith({
    bool? spokenResponses,
    VoiceSpeed? speed,
    bool? liveTranscript,
    String? ttsStyle,
  }) =>
      VoiceSettings(
        spokenResponses: spokenResponses ?? this.spokenResponses,
        speed: speed ?? this.speed,
        liveTranscript: liveTranscript ?? this.liveTranscript,
        ttsStyle: ttsStyle ?? this.ttsStyle,
      );

  Map<String, Object?> toJson() => {
        'version': 3,
        'spokenResponses': spokenResponses,
        'speed': speed.name,
        'liveTranscript': liveTranscript,
        'ttsStyle': ttsStyle,
      };

  factory VoiceSettings.fromJson(Map<String, Object?> json) {
    final stored = json['ttsStyle'];
    return VoiceSettings(
      spokenResponses: json['spokenResponses'] == true,
      speed: VoiceSpeed.values.firstWhere(
        (value) => value.name == json['speed'],
        orElse: () => VoiceSpeed.normal,
      ),
      liveTranscript: json['liveTranscript'] != false,
      ttsStyle: stored is String && ttsStyles.contains(stored)
          ? stored
          : defaultTtsStyle,
    );
  }
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
  VoiceSpeed get speed => _settings.speed;
  bool get liveTranscript => _settings.liveTranscript;
  String get ttsStyle => _settings.ttsStyle;

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

  Future<bool> setSpokenResponses(bool value) =>
      _update(_settings.copyWith(spokenResponses: value));

  Future<bool> setSpeed(VoiceSpeed value) =>
      _update(_settings.copyWith(speed: value));

  Future<bool> setLiveTranscript(bool value) =>
      _update(_settings.copyWith(liveTranscript: value));

  Future<bool> setTtsStyle(String value) => _update(
        _settings.copyWith(
          ttsStyle: ttsStyles.contains(value) ? value : defaultTtsStyle,
        ),
      );

  Future<bool> _update(VoiceSettings next) async {
    _settings = next;
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
