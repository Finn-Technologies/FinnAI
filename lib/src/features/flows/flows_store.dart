import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/features/actions/action_catalog.dart';
import 'package:finn_ai/src/features/flows/flow_model.dart';

/// The flow types are part of this library's surface: the page, the runner and
/// the tests all reach them through the store, and `FinnFlow` used to live
/// here before the model grew steps, triggers and a run log.
export 'package:finn_ai/src/features/flows/flow_model.dart';

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

/// Encodes and decodes a flow document.
///
/// Separate from the store so the format can be tested, and so a v1 file can
/// be read by exactly one function that says what it did with it.
class FlowCodec {
  const FlowCodec._();

  /// The current on-disk version.
  ///
  /// v1 was `{name, description, instructions, category, enabled}` — a prompt
  /// snippet, not an automation. There is no version 2 file format yet: a v1
  /// file becomes a single-step prompt flow, which is exactly what it was, and
  /// keeps working without the user doing anything.
  static const int currentVersion = 2;

  /// Builds a flow from a v1 document, which had no steps and no trigger.
  ///
  /// The one migration in the format's history, and it is lossless in the only
  /// direction that matters: a v1 flow's `instructions` were shown to the model
  /// when relevant, which is precisely what a one-step prompt flow does.
  static FinnFlow migrateV1(Map<String, Object?> json) => FinnFlow(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        instructions: json['instructions']?.toString() ?? '',
        category: json['category']?.toString() ?? 'Custom',
        enabled: json['enabled'] == true,
        builtIn: json['builtIn'] == true,
        steps: [
          if ((json['instructions']?.toString() ?? '').trim().isNotEmpty)
            FlowStep(
              kind: FlowStepKind.prompt,
              text: json['instructions']!.toString(),
            ),
        ],
      );

  /// Parses a whole document, migrating older versions.
  ///
  /// Returns an empty list for a document it cannot read, so a corrupt file
  /// shows the built-ins rather than an empty screen.
  static ({int version, List<FinnFlow> flows}) decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) return (version: currentVersion, flows: const []);
    final json = decoded.cast<String, Object?>();
    final version = (json['version'] as num?)?.toInt() ?? 1;
    final raw = json['flows'] as List<Object?>? ?? const [];
    return (
      version: version,
      flows: [
        for (final item in raw)
          if (item is Map)
            version >= 2
                ? FinnFlow.fromJson(item.cast<String, Object?>())
                : migrateV1(item.cast<String, Object?>()),
      ],
    );
  }

  static String encode(int version, List<FinnFlow> flows) => jsonEncode({
        'version': version,
        'flows': [for (final flow in flows) flow.toJson()],
      });
}

class FlowsStore extends ChangeNotifier {
  FlowsStore({this.directoryProvider});

  static final instance = FlowsStore();

  @visibleForTesting
  final Future<Directory> Function()? directoryProvider;
  List<FinnFlow> _skills = List.of(finnBuiltInFlows);

  /// Recent runs, newest first, bounded by [maxRunHistory].
  ///
  /// A run log is what makes an automation accountable: without it, a flow that
  /// fires on its own is something that happened to the user. It records what
  /// each step *did* — never what the model said, because this is written to
  /// disk and read back on device.
  List<FlowRun> _runs = const [];

  /// How many runs are kept. Enough to cover "what happened this morning",
  /// small enough that the log is not itself a growth problem on a device whose
  /// RAM is the scarce resource.
  static const int maxRunHistory = 30;

  bool _initialized = false;
  Future<void>? _initializeJob;
  bool _saving = false;
  Future<void> _writeQueue = Future<void>.value();
  int _pendingWrites = 0;
  FlowsFailure? _failure;

  List<FinnFlow> get flows => List.unmodifiable(_skills);
  List<FinnFlow> get enabledSkills =>
      List.unmodifiable(_skills.where((flow) => flow.enabled));
  List<FlowRun> get runs => List.unmodifiable(_runs);
  bool get initialized => _initialized;
  bool get saving => _saving;
  FlowsFailure? get failure => _failure;

  /// The most recent runs of one flow, newest first.
  List<FlowRun> runsOf(String flowId) =>
      List.unmodifiable(_runs.where((run) => run.flowId == flowId));

  /// Records a completed run and persists the log.
  ///
  /// Returns false only when the log could not be written; the run itself still
  /// happened, and losing one log line is not a reason to lose the run.
  Future<bool> recordRun(FlowRun run) async {
    if (run.id.isEmpty) return false;
    _runs = [run, ..._runs].take(maxRunHistory).toList(growable: false);
    notifyListeners();
    return _persist();
  }

