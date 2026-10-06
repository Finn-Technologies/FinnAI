import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// How much the agent may do before it asks.
enum CodePermissionMode {
  /// Every command and every file write waits for a tap.
  askEveryTime,

  /// Files are written as the agent goes; commands still wait for a tap. The
  /// default: a written file is inside the project folder and easy to undo,
  /// a command is not.
  acceptEdits,

  /// Everything runs. Commands are still confined to the project folder and
  /// checked by the policy, but nothing waits for the user.
  autoRun,
}

@immutable
class CodeSettings {
  const CodeSettings({
    this.permissionMode = CodePermissionMode.acceptEdits,
    this.maxSteps,
    this.allowNetwork = false,
    this.commandTimeoutSeconds = 20,
    this.useContainer = true,
  });

  final CodePermissionMode permissionMode;

  /// Actions per request. Null follows the model: short for the on-device
  /// one, longer for a cloud one.
  final int? maxSteps;

  /// Lets commands use the network (`curl`, `wget`). Off by default.
  final bool allowNetwork;
  final int commandTimeoutSeconds;

  /// Runs commands in the Linux container once it is installed. Off sends
  /// them to the device's own shell, as before the container existed.
  final bool useContainer;

  static const List<int> stepChoices = [4, 8, 12, 20, 30];
  static const List<int> timeoutChoices = [10, 20, 60, 120];

  CodeSettings copyWith({
    CodePermissionMode? permissionMode,
    int? Function()? maxSteps,
    bool? allowNetwork,
    int? commandTimeoutSeconds,
    bool? useContainer,
  }) =>
      CodeSettings(
        permissionMode: permissionMode ?? this.permissionMode,
        maxSteps: maxSteps != null ? maxSteps() : this.maxSteps,
        allowNetwork: allowNetwork ?? this.allowNetwork,
        commandTimeoutSeconds:
            commandTimeoutSeconds ?? this.commandTimeoutSeconds,
        useContainer: useContainer ?? this.useContainer,
      );

  Map<String, Object?> toJson() => {
        'permission': permissionMode.name,
        if (maxSteps != null) 'maxSteps': maxSteps,
        'network': allowNetwork,
        'timeout': commandTimeoutSeconds,
        'container': useContainer,
      };

  factory CodeSettings.fromJson(Map<String, Object?> json) => CodeSettings(
        permissionMode: CodePermissionMode.values
                .where((value) => value.name == json['permission'])
                .firstOrNull ??
            CodePermissionMode.acceptEdits,
        maxSteps: json['maxSteps'] is int
            ? (json['maxSteps'] as int).clamp(1, 50)
            : null,
        allowNetwork: json['network'] == true,
        commandTimeoutSeconds: json['timeout'] is int
            ? (json['timeout'] as int).clamp(5, 300)
            : 20,
        useContainer: json['container'] != false,
      );
}

class CodeSettingsStore extends ChangeNotifier {
  CodeSettingsStore({this.directoryProvider});

  static final instance = CodeSettingsStore();

  @visibleForTesting
  final Future<Directory> Function()? directoryProvider;

  CodeSettings _settings = const CodeSettings();
  bool _initialized = false;

  CodeSettings get settings => _settings;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final file = await _file();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          _settings = CodeSettings.fromJson(decoded.cast<String, Object?>());
        }
      }
    } catch (_) {
      // Unreadable settings fall back to the safe defaults.
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> update(CodeSettings Function(CodeSettings) change) async {
    final next = change(_settings);
    _settings = next;
    notifyListeners();
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(next.toJson()), flush: true);
    } catch (_) {
      // The choice still applies for this run.
    }
  }

  Future<File> _file() async {
    final directory = directoryProvider != null
        ? await directoryProvider!()
        : await getApplicationSupportDirectory();
    return File('${directory.path}/code/settings.json');
  }

  Future<List<String>> deleteStorage() async {
    _settings = const CodeSettings();
    notifyListeners();
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (error) {
      return ['FinnAI Code settings ($error)'];
    }
    return const [];
  }
}
