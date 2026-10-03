import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/flows/flow_conditions.dart';

/// What a block does. Closed on purpose: a flow can only ever do things in this
/// list, and only [action] touches the device.
enum FlowBlockKind {
  /// Ask FinnAI something. The answer becomes `{ai}` for the blocks after.
  ask,

  /// Look something up on the web. What it finds is given to the next [ask].
  web,

  /// Show a notification.
  notify,

  /// Say something out loud.
  speak,

  /// Do something on the device, from the allowlist in `DeviceActionCatalog`.
  action,

  /// Wait a few seconds.
  wait,

  /// Ask a yes/no question and run one of two lanes.
  branch,

  /// Put the last answer in a chat the user can open.
  saveToChat,

  /// End the flow here.
  stop;

  static FlowBlockKind? fromName(String? name) {
    // Names a version-2 flow or run log used.
    final current = switch (name) {
      'prompt' => 'ask',
      'browse' => 'web',
      'deviceAction' => 'action',
      _ => name,
    };
    return FlowBlockKind.values.where((k) => k.name == current).firstOrNull;
  }

  /// Blocks that cannot run when the phone is idle in a pocket, because they
  /// need to show something on screen. (Device actions decide this one by one;
  /// see `DeviceActionCatalog.runsInBackground`.)
  bool get touchesDevice => this == action;
}

/// One step of a flow.
///
/// A single class for every kind, with the fields each kind reads documented
/// here, because a flow is edited, stored, shown and run by code that wants to
/// treat blocks alike, and a sealed hierarchy would make each of those a switch
/// over seven types for little gain.
@immutable
class FlowBlock {
  const FlowBlock({
    required this.kind,
    this.text = '',
    this.title = '',
    this.actionName,
    this.arguments = const {},
    this.seconds = 0,
    this.condition,
    this.then = const [],
    this.otherwise = const [],
  });

  /// "Ask FinnAI": [text] is the prompt. `{input}` is the previous answer and
  /// `{date}`, `{time}`, `{battery}` are filled in.
  const FlowBlock.ask(String text) : this(kind: FlowBlockKind.ask, text: text);

  /// "Look up": [text] is the query. `news: …` and `weather: …` use a source
  /// built for that question.
  const FlowBlock.web(String text) : this(kind: FlowBlockKind.web, text: text);

  /// "Notify": [text] is the message, or empty to send the last answer.
  const FlowBlock.notify(String text, {String title = ''})
      : this(kind: FlowBlockKind.notify, text: text, title: title);

  /// "Say it": [text] is what to say, or empty for the last answer.
  const FlowBlock.speak(String text)
      : this(kind: FlowBlockKind.speak, text: text);

  const FlowBlock.action(String name,
      [Map<String, String> arguments = const {}])
      : this(
          kind: FlowBlockKind.action,
          actionName: name,
          arguments: arguments,
        );

  const FlowBlock.wait(int seconds)
      : this(kind: FlowBlockKind.wait, seconds: seconds);

  const FlowBlock.branch(
    FlowCondition condition, {
    List<FlowBlock> then = const [],
    List<FlowBlock> otherwise = const [],
  }) : this(
          kind: FlowBlockKind.branch,
          condition: condition,
          then: then,
          otherwise: otherwise,
        );

  const FlowBlock.saveToChat() : this(kind: FlowBlockKind.saveToChat);

  const FlowBlock.stop() : this(kind: FlowBlockKind.stop);

  final FlowBlockKind kind;

  /// The prompt, query, message or spoken text, by kind.
  final String text;

  /// A notification's heading. Empty uses the flow's name.
  final String title;

  /// For [FlowBlockKind.action]: must name an action in `DeviceActionCatalog`.
  /// The runner refuses anything else, so a flow file can never widen what the
  /// app is willing to do.
  final String? actionName;
  final Map<String, String> arguments;

  /// For [FlowBlockKind.wait].
  final int seconds;

  /// For [FlowBlockKind.branch]: the question, and what to run for yes and no.
  final FlowCondition? condition;
  final List<FlowBlock> then;
  final List<FlowBlock> otherwise;

  /// Most blocks a flow may hold, branches included.
  static const int maxPerFlow = 30;