  Future<List<FlowRun>> _readRuns(File file) async {
    // The run log lives beside the flows rather than inside the document, so
    // appending a run does not rewrite (and risk) the user's flow definitions.
    final log = File('${file.path}.runs');
    if (!await log.exists()) return const [];
    try {
      final decoded = jsonDecode(await log.readAsString());
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map) FlowRun.fromJson(item.cast<String, Object?>()),
      ].take(maxRunHistory).toList(growable: false);
    } catch (error) {
      // A corrupt log must not cost the user their flows.
      debugPrint('FINN_FLOWS run log unreadable: $error');
      return const [];
    }
  }

  Future<void> _writeRuns(File file) async {
    final log = File('${file.path}.runs');
    await log.parent.create(recursive: true);
    final temporary = File('${log.path}.tmp');
    await temporary.writeAsString(
      jsonEncode([for (final run in _runs) run.toJson()]),
      flush: true,
    );
    await temporary.rename(log.path);
  }

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
        // The version was written but never read, so a v1 file — a prompt
        // snippet with no steps — used to load as an automation with nothing in
        // it. [FlowCodec.decode] migrates it: a v1 flow's instructions become
        // the one prompt step they always effectively were.
        final decoded = FlowCodec.decode(await file.readAsString());
        final stored =
            decoded.flows.where((flow) => flow.id.isNotEmpty).toList();
        final storedById = {for (final flow in stored) flow.id: flow};
        _skills = [
          for (final builtIn in finnBuiltInFlows)
            // Only the enabled flag is restored for a built-in: its steps and
            // trigger ship with the app, not with the user's file.
            builtIn.copyWith(
              enabled: storedById[builtIn.id]?.enabled ?? builtIn.enabled,
            ),
          ...stored.where((flow) => !flow.builtIn),
        ];
        _runs = await _readRuns(file);
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
    List<FlowStep> steps = const [],
    FlowTrigger? trigger,
    bool? granted,
  }) async {
    final cleanName = name.trim();
    final cleanInstructions = instructions.trim();
    // A flow needs something to do: either steps, or the v1 instruction text
    // that the prompt path still uses.
    if (cleanName.isEmpty ||
        (cleanInstructions.isEmpty &&
            steps.every((s) => s.text.trim().isEmpty))) {
      return false;
    }

    final existingIndex = id == null
        ? -1
        : _skills.indexWhere((flow) => flow.id == id && !flow.builtIn);
    final previous = existingIndex >= 0 ? _skills[existingIndex] : null;
    final wasEnabled = previous != null && previous.enabled;
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
      steps: steps,
      trigger: trigger ?? previous?.trigger ?? const FlowTrigger.manual(),
      // A grant survives an edit only if the caller did not say otherwise: an
      // edit that adds a device action to a previously prompt-only flow must
      // not inherit permission it never had.
      granted: granted ?? previous?.granted ?? false,
    );
    if (existingIndex >= 0) {
      _skills[existingIndex] = flow;
    } else {
      _skills.add(flow);
    }
    notifyListeners();
    return _persist();
  }

  /// Records the user's standing permission for a flow to act on its own.
  ///
  /// Separate from [upsertCustom] on purpose: this is the one call in the
  /// feature that can let something happen when the user is not looking, so it
  /// gets its own name and its own reason to exist.
  Future<bool> setGranted(String id, bool granted) async {
    final index = _skills.indexWhere((flow) => flow.id == id);
    if (index < 0) return false;
    final flow = _skills[index];
    // Withdrawing a grant is always allowed. Granting one is only meaningful
    // for a flow that can actually do something, and a flow with no device
    // action needs no permission, so it is not granted one.
    if (granted && !flow.hasDeviceAction) return false;
    _skills[index] = flow.copyWith(granted: granted);
    notifyListeners();
    return _persist();
  }

  /// Checks a flow's shape without running anything.
  ///
  /// A pure function so the rule "a flow may not name an action outside the
  /// catalog" is testable, and so a bad flow is caught at save time rather than
  /// halfway through a run that has already set an alarm.
  static FlowValidation validate(FinnFlow flow) {
    final problems = <FlowValidationProblem>[];
    if (flow.steps.isEmpty) problems.add(FlowValidationProblem.empty);
    var hasDeviceAction = false;
    for (final step in flow.steps) {
      if (step.kind != FlowStepKind.deviceAction) continue;
      hasDeviceAction = true;
      final name = step.actionName;
      final action = name == null ? null : DeviceActionCatalog.byName(name);
      if (action == null) {
        problems.add(FlowValidationProblem.unknownAction);
        continue;
      }
      for (final param in action.params) {
        if (param.required && !step.arguments.containsKey(param.name)) {
          problems.add(FlowValidationProblem.missingArgument);
        }
      }
    }
    if (flow.trigger.isScheduled) {
      if (flow.trigger.hour < 0 ||
          flow.trigger.hour > 23 ||
          flow.trigger.minute < 0 ||
          flow.trigger.minute > 59) {
        problems.add(FlowValidationProblem.invalidSchedule);
      }
    }
    return FlowValidation(problems, hasDeviceAction: hasDeviceAction);
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
    final lines = <String>['Active user-selected flows:'];
    for (final flow in selected) {
      // A flow with steps contributes its prompts; a v1 flow contributes the
      // instruction text that was always its whole behaviour. A flow that has
      // only device-action steps contributes nothing here: it is an automation
      // the runner executes, not a preference the model should imitate.
      for (final line in flow.promptLines) {
        final clean = line.trim();
        if (clean.isEmpty) continue;
        lines.add(
          '- ${flow.name}: '
          '${clean.substring(0, math.min(500, clean.length))}',
        );
      }
    }
    if (lines.length == 1) return '';
    lines.add(
      'Apply a flow only when it is relevant to the current request. Safety and explicit user requests take priority.',
    );
    return lines.join('\n');
  }

  Future<bool> _persist() async {
    final payload = FlowCodec.encode(FlowCodec.currentVersion, _skills);
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
        await _writeRuns(file);
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
