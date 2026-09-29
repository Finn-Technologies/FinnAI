import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Why a flow operation failed, resolved to a sentence by the page.
///
/// The store holds a code rather than a message: a hardcoded English sentence
/// here would override the page's `L10n` lookup and leak English into the other
/// locales.
enum FlowsFailure {
  /// The persisted flows could not be read; built-ins are shown instead.
  load,

  /// A change could not be written.
  save,

  /// The four-active-flows cap was reached.
  limit,
}

@immutable
class FinnFlow {
  const FinnFlow({
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
    required this.category,
    this.enabled = false,
    this.builtIn = false,
  });

  final String id;
  final String name;
  final String description;
  final String instructions;
  final String category;
  final bool enabled;
  final bool builtIn;

  FinnFlow copyWith({
    String? name,
    String? description,
    String? instructions,
    String? category,
    bool? enabled,
  }) =>
      FinnFlow(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        instructions: instructions ?? this.instructions,
        category: category ?? this.category,
        enabled: enabled ?? this.enabled,
        builtIn: builtIn,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'instructions': instructions,
        'category': category,
        'enabled': enabled,
        'builtIn': builtIn,
      };

  factory FinnFlow.fromJson(Map<String, Object?> json) => FinnFlow(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        instructions: json['instructions']?.toString() ?? '',
        category: json['category']?.toString() ?? 'Custom',
        enabled: json['enabled'] == true,
        builtIn: json['builtIn'] == true,
      );
}

const List<FinnFlow> finnBuiltInFlows = [
  FinnFlow(
    id: 'builtin-writing',
    name: 'Clear writing',
    description: 'Polish structure, clarity, tone, and grammar.',
    instructions:
        'For writing tasks, improve clarity and flow, preserve the intended meaning, and briefly note important edits.',
    category: 'Writing',
    builtIn: true,
  ),
  FinnFlow(
    id: 'builtin-coding',
    name: 'Coding partner',
    description: 'Practical code with clear trade-offs and checks.',
    instructions:
        'For software tasks, prioritize correct, maintainable solutions. State assumptions, cover edge cases, and include verification steps when useful.',
    category: 'Development',
    builtIn: true,
  ),
  FinnFlow(
    id: 'builtin-learning',
    name: 'Study coach',
    description: 'Explain concepts progressively and test understanding.',
    instructions:
        'For learning tasks, build from first principles, use a compact example, and end with one useful check for understanding when appropriate.',
    category: 'Learning',
    builtIn: true,
  ),
  FinnFlow(
    id: 'builtin-planning',
    name: 'Thoughtful planner',
    description: 'Turn goals into realistic, ordered next steps.',
    instructions:
        'For planning tasks, identify constraints, prioritize the highest-impact steps, and make the plan concrete and realistic.',
    category: 'Planning',
    builtIn: true,
  ),
];

class FlowsStore extends ChangeNotifier {
  FlowsStore({this.directoryProvider});

  static final instance = FlowsStore();

  @visibleForTesting
  final Future<Directory> Function()? directoryProvider;
  List<FinnFlow> _skills = List.of(finnBuiltInFlows);
  bool _initialized = false;
  Future<void>? _initializeJob;
  bool _saving = false;
  Future<void> _writeQueue = Future<void>.value();
  int _pendingWrites = 0;
  FlowsFailure? _failure;