  /// Deepest nesting of branches.
  static const int maxDepth = 3;

  /// Longest wait. The run happens with the phone in the background, where the
  /// system will not keep us alive for long.
  static const int maxWaitSeconds = 120;

  static const int maxTextLength = 600;

  FlowBlock copyWith({
    String? text,
    String? title,
    String? actionName,
    Map<String, String>? arguments,
    int? seconds,
    FlowCondition? condition,
    List<FlowBlock>? then,
    List<FlowBlock>? otherwise,
  }) =>
      FlowBlock(
        kind: kind,
        text: text ?? this.text,
        title: title ?? this.title,
        actionName: actionName ?? this.actionName,
        arguments: arguments ?? this.arguments,
        seconds: seconds ?? this.seconds,
        condition: condition ?? this.condition,
        then: then ?? this.then,
        otherwise: otherwise ?? this.otherwise,
      );

  /// This block and every block inside it, in running order.
  Iterable<FlowBlock> flatten() sync* {
    yield this;
    for (final inner in then) {
      yield* inner.flatten();
    }
    for (final inner in otherwise) {
      yield* inner.flatten();
    }
  }

  /// How many blocks this one holds, itself included.
  int get size => flatten().length;

  /// Deepest branch nesting at or under this block (a plain block is 0).
  int get depth => kind != FlowBlockKind.branch
      ? 0
      : 1 +
          [
            for (final inner in [...then, ...otherwise]) inner.depth,
            0,
          ].reduce((a, b) => a > b ? a : b);

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        if (text.isNotEmpty) 'text': text,
        if (title.isNotEmpty) 'title': title,
        if (actionName != null) 'action': actionName,
        if (arguments.isNotEmpty) 'args': arguments,
        if (kind == FlowBlockKind.wait) 'seconds': seconds,
        if (condition != null) 'if': condition!.toJson(),
        if (then.isNotEmpty) 'then': [for (final b in then) b.toJson()],
        if (otherwise.isNotEmpty)
          'else': [for (final b in otherwise) b.toJson()],
      };

  /// Null for a kind this version does not know. Reading an unknown block as a
  /// notification, as version 2 did for steps, would run something the user
  /// never wrote; dropping it is safer.
  static FlowBlock? fromJson(Object? raw, {int depth = 0}) {
    if (raw is! Map) return null;
    final kind = FlowBlockKind.fromName(raw['kind']?.toString());
    if (kind == null) return null;
    if (kind == FlowBlockKind.branch && depth >= maxDepth) return null;
    String clip(Object? value, int max) {
      final text = value?.toString().trim() ?? '';
      return text.length <= max ? text : text.substring(0, max);
    }

    return FlowBlock(
      kind: kind,
      text: clip(raw['text'], maxTextLength),
      title: clip(raw['title'], 60),
      actionName: raw['action']?.toString(),
      arguments: {
        for (final entry in (raw['args'] as Map<Object?, Object?>? ??
                const <Object?, Object?>{})
            .entries)
          entry.key.toString(): clip(entry.value, 200),
      },
      seconds:
          ((raw['seconds'] as num?)?.toInt() ?? 0).clamp(0, maxWaitSeconds),
      condition: FlowCondition.fromJson(raw['if']),
      then: listFromJson(raw['then'], depth: depth + 1),
      otherwise: listFromJson(raw['else'], depth: depth + 1),
    );
  }

  static List<FlowBlock> listFromJson(Object? raw, {int depth = 0}) => [
        if (raw is List)
          for (final item in raw)
            if (FlowBlock.fromJson(item, depth: depth) case final block?) block,
      ];

  @override
  bool operator ==(Object other) =>
      other is FlowBlock &&
      other.kind == kind &&
      other.text == text &&
      other.title == title &&
      other.actionName == actionName &&
      mapEquals(other.arguments, arguments) &&
      other.seconds == seconds &&
      other.condition == condition &&
      listEquals(other.then, then) &&
      listEquals(other.otherwise, otherwise);

  @override
  int get hashCode => Object.hash(kind, text, title, actionName, seconds,
      condition, then.length, otherwise.length);
}
