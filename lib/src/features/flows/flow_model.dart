import 'package:flutter/foundation.dart';

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
    this.steps = const [],
    this.trigger = const FlowTrigger.manual(),
    this.granted = false,
  });

  final String id;
  final String name;
  final String description;
  final String instructions;
  final String category;
  final bool enabled;
  final bool builtIn;

  /// What the flow does, in order. Empty for a v1 flow that has not been
  /// migrated yet, in which case [instructions] is what still drives it.
  final List<FlowStep> steps;

  final FlowTrigger trigger;

  /// The user's standing permission for this flow to act on the device by
  /// itself.
  ///
  /// Only ever set by an explicit user action, only consulted for a
  /// *scheduled* run, and only meaningful when the flow has a device-action
  /// step. A manual run asks every time regardless — the grant is what lets
  /// something happen when the user is not looking, so it is the only thing
  /// that must not be implicit.
  final bool granted;

  /// Whether this flow can act on the device at all.
  bool get hasDeviceAction =>
      steps.any((step) => step.kind == FlowStepKind.deviceAction);

  /// Whether a scheduled run would be allowed to execute right now.
  bool get scheduledRunIsPermitted => !hasDeviceAction || granted;

  /// What the model is told about this flow.
  ///
  /// A flow with steps contributes its steps' prompts; a v1 flow contributes
  /// its instructions, which is what it always did.
  List<String> get promptLines => [
        for (final step in steps)
          if (step.kind == FlowStepKind.prompt) step.text,
        if (steps.isEmpty && instructions.trim().isNotEmpty) instructions,
      ];

  FinnFlow copyWith({
    String? name,
    String? description,
    String? instructions,
    String? category,
    bool? enabled,
    List<FlowStep>? steps,
    FlowTrigger? trigger,
    bool? granted,
  }) =>
      FinnFlow(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        instructions: instructions ?? this.instructions,
        category: category ?? this.category,
        enabled: enabled ?? this.enabled,
        builtIn: builtIn,
        steps: steps ?? this.steps,
        trigger: trigger ?? this.trigger,
        granted: granted ?? this.granted,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'instructions': instructions,
        'category': category,
        'enabled': enabled,
        'builtIn': builtIn,
        if (steps.isNotEmpty)
          'steps': [for (final step in steps) step.toJson()],
        if (trigger.isScheduled) 'trigger': trigger.toJson(),
        if (granted) 'granted': true,
      };

  factory FinnFlow.fromJson(Map<String, Object?> json) => FinnFlow(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        instructions: json['instructions']?.toString() ?? '',
        category: json['category']?.toString() ?? 'Custom',
        enabled: json['enabled'] == true,
        builtIn: json['builtIn'] == true,
        steps: [
          for (final step in (json['steps'] as List<Object?>? ?? const []))
            if (step is Map) FlowStep.fromJson(step.cast<String, Object?>()),
        ],
        trigger: json['trigger'] is Map
            ? FlowTrigger.fromJson(
                (json['trigger']! as Map<Object?, Object?>)
                    .cast<String, Object?>(),
              )
            : const FlowTrigger.manual(),
        // A grant is never inferred from the file. If the user revoked it, the
        // file says so; if they granted it, the file says so. The only way to
        // be wrong here is a hand-edited file, and the runner re-checks the
        // action against the catalog regardless.
        granted: json['granted'] == true,
      );
}

/// A step in a flow.
///
/// Four kinds, and the split matters: only [notify] and [deviceAction] touch
/// anything outside the app, so they are the only ones that can change state or
/// interrupt the user. A flow made of [prompt] steps is a prompt template; a
/// flow with a [deviceAction] step is an automation, and it is the kind that
/// needs a standing grant.
enum FlowStepKind {
  /// Ask the model something. The answer becomes the next step's input.
  prompt,

  /// Run an allowlisted device action (an alarm, the torch, media transport).
  deviceAction,

  /// Say something out loud, or write a note. Changes nothing.
  notify,

  /// Look something up on the web and use the result.
  browse,
}

