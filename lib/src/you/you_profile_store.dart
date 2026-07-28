import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum FinnResponseStyle {
  balanced('Balanced', 'Use a natural balance of clarity and detail.'),
  concise(
    'Concise',
    'Prefer short, direct answers without unnecessary detail.',
  ),
  detailed('Detailed', 'Give thorough explanations with useful context.'),
  conversational(
    'Conversational',
    'Use a warm, natural, conversational tone while staying useful.',
  );

  const FinnResponseStyle(this.label, this.promptInstruction);

  final String label;
  final String promptInstruction;
}

@immutable
class FinnUserProfile {
  const FinnUserProfile({
    this.preferredName = '',
    this.about = '',
    this.customInstructions = '',
    this.responseStyle = FinnResponseStyle.balanced,
  });

  final String preferredName;
  final String about;
  final String customInstructions;
  final FinnResponseStyle responseStyle;

  bool get hasPersonalization =>
      preferredName.trim().isNotEmpty ||
      about.trim().isNotEmpty ||
      customInstructions.trim().isNotEmpty ||
      responseStyle != FinnResponseStyle.balanced;

  FinnUserProfile copyWith({
    String? preferredName,
    String? about,
    String? customInstructions,
    FinnResponseStyle? responseStyle,
  }) => FinnUserProfile(
    preferredName: preferredName ?? this.preferredName,
    about: about ?? this.about,
    customInstructions: customInstructions ?? this.customInstructions,
    responseStyle: responseStyle ?? this.responseStyle,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'preferredName': preferredName,
    'about': about,
    'customInstructions': customInstructions,
    'responseStyle': responseStyle.name,
  };

  factory FinnUserProfile.fromJson(Map<String, Object?> json) {
    final rawStyle = json['responseStyle']?.toString();
    final style = FinnResponseStyle.values
        .where((value) => value.name == rawStyle)
        .firstOrNull;
    return FinnUserProfile(
      preferredName: json['preferredName']?.toString() ?? '',
      about: json['about']?.toString() ?? '',
      customInstructions: json['customInstructions']?.toString() ?? '',
      responseStyle: style ?? FinnResponseStyle.balanced,
    );
  }
}

/// Local, dependency-injectable personalization storage.
class YouProfileStore extends ChangeNotifier {
  YouProfileStore({this.directoryProvider});

  static final instance = YouProfileStore();

  @visibleForTesting
  final Future<Directory> Function()? directoryProvider;
  FinnUserProfile _profile = const FinnUserProfile();
  bool _initialized = false;
  Future<void>? _initializeJob;
  bool _saving = false;
  String? _storageError;

  FinnUserProfile get profile => _profile;
  bool get initialized => _initialized;
  bool get saving => _saving;
  String? get storageError => _storageError;

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
        _profile = FinnUserProfile.fromJson(
          (decoded as Map<Object?, Object?>).cast<String, Object?>(),
        );
      }
      _storageError = null;
    } catch (error) {
      _storageError = 'Could not read personalization: $error';
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<bool> save(FinnUserProfile profile) async {
    _profile = FinnUserProfile(
      preferredName: profile.preferredName.trim(),
      about: profile.about.trim(),
      customInstructions: profile.customInstructions.trim(),
      responseStyle: profile.responseStyle,
    );
    _saving = true;
    _storageError = null;
    notifyListeners();
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(jsonEncode(_profile.toJson()), flush: true);
      await temporary.rename(file.path);
      return true;
    } catch (error) {
      _storageError = 'Could not save personalization: $error';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> clear() => save(const FinnUserProfile());

  /// Clears the in-memory profile and removes its app-private JSON file.
  ///
  /// The returned list is empty on success and contains human-readable
  /// failures when deletion could not be completed, matching the app-wide
  /// deletion workflow.
  Future<List<String>> deleteStorage() async {
    final failures = <String>[];
    _profile = const FinnUserProfile();
    _storageError = null;
    try {
      final file = await _file();
      final temporary = File('${file.path}.tmp');
      if (await file.exists()) await file.delete();
      if (await temporary.exists()) await temporary.delete();
    } catch (error) {
      failures.add('Personalization ($error)');
    }
    _initialized = true;
    notifyListeners();
    return failures;
  }

  /// A compact system-prompt fragment. Empty means no user customization.
  String get promptContext {
    if (!_profile.hasPersonalization) return '';
    final lines = <String>[
      'User personalization (private and stored locally):',
      if (_profile.preferredName.isNotEmpty)
        '- Address the user as ${_profile.preferredName}.',
      if (_profile.about.isNotEmpty) '- About the user: ${_profile.about}',
      '- Response preference: ${_profile.responseStyle.promptInstruction}',
      if (_profile.customInstructions.isNotEmpty)
        '- Additional user instruction: ${_profile.customInstructions}',
      'Follow these preferences unless they conflict with safety or the current request.',
    ];
    return lines.join('\n');
  }

  Future<File> _file() async {
    // Application Support maps to app-private internal storage on Android.
    final directory = directoryProvider != null
        ? await directoryProvider!()
        : await getApplicationSupportDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}user_personalization.json',
    );
  }
}