  List<FinnFlow> get flows => List.unmodifiable(_skills);
  List<FinnFlow> get enabledSkills =>
      List.unmodifiable(_skills.where((flow) => flow.enabled));
  bool get initialized => _initialized;
  bool get saving => _saving;
  FlowsFailure? get failure => _failure;

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
        final decoded =
            (jsonDecode(await file.readAsString()) as Map<Object?, Object?>)
                .cast<String, Object?>();
        final stored = (decoded['flows'] as List<Object?>? ?? const [])
            .map(
              (item) => FinnFlow.fromJson(
                (item as Map<Object?, Object?>).cast<String, Object?>(),
              ),
            )
            .where((flow) => flow.id.isNotEmpty)
            .toList();
        final storedById = {for (final flow in stored) flow.id: flow};
        _skills = [
          for (final builtIn in finnBuiltInFlows)
            builtIn.copyWith(
              enabled: storedById[builtIn.id]?.enabled ?? builtIn.enabled,
            ),
          ...stored.where((flow) => !flow.builtIn),
        ];
      }
      _failure = null;
    } catch (error) {
      debugPrint('FINN_SKILLS read failed: $error');
      _failure = FlowsFailure.load;
      _skills = List.of(finnBuiltInFlows);
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<bool> setEnabled(String id, bool enabled) async {
    final index = _skills.indexWhere((flow) => flow.id == id);
    if (index < 0) return false;
    if (enabled && !_skills[index].enabled && enabledSkills.length >= 4) {
      _failure = FlowsFailure.limit;
      notifyListeners();
      return false;
    }
    _skills[index] = _skills[index].copyWith(enabled: enabled);
    notifyListeners();
    return _persist();
  }

  Future<bool> upsertCustom({
    String? id,
    required String name,
    required String description,
    required String instructions,
    String category = 'Custom',
    bool enabled = true,
  }) async {
    final cleanName = name.trim();
    final cleanInstructions = instructions.trim();
    if (cleanName.isEmpty || cleanInstructions.isEmpty) return false;

    final existingIndex = id == null
        ? -1
        : _skills.indexWhere((flow) => flow.id == id && !flow.builtIn);
    final wasEnabled = existingIndex >= 0 && _skills[existingIndex].enabled;
    if (enabled && !wasEnabled && enabledSkills.length >= 4) {
      _failure = FlowsFailure.limit;
      notifyListeners();
      return false;
    }
    final flow = FinnFlow(
      id: existingIndex >= 0
          ? _skills[existingIndex].id
          : 'custom-${DateTime.now().microsecondsSinceEpoch}',
      name: cleanName,
      description: description.trim(),
      instructions: cleanInstructions.substring(
        0,
        math.min(500, cleanInstructions.length),
      ),
      category: category.trim().isEmpty ? 'Custom' : category.trim(),
      enabled: enabled,
    );
    if (existingIndex >= 0) {
      _skills[existingIndex] = flow;
    } else {
      _skills.add(flow);
    }
    notifyListeners();
    return _persist();
  }

  Future<bool> removeCustom(String id) async {
    final before = _skills.length;
    _skills.removeWhere((flow) => flow.id == id && !flow.builtIn);
    if (_skills.length == before) return false;
    notifyListeners();
    return _persist();
  }

  /// Restores built-ins to disabled defaults and removes app-private state.
  Future<List<String>> deleteStorage() async {
    await _writeQueue;
    final failures = <String>[];
    _skills = List.of(finnBuiltInFlows);
    _failure = null;
    try {
      final file = await _file();
      final temporary = File('${file.path}.tmp');
      if (await file.exists()) await file.delete();
      if (await temporary.exists()) await temporary.delete();
    } catch (error) {
      failures.add('Flows ($error)');
    }
    _initialized = true;
    notifyListeners();
    return failures;
  }

  /// Prompt fragment consumed by the inference layer.
  String get activePromptContext {
    return _promptContext(enabledSkills.take(4));
  }

  String promptContextFor(String prompt) {
    final value = prompt.toLowerCase();
    final relevant = enabledSkills.where((flow) {
      final signals = switch (flow.id) {
        'builtin-writing' => const [
            'write',
            'rewrite',
            'edit',
            'message',
            'scrivi',
            'écris',
          ],
        'builtin-coding' => const [
            'code',
            'program',
            'software',
            'debug',
            'flutter',
            'python',
            'swift',
          ],
        'builtin-learning' => const [
            'learn',
            'explain',
            'teach',
            'study',
            'impar',
            'spiega',
          ],
        'builtin-planning' => const [
            'plan',
            'schedule',
            'roadmap',
            'organize',
            'piano',
            'programma',
          ],
        _ => [
            ...flow.name.toLowerCase().split(RegExp(r'\W+')),
            ...flow.category.toLowerCase().split(RegExp(r'\W+')),
            ...flow.description.toLowerCase().split(RegExp(r'\W+')),
          ].where((word) => word.length >= 4),
      };
      return signals.any(value.contains);
    }).take(4);
    return _promptContext(relevant);
  }

  String _promptContext(Iterable<FinnFlow> active) {
    final selected = active.toList(growable: false);
    if (selected.isEmpty) return '';
    final lines = <String>[
      'Active user-selected flows:',
      for (final flow in selected)
        '- ${flow.name}: ${flow.instructions.trim().substring(0, math.min(500, flow.instructions.trim().length))}',
      'Apply a flow only when it is relevant to the current request. Safety and explicit user requests take priority.',
    ];
    return lines.join('\n');
  }

  Future<bool> _persist() async {
    final data = {
      'version': 1,
      'flows': _skills.map((flow) => flow.toJson()).toList(),
    };
    final payload = jsonEncode(data);
    final result = Completer<bool>();
    _pendingWrites++;
    _saving = true;
    _failure = null;
    notifyListeners();
    _writeQueue = _writeQueue.then((_) async {
      try {
        final file = await _file();
        await file.parent.create(recursive: true);
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(payload, flush: true);
        await temporary.rename(file.path);
        result.complete(true);
      } catch (error) {
        debugPrint('FINN_SKILLS save failed: $error');
        _failure = FlowsFailure.save;
        result.complete(false);
      } finally {
        _pendingWrites--;
        _saving = _pendingWrites > 0;
        notifyListeners();
      }
    });
    return result.future;
  }

  Future<File> _file() async {
    // Application Support maps to app-private internal storage on Android.
    final directory = directoryProvider != null
        ? await directoryProvider!()
        : await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}flows.json');
  }
}