@immutable
class FlowStep {
  const FlowStep({
    required this.kind,
    required this.text,
    this.actionName,
    this.arguments = const {},
  });

  final FlowStepKind kind;

  /// What this step is for. For a [FlowStepKind.prompt] this is the prompt; for
  /// a [FlowStepKind.deviceAction] it is a human-readable description of what
  /// the action does, since the arguments are machine-shaped.
  final String text;

  /// Set only for [FlowStepKind.deviceAction]. Must name an action in
  /// `DeviceActionCatalog`; the runner refuses anything else, so a flow file
  /// can never widen what the app is willing to do.
  final String? actionName;

  final Map<String, String> arguments;

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'text': text,
        if (actionName != null) 'action': actionName,
        if (arguments.isNotEmpty) 'args': arguments,
      };

  factory FlowStep.fromJson(Map<String, Object?> json) => FlowStep(
        kind: FlowStepKind.values.firstWhere(
          (k) => k.name == json['kind'],
          // An unknown kind is a step we cannot run. Reading it as `prompt`
          // would execute it as a model call the user never asked for.
          orElse: () => FlowStepKind.notify,
        ),
        text: json['text']?.toString() ?? '',
        actionName: json['action']?.toString(),
        arguments: {
          for (final entry in (json['args'] as Map<Object?, Object?>? ??
                  const <Object?, Object?>{})
              .entries)
            entry.key.toString(): entry.value?.toString() ?? '',
        },
      );
}

/// When a flow runs on its own.
///
/// [manual] is the only kind a flow can be *granted* — the standing grant
/// below is what a scheduled run spends, and a manual run always asks first.
enum FlowTriggerKind { manual, timeOfDay }

@immutable
class FlowTrigger {
  const FlowTrigger.manual()
      : kind = FlowTriggerKind.manual,
        hour = 0,
        minute = 0,
        daysOfWeek = const {};

  const FlowTrigger.daily(this.hour, this.minute)
      : kind = FlowTriggerKind.timeOfDay,
        daysOfWeek = const {};

  const FlowTrigger.weekly(this.hour, this.minute, this.daysOfWeek)
      : kind = FlowTriggerKind.timeOfDay;

  final FlowTriggerKind kind;

  /// Local time. A local time and not UTC on purpose: a flow that runs at 7am
  /// should run at 7am where the phone is, and the device timezone is what the
  /// user means by "7am".
  final int hour;
  final int minute;

  /// 1 = Monday .. 7 = Sunday, matching `DateTime.weekday`. Empty means every
  /// day for a [FlowTriggerKind.timeOfDay].
  final Set<int> daysOfWeek;

  bool get isScheduled => kind == FlowTriggerKind.timeOfDay;

  /// Whether this trigger is due at [now], given that the caller has already
  /// decided to run at most once per minute.
  ///
  /// Exposed as a pure function so the whole scheduling rule is testable
  /// without a clock, a plugin, or a device.
  bool isDueAt(DateTime now) {
    if (!isScheduled) return false;
    if (now.hour != hour || now.minute != minute) return false;
    return daysOfWeek.isEmpty || daysOfWeek.contains(now.weekday);
  }

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        if (isScheduled) 'hour': hour,
        if (isScheduled) 'minute': minute,
        if (daysOfWeek.isNotEmpty) 'days': daysOfWeek.toList()..sort(),
      };

  factory FlowTrigger.fromJson(Map<String, Object?> json) {
    if (json['kind'] != FlowTriggerKind.timeOfDay.name) {
      return const FlowTrigger.manual();
    }
    final hour = (json['hour'] as num?)?.toInt();
    final minute = (json['minute'] as num?)?.toInt();
    if (hour == null || minute == null) return const FlowTrigger.manual();
    return FlowTrigger.daily(hour.clamp(0, 23), minute.clamp(0, 59));
  }
}

/// How one run of a flow ended.
enum FlowRunOutcome {
  /// Every step ran and the flow was allowed to execute its device actions.
  completed,

  /// A step asked for confirmation and the user declined.
  declined,

