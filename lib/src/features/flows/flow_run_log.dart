import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/flows/flow_blocks.dart';

/// How one run of a flow ended.
enum FlowRunOutcome {
  /// Every block that was reached ran.
  completed,

  /// A block asked for confirmation and the user declined.
  declined,

  /// The flow has no standing grant for a device action, so it stopped and
  /// asked. This is the outcome that must be impossible to skip.
  needsGrant,

  /// A block needs the screen (it opens an app or a system page) and the run
  /// started while the phone was in the background. The user is told, and the
  /// flow runs when they tap.
  needsScreen,

  /// The flow's "only if" conditions did not hold, so nothing ran.
  skipped,

  /// A block failed. The flow stopped; later blocks did not run.
  failed,

  /// The run was cancelled, or the app was killed mid-run.
  interrupted,
}

@immutable
class FlowStepResult {
  const FlowStepResult({
    required this.path,
    required this.kind,
    required this.outcome,
    this.detail = '',
  });

  /// Where the block sits: `2` for the third block, `1.then.0` for the first
  /// block in the "yes" lane of the second.
  final String path;
  final FlowBlockKind kind;
  final FlowRunOutcome outcome;

  /// Never model text. A run log is committed to storage and read back on
  /// device, so it records what happened, not what the model said.
  final String detail;

  Map<String, Object?> toJson() => {
        'path': path,
        'kind': kind.name,
        'outcome': outcome.name,
        if (detail.isNotEmpty) 'detail': detail,
      };

  factory FlowStepResult.fromJson(Map<String, Object?> json) => FlowStepResult(
        // Version-2 logs had `index`.
        path: json['path']?.toString() ??
            '${(json['index'] as num?)?.toInt() ?? 0}',
        kind: FlowBlockKind.fromName(json['kind']?.toString()) ??
            FlowBlockKind.notify,
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
    this.durationMs = 0,
  });

  final String id;
  final String flowId;
  final DateTime startedAt;
  final FlowRunOutcome outcome;

  /// How long the run took, for the run screen. 0 for older records.
  final int durationMs;
  final List<FlowStepResult> steps;

  /// `manual`, `schedule`, `event:<trigger>`, `chat` or `shortcut`. Recorded
  /// because "it did this by itself" is a different thing to be told than "I
  /// asked it to".
  final String triggeredBy;

  Map<String, Object?> toJson() => {
        'id': id,
        'flowId': flowId,
        'startedAt': startedAt.toIso8601String(),
        'outcome': outcome.name,
        'triggeredBy': triggeredBy,
        if (durationMs > 0) 'ms': durationMs,
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
        durationMs: (json['ms'] as num?)?.toInt() ?? 0,
        steps: [
          for (final step in (json['steps'] as List<Object?>? ?? const []))
            if (step is Map)
              FlowStepResult.fromJson(step.cast<String, Object?>()),
        ],
      );
}

/// Why a flow cannot be run as written.
///
/// Distinct from [FlowRunOutcome.failed]: this is about the flow's *shape*,
/// catchable before anything runs, where a bad block would otherwise fail
/// halfway through and leave the user unsure what had already happened.
enum FlowValidationProblem {
  /// No blocks at all.
  empty,

  /// More blocks, or deeper branches, than a flow may have.
  tooLarge,

  /// A device action naming something not in the catalog. This is the one that
  /// matters: it means a hand-edited or imported flow is trying to make the app
  /// do something the allowlist does not permit.
  unknownAction,

  /// A device action missing a required argument.
  missingArgument,

  /// A trigger whose own values are not usable (a time that does not exist).
  invalidTrigger,

  /// A condition whose values are out of range.
  invalidCondition,
}

@immutable
class FlowValidation {
  const FlowValidation(this.problems, {required this.hasDeviceAction});

  final List<FlowValidationProblem> problems;

  /// Whether the flow contains a device-action block.
  ///
  /// The rule the whole feature rests on: a flow with a device action needs a
  /// grant before a run that something else started will execute it. A flow
  /// without one is inert — it spends model time and writes a note — so it
  /// needs none.
  final bool hasDeviceAction;

  bool get isValid => problems.isEmpty;

  bool get needsGrantForAutoRun => hasDeviceAction;
}
