import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/features/actions/action_catalog.dart';
import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/features/flows/flows_codec.dart';

/// The flow types are part of this library's surface: the page, the runner and
/// the tests all reach them through the store, and `FinnFlow` used to live
/// here before the model grew steps, triggers and a run log.
export 'package:finn_ai/src/features/flows/flow_model.dart';
export 'package:finn_ai/src/features/flows/flows_codec.dart';

/// Why a flow operation failed, resolved to a sentence by the page.
///
/// The store holds a code rather than a message: a hardcoded English sentence
/// here would override the page's `L10n` lookup and leak English into the other
/// locales.
enum FlowsFailure {
  /// The persisted flows could not be read; an empty list is shown instead.
  load,

  /// A change could not be written.
  save,
}

class FlowsStore extends ChangeNotifier {
  FlowsStore({this.directoryProvider});

  static final instance = FlowsStore();

  @visibleForTesting
  final Future<Directory> Function()? directoryProvider;
  List<FinnFlow> _flows = <FinnFlow>[];

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

  List<FinnFlow> get flows => List.unmodifiable(_flows);

  /// Enabled flows that run steps, by hand or on a schedule.
  List<FinnFlow> get enabledAutomations => List.unmodifiable(
        _flows.where((flow) => flow.enabled && flow.isAutomation),
      );
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
    return _persistRuns();
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
        // Guides were removed in v4: [FlowCodec.decode] already drops flows
        // with no blocks, so whatever is left here is an automation.
        final decoded = FlowCodec.decode(await file.readAsString());
        _flows = decoded.flows.where((flow) => flow.id.isNotEmpty).toList();
      }
      // The run log is its own file, so it is read even when no flow was ever
      // saved (a flow can run and be logged without a flows file).
      _runs = await _readRuns(await _file());
      _failure = null;
    } catch (error) {
      debugPrint('FINN_FLOWS read failed: $error');
      _failure = FlowsFailure.load;
      _flows = <FinnFlow>[];
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<bool> setEnabled(String id, bool enabled) async {
    final index = _flows.indexWhere((flow) => flow.id == id);
    if (index < 0) return false;
    _flows[index] = _flows[index].copyWith(enabled: enabled);
    notifyListeners();
    return _persist();
  }

  Future<bool> upsertCustom({
    String? id,
    required String name,
    required String description,
    String category = 'Custom',
    bool enabled = true,
    List<FlowBlock> blocks = const [],
    List<FlowTrigger>? triggers,
    List<FlowCondition>? conditions,
    bool? granted,
  }) async {
    final cleanName = name.trim();
    // A flow is its blocks. Anything without steps is a leftover guide and is
    // refused: the codec already drops those on load.
    if (cleanName.isEmpty || blocks.isEmpty) {
      return false;
    }

    final existingIndex =
        id == null ? -1 : _flows.indexWhere((flow) => flow.id == id);
    final previous = existingIndex >= 0 ? _flows[existingIndex] : null;
    final flow = FinnFlow(
      id: existingIndex >= 0
          ? _flows[existingIndex].id
          : 'custom-${DateTime.now().microsecondsSinceEpoch}',
      name: cleanName,
      description: description.trim(),
      instructions: '',
      category: category.trim().isEmpty ? 'Custom' : category.trim(),
      enabled: enabled,
      blocks: blocks,
      triggers: triggers ?? previous?.triggers ?? const [],
      conditions: conditions ?? previous?.conditions ?? const [],
      // A grant survives an edit only if the caller did not say otherwise: an
      // edit that adds a device action to a previously inert flow must not
      // inherit permission it never had.
      granted: granted ?? _keepGrant(previous, blocks),
    );
    if (existingIndex >= 0) {
      _flows[existingIndex] = flow;
    } else {
      _flows.add(flow);
    }
    notifyListeners();
    return _persist();
  }

  /// The standing grant an edit keeps. An edit that *adds* a device action to a
  /// flow that had none starts without permission; one that only changes what
  /// was already permitted keeps it.
  static bool _keepGrant(FinnFlow? previous, List<FlowBlock> blocks) {
    if (previous == null || !previous.granted) return false;
    return previous.hasDeviceAction &&
        blocks
            .any((b) => b.flatten().any((x) => x.kind == FlowBlockKind.action));
  }

  /// Records the user's standing permission for a flow to act on its own.
  ///
  /// Separate from [upsertCustom] on purpose: this is the one call in the
  /// feature that can let something happen when the user is not looking, so it
  /// gets its own name and its own reason to exist.
  Future<bool> setGranted(String id, bool granted) async {
    final index = _flows.indexWhere((flow) => flow.id == id);
    if (index < 0) return false;
    final flow = _flows[index];
    // Withdrawing a grant is always allowed. Granting one is only meaningful
    // for a flow that can actually do something, and a flow with no device
    // action needs no permission, so it is not granted one.
    if (granted && !flow.hasDeviceAction) return false;
    _flows[index] = flow.copyWith(granted: granted);
    notifyListeners();
    return _persist();
  }

  /// Checks a flow's shape without running anything.
  ///
  /// A pure function so the rule "a flow may not name an action outside the
  /// catalog" is testable, and so a bad flow is caught at save time rather than
  /// halfway through a run that has already set an alarm.
  static FlowValidation validate(FinnFlow flow) {
    final problems = <FlowValidationProblem>{};
    if (flow.blocks.isEmpty) problems.add(FlowValidationProblem.empty);
    final total = flow.blocks.fold<int>(0, (sum, b) => sum + b.size);
    if (total > FlowBlock.maxPerFlow ||
        flow.blocks.any((b) => b.depth > FlowBlock.maxDepth)) {
      problems.add(FlowValidationProblem.tooLarge);
    }
    var hasDeviceAction = false;
    for (final block in flow.allBlocks) {
      if (block.kind == FlowBlockKind.branch &&
          !(block.condition?.isValid ?? false)) {
        problems.add(FlowValidationProblem.invalidCondition);
      }
      if (block.kind != FlowBlockKind.action) continue;
      hasDeviceAction = true;
      final name = block.actionName;
      final action = name == null ? null : DeviceActionCatalog.byName(name);
      if (action == null) {
        problems.add(FlowValidationProblem.unknownAction);
        continue;
      }
      for (final param in action.params) {
        if (param.required && !block.arguments.containsKey(param.name)) {
          problems.add(FlowValidationProblem.missingArgument);
        }
      }
    }
    if (flow.triggers.any((t) => !t.isValid)) {
      problems.add(FlowValidationProblem.invalidTrigger);
    }
    if (flow.conditions.any((c) => !c.isValid)) {
      problems.add(FlowValidationProblem.invalidCondition);
    }
    return FlowValidation(problems.toList(), hasDeviceAction: hasDeviceAction);
  }

  Future<bool> removeCustom(String id) async {
    final before = _flows.length;
    _flows.removeWhere((flow) => flow.id == id);
    if (_flows.length == before) return false;
    notifyListeners();
    return _persist();
  }

  /// Clears flows and removes app-private state.
  Future<List<String>> deleteStorage() async {
    await _writeQueue;
    final failures = <String>[];
    _flows = <FinnFlow>[];
    _failure = null;
    try {
      final file = await _file();
      final temporary = File('${file.path}.tmp');
      final log = File('${file.path}.runs');
      if (await file.exists()) await file.delete();
      if (await temporary.exists()) await temporary.delete();
      if (await log.exists()) await log.delete();
      _runs = const [];
    } catch (error) {
      failures.add('Flows ($error)');
    }
    _initialized = true;
    notifyListeners();
    return failures;
  }

  /// Writes only the run log. A run can finish in a second Flutter engine (a
  /// flow started in the background), and that engine must never rewrite the
  /// flow definitions from a copy it read earlier.
  Future<bool> _persistRuns() async {
    final result = Completer<bool>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _writeRuns(await _file());
        result.complete(true);
      } catch (error) {
        debugPrint('FINN_FLOWS run log save failed: $error');
        result.complete(false);
      }
    });
    return result.future;
  }

  /// Re-reads the run log, picking up runs another engine wrote while the app
  /// was closed.
  Future<void> reloadRuns() async {
    try {
      _runs = await _readRuns(await _file());
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> _persist() async {
    final payload = FlowCodec.encode(FlowCodec.currentVersion, _flows);
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
        debugPrint('FINN_FLOWS save failed: $error');
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