  /// The flow has no standing grant for a device action, so it stopped and
  /// asked. This is the outcome that must be impossible to skip.
  needsGrant,

  /// A step failed. The flow stopped; later steps did not run.
  failed,

  /// The run was cancelled, or the app was killed mid-run.
  interrupted,
}

@immutable
class FlowStepResult {
  const FlowStepResult({
    required this.index,
    required this.kind,
    required this.outcome,
    this.detail = '',
  });

  final int index;
  final FlowStepKind kind;
  final FlowRunOutcome outcome;

  /// Never model text. A run log is committed to storage and read back on
  /// device, so it records what happened, not what the model said.
  final String detail;

  Map<String, Object?> toJson() => {
        'index': index,
        'kind': kind.name,
        'outcome': outcome.name,
        if (detail.isNotEmpty) 'detail': detail,
      };

  factory FlowStepResult.fromJson(Map<String, Object?> json) => FlowStepResult(
        index: (json['index'] as num?)?.toInt() ?? 0,
        kind: FlowStepKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => FlowStepKind.notify,
        ),
        outcome: FlowRunOutcome.values.firstWhere(
          (o) => o.name == json['outcome'],
          orElse: () => FlowRunOutcome.failed,
        ),
        detail: json['detail']?.toString() ?? '',
      );
}

/// One run of a flow, kept so the user can see what an automation did.
@immutable
class FlowRun {
  const FlowRun({
    required this.id,
    required this.flowId,
    required this.startedAt,
    required this.outcome,
    this.steps = const [],
    this.triggeredBy = 'manual',
  });

  final String id;
  final String flowId;
  final DateTime startedAt;
  final FlowRunOutcome outcome;
  final List<FlowStepResult> steps;

  /// `manual` or `schedule`. Recorded because "it did this by itself" is a
  /// different thing to be told than "I asked it to".
  final String triggeredBy;

  Map<String, Object?> toJson() => {
        'id': id,
        'flowId': flowId,
        'startedAt': startedAt.toIso8601String(),
        'outcome': outcome.name,
        'triggeredBy': triggeredBy,
        'steps': [for (final step in steps) step.toJson()],
      };

  factory FlowRun.fromJson(Map<String, Object?> json) => FlowRun(
        id: json['id']?.toString() ?? '',
        flowId: json['flowId']?.toString() ?? '',
        startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        outcome: FlowRunOutcome.values.firstWhere(
          (o) => o.name == json['outcome'],
          orElse: () => FlowRunOutcome.failed,
        ),
        triggeredBy: json['triggeredBy']?.toString() ?? 'manual',
        steps: [
          for (final step in (json['steps'] as List<Object?>? ?? const []))
            FlowStepResult.fromJson(
              (step as Map<Object?, Object?>).cast<String, Object?>(),
            ),
        ],
      );
}

/// Why a flow cannot be run as written.
///
/// Distinct from [FlowRunOutcome.failed]: this is about the flow's *shape*,
/// catchable before anything runs, where a bad step would otherwise fail
/// halfway through and leave the user unsure what had already happened.
enum FlowValidationProblem {
  /// No steps at all.
  empty,

  /// A device action naming something not in the catalog. This is the one that
  /// matters: it means a hand-edited or imported flow is trying to make the app
  /// do something the allowlist does not permit.
  unknownAction,

  /// A device action missing a required argument.
  missingArgument,

  /// A scheduled trigger that is not a real local time.
  invalidSchedule,
}

@immutable
class FlowValidation {
  const FlowValidation(this.problems, {required this.hasDeviceAction});

  final List<FlowValidationProblem> problems;

  /// Whether the flow contains a device-action step.
  ///
  /// The rule the whole feature rests on: a flow with a device action needs a
  /// grant before a *scheduled* run will execute it. A prompt-only flow is
  /// inert — it spends model time and writes a note — so it needs none.
  final bool hasDeviceAction;

  bool get isValid => problems.isEmpty;

  bool get needsGrantForScheduledRun => hasDeviceAction;
}
