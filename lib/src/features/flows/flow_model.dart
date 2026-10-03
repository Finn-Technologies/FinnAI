import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/flows/flow_blocks.dart';
import 'package:finn_ai/src/features/flows/flow_conditions.dart';
import 'package:finn_ai/src/features/flows/flow_triggers.dart';

export 'package:finn_ai/src/features/flows/flow_blocks.dart';
export 'package:finn_ai/src/features/flows/flow_conditions.dart';
export 'package:finn_ai/src/features/flows/flow_run_log.dart';
export 'package:finn_ai/src/features/flows/flow_triggers.dart';

/// One flow: *when* something starts it, *only if* conditions hold, and the
/// blocks it then runs.
///
/// There are two kinds of thing in the store and they share this class:
///
/// * a **guide** has [instructions] and no blocks. It shapes chat replies and
///   never runs;
/// * an **automation** has blocks and (usually) triggers. It runs by hand, on a
///   schedule or when something happens on the phone, and it is the only kind
///   that can act on the device.
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
    this.blocks = const [],
    this.triggers = const [],
    this.conditions = const [],
    this.granted = false,
  });

  final String id;
  final String name;
  final String description;
  final String instructions;
  final String category;
  final bool enabled;
  final bool builtIn;

  /// What the flow does, in order. Empty for a guide.
  final List<FlowBlock> blocks;

  /// What starts the flow on its own. Any one of them does. Empty means the
  /// flow only runs when the user starts it.
  final List<FlowTrigger> triggers;

  /// Conditions that must all hold for a run that *something else* started.
  /// A run the user starts by hand ignores them: asking is a stronger signal
  /// than any condition.
  final List<FlowCondition> conditions;

  /// The user's standing permission for this flow to act on the device by
  /// itself.
  ///
  /// Only ever set by an explicit user action, only consulted for a run that
  /// something other than the user started, and only meaningful when the flow
  /// has a device-action block. A manual run asks every time regardless: the
  /// grant is what lets something happen when the user is not looking, so it is
  /// the only thing that must not be implicit.
  final bool granted;

  bool get isAutomation => blocks.isNotEmpty;

  /// The first trigger, or a manual one. Kept for callers that show one line.
  FlowTrigger get trigger =>
      triggers.isEmpty ? const FlowTrigger.manual() : triggers.first;

  /// Triggers that need an alarm (a clock time or an interval).
  Iterable<FlowTrigger> get scheduledTriggers =>
      triggers.where((t) => t.isScheduled);

  /// Triggers that need the device-event service.
  Iterable<FlowTrigger> get eventTriggers => triggers.where((t) => t.isEvent);

  /// Whether this flow can act on the device at all.
  bool get hasDeviceAction =>
      allBlocks.any((block) => block.kind == FlowBlockKind.action);

  /// Whether a run that something else started would be allowed to execute.
  bool get autoRunIsPermitted => !hasDeviceAction || granted;

  /// Every block, including the ones inside branches.
  Iterable<FlowBlock> get allBlocks sync* {
    for (final block in blocks) {
      yield* block.flatten();
    }
  }

  /// What the model is told about this flow. A guide contributes its
  /// instructions; an automation contributes nothing, because its prompts are
  /// for its own runs and must never leak into chat.
  List<String> get promptLines => [
        if (!isAutomation && instructions.trim().isNotEmpty) instructions,
      ];

  FinnFlow copyWith({
    String? name,
    String? description,
    String? instructions,
    String? category,
    bool? enabled,
    List<FlowBlock>? blocks,
    List<FlowTrigger>? triggers,
    List<FlowCondition>? conditions,
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
        blocks: blocks ?? this.blocks,
        triggers: triggers ?? this.triggers,
        conditions: conditions ?? this.conditions,
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
        if (blocks.isNotEmpty)
          'blocks': [for (final block in blocks) block.toJson()],
        if (triggers.isNotEmpty)
          'triggers': [for (final trigger in triggers) trigger.toJson()],
        if (conditions.isNotEmpty)
          'conditions': [for (final c in conditions) c.toJson()],
        if (granted) 'granted': true,
      };

  /// Reads a version-3 flow. Older documents go through `FlowCodec`, which
  /// turns their steps into blocks first.
  factory FinnFlow.fromJson(Map<String, Object?> json) => FinnFlow(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        instructions: json['instructions']?.toString() ?? '',
        category: json['category']?.toString() ?? 'Custom',
        enabled: json['enabled'] == true,
        builtIn: json['builtIn'] == true,
        blocks: FlowBlock.listFromJson(json['blocks']),
        triggers: FlowTrigger.listFromJson(json['triggers']),
        conditions: FlowCondition.listFromJson(json['conditions']),
        // A grant is never inferred from the file. If the user revoked it, the
        // file says so; if they granted it, the file says so. The only way to
        // be wrong here is a hand-edited file, and the runner re-checks every
        // action against the catalog regardless.
        granted: json['granted'] == true,
      );
}
