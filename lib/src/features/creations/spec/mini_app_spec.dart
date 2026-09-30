import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/creations/spec/safe_expression.dart';
import 'package:finn_ai/src/features/creations/spec/spec_json.dart';

/// Pastel accent used by a creation's tile and mini-app chrome.
///
/// The mapping to an actual color lives in the render layer so this model stays
/// plain data. The set is closed so generated specs cannot introduce arbitrary
/// styling — that is a large part of why the custom gesture painting in the
/// legacy implementation looked inconsistent with the theme tokens.
enum MiniAppAccent {
  mint,
  blue,
  lime,
  amber,
  rose,
  violet,
  sky;

  static MiniAppAccent parse(String raw) => switch (raw.trim().toLowerCase()) {
        'mint' => MiniAppAccent.mint,
        'blue' => MiniAppAccent.blue,
        'lime' => MiniAppAccent.lime,
        'amber' => MiniAppAccent.amber,
        'rose' => MiniAppAccent.rose,
        'violet' => MiniAppAccent.violet,
        'sky' => MiniAppAccent.sky,
        _ => throw FormatException('"$raw" is not a known accent'),
      };
}

/// Text emphasis for a `text` node.
enum MiniAppTextRole {
  title,
  body,
  caption;

  static MiniAppTextRole parse(String raw) =>
      switch (raw.trim().toLowerCase()) {
        'title' => MiniAppTextRole.title,
        'caption' => MiniAppTextRole.caption,
        _ => MiniAppTextRole.body,
      };
}

/// The closed vocabulary of node types a generated mini app may use.
enum MiniAppNodeType {
  text,
  button,
  field,
  toggle,
  slider,
  list,
  progress,
  choice,
  image,
  row,
  column,
  spacer;

  static MiniAppNodeType parse(String raw) {
    try {
      return MiniAppNodeType.values.byName(raw.trim().toLowerCase());
    } on ArgumentError {
      throw FormatException('"$raw" is not a supported node type');
    }
  }
}

/// A state mutation a button can perform.
sealed class MiniAppAction {
  const MiniAppAction();

  factory MiniAppAction.fromJson(Map<String, Object?> json) {
    final kind = SpecJson.string(json, 'kind');
    switch (kind.trim().toLowerCase()) {
      case 'set':
        final source = SpecJson.string(json, 'expr');
        try {
          return SetAction(
            key: SpecJson.string(json, 'key'),
            source: source,
            expression: SafeExpression.parse(source),
          );
        } on ExpressionException catch (error) {
          throw FormatException(error.message);
        }
      case 'toggle':
        return ToggleAction(key: SpecJson.string(json, 'key'));
      case 'increment':
        return IncrementAction(
          key: SpecJson.string(json, 'key'),
          by: SpecJson.intOr(json, 'by', 1),
        );
      case 'append':
        final clear = SpecJson.stringOr(json, 'clear', '');
        return AppendAction(
          key: SpecJson.string(json, 'key'),
          value: SpecJson.string(json, 'value'),
          clearKey: clear.isEmpty ? null : clear,
        );
      case 'reset':
        return const ResetAction();
      default:
        throw FormatException('"$kind" is not a supported action');
    }
  }

  Map<String, Object?> toJson();
}

/// Assigns `expression` to `key`.
final class SetAction extends MiniAppAction {
  const SetAction({
    required this.key,
    required this.source,
    required this.expression,
  });

  final String key;
  final String source;
  final SafeExpression expression;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'set',
        'key': key,
        'expr': source,
      };
}

/// Flips a boolean `key`.
final class ToggleAction extends MiniAppAction {
  const ToggleAction({required this.key});

  final String key;

  @override
  Map<String, Object?> toJson() => {'kind': 'toggle', 'key': key};
}

/// Adds `by` to an integer `key`.
final class IncrementAction extends MiniAppAction {
  const IncrementAction({required this.key, required this.by});

  final String key;
  final int by;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'increment',
        'key': key,
        'by': by,
      };
}

/// Appends `value` to the list stored at `key`.
///
/// `value` may contain `{key}` placeholders, which read state when the button
/// is pressed: `{"value":"{draft}","clear":"draft"}` adds what was typed in the
/// `draft` field and empties the field, which is what makes a notes or
/// shopping list possible. A value that resolves to nothing adds nothing.
final class AppendAction extends MiniAppAction {
  const AppendAction({required this.key, required this.value, this.clearKey});

  final String key;
  final String value;

  /// A key to set back to empty after appending (usually the input field).
  final String? clearKey;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'append',
        'key': key,
        'value': value,
        if (clearKey != null) 'clear': clearKey,
      };
}

/// Clears every state key back to the spec's initial values.
final class ResetAction extends MiniAppAction {
  const ResetAction();

  @override
  Map<String, Object?> toJson() => {'kind': 'reset'};
}

/// One element of a generated mini app screen.
sealed class MiniAppNode {
  const MiniAppNode();

  factory MiniAppNode.fromJson(Map<String, Object?> json) {
    final type = MiniAppNodeType.parse(SpecJson.string(json, 'type'));
    return switch (type) {
      MiniAppNodeType.text => TextNode(
          value: SpecJson.string(json, 'value'),
          role: MiniAppTextRole.parse(SpecJson.stringOr(json, 'style', 'body')),
        ),
      MiniAppNodeType.button => ButtonNode(
          label: SpecJson.string(json, 'label'),
          action: MiniAppAction.fromJson(SpecJson.object(json, 'action')),
        ),
      MiniAppNodeType.field => FieldNode(
          key: SpecJson.string(json, 'key'),
          hint: SpecJson.stringOr(json, 'hint', ''),
        ),
      MiniAppNodeType.toggle => ToggleNode(
          key: SpecJson.string(json, 'key'),
          label: SpecJson.stringOr(json, 'label', ''),
        ),
      MiniAppNodeType.slider => SliderNode(
          key: SpecJson.string(json, 'key'),
          min: SpecJson.intOr(json, 'min', 0),
          max: SpecJson.intOr(json, 'max', 10),
        ),
      MiniAppNodeType.list => ListNode(
          bind: SpecJson.string(json, 'bind'),
          empty: SpecJson.stringOr(json, 'empty', ''),
        ),
      MiniAppNodeType.progress => ProgressNode(
          bind: SpecJson.string(json, 'bind'),
          max: SpecJson.intOr(json, 'max', 10),
        ),
      MiniAppNodeType.choice => ChoiceNode(
          key: SpecJson.string(json, 'key'),
          options: SpecJson.stringList(json, 'options'),
        ),
      MiniAppNodeType.image => ImageNode(
          emoji: SpecJson.stringOr(json, 'emoji', ''),
          url: SpecJson.stringOr(json, 'url', ''),
        ),
      MiniAppNodeType.row => ContainerNode(
          axis: MiniAppAxis.horizontal,
          children: _nodeList(json, 'children'),
        ),
      MiniAppNodeType.column => ContainerNode(
          axis: MiniAppAxis.vertical,
          children: _nodeList(json, 'children'),
        ),
      MiniAppNodeType.spacer =>
        SpacerNode(size: SpecJson.intOr(json, 'size', 12)),
    };
  }

  Map<String, Object?> toJson();

  /// The state keys this node reads, so the validator can check bindings and
  /// the runtime can seed initial values.
  Set<String> get referencedKeys;
}

/// Static or interpolated text. `{key}` placeholders resolve against state.
final class TextNode extends MiniAppNode {
  const TextNode({required this.value, this.role = MiniAppTextRole.body});

  final String value;
  final MiniAppTextRole role;

  @override
  Map<String, Object?> toJson() => {
        'type': 'text',
        'value': value,
        'style': role.name,
      };

  @override
  Set<String> get referencedKeys => _placeholdersIn(value);
}

/// A pill button that dispatches [action].
final class ButtonNode extends MiniAppNode {
  const ButtonNode({required this.label, required this.action});

  final String label;
  final MiniAppAction action;

  @override
  Map<String, Object?> toJson() => {
        'type': 'button',
        'label': label,
        'action': action.toJson(),
      };

  @override
  Set<String> get referencedKeys => switch (action) {
        SetAction(:final key, :final expression) => {
            key,
            ...expression.referencedKeys
          },
        ToggleAction(:final key) => {key},
        IncrementAction(:final key) => {key},
        AppendAction(:final key, :final value, :final clearKey) => {
            key,
            ..._placeholdersIn(value),
            if (clearKey != null) clearKey,
          },
        ResetAction() => const <String>{},
      };
}

/// A text input writing its value straight to [key].
final class FieldNode extends MiniAppNode {
  const FieldNode({required this.key, required this.hint});

  final String key;
  final String hint;

  @override
  Map<String, Object?> toJson() => {
        'type': 'field',
        'key': key,
        'hint': hint,
      };

  @override
  Set<String> get referencedKeys => {key};
}

/// A switch bound to a boolean [key].
final class ToggleNode extends MiniAppNode {
  const ToggleNode({required this.key, required this.label});

  final String key;
  final String label;

  @override
  Map<String, Object?> toJson() => {
        'type': 'toggle',
        'key': key,
        'label': label,
      };

  @override
  Set<String> get referencedKeys => {key};
}

/// An integer slider between [min] and [max].
final class SliderNode extends MiniAppNode {
  const SliderNode({required this.key, required this.min, required this.max});

  final String key;
  final int min;
  final int max;

  @override
  Map<String, Object?> toJson() => {
        'type': 'slider',
        'key': key,
        'min': min,
        'max': max,
      };

  @override
  Set<String> get referencedKeys => {key};
}

/// A list rendering the string collection stored at [bind].
final class ListNode extends MiniAppNode {
  const ListNode({required this.bind, required this.empty});

  final String bind;
  final String empty;

  @override
  Map<String, Object?> toJson() => {
        'type': 'list',
        'bind': bind,
        'empty': empty,
      };

  @override
  Set<String> get referencedKeys => {bind};
}

/// A progress bar reading 0..[max] from [bind].
final class ProgressNode extends MiniAppNode {
  const ProgressNode({required this.bind, required this.max});

  final String bind;
  final int max;

  @override
  Map<String, Object?> toJson() => {
        'type': 'progress',
        'bind': bind,
        'max': max,
      };

  @override
  Set<String> get referencedKeys => {bind};
}

/// A segmented control choosing one of [options].
final class ChoiceNode extends MiniAppNode {
  const ChoiceNode({required this.key, required this.options});

  final String key;
  final List<String> options;

  @override
  Map<String, Object?> toJson() => {
        'type': 'choice',
        'key': key,
        'options': options,
      };

  @override
  Set<String> get referencedKeys => {key};
}

/// An emoji or remote https image.
final class ImageNode extends MiniAppNode {
  const ImageNode({required this.emoji, required this.url});

  final String emoji;
  final String url;

  @override
  Map<String, Object?> toJson() => {
        'type': 'image',
        if (emoji.isNotEmpty) 'emoji': emoji,
        if (url.isNotEmpty) 'url': url,
      };

  @override
  Set<String> get referencedKeys => const <String>{};
}

/// Direction of a container node.
enum MiniAppAxis { horizontal, vertical }

/// A `row` or `column` holding child nodes.
final class ContainerNode extends MiniAppNode {
  const ContainerNode({required this.axis, required this.children});

  final MiniAppAxis axis;
  final List<MiniAppNode> children;

  @override
  Map<String, Object?> toJson() => {
        'type': axis == MiniAppAxis.horizontal ? 'row' : 'column',
        'children': children.map((child) => child.toJson()).toList(),
      };

  @override
  Set<String> get referencedKeys =>
      {for (final child in children) ...child.referencedKeys};
}

/// Fixed vertical space.
final class SpacerNode extends MiniAppNode {
  const SpacerNode({required this.size});

  final int size;

  @override
  Map<String, Object?> toJson() => {'type': 'spacer', 'size': size};

  @override
  Set<String> get referencedKeys => const <String>{};
}

/// A complete, validated, runnable mini application.
@immutable
class MiniAppSpec {
  const MiniAppSpec({
    required this.title,
    required this.accent,
    required this.nodes,
  });

  final String title;
  final MiniAppAccent accent;
  final List<MiniAppNode> nodes;

  factory MiniAppSpec.fromJson(Map<String, Object?> json) => MiniAppSpec(
        title: SpecJson.string(json, 'title'),
        accent: MiniAppAccent.parse(SpecJson.stringOr(json, 'accent', 'mint')),
        nodes: _nodeList(json, 'nodes'),
      );

  Map<String, Object?> toJson() => {
        'title': title,
        'accent': accent.name,
        'nodes': nodes.map((node) => node.toJson()).toList(),
      };

  /// Every state key the app reads, whether bound, set, or appended.
  Set<String> get referencedKeys =>
      {for (final node in nodes) ...node.referencedKeys};

  /// State keys the app writes to, so initial values can be seeded.
  Set<String> get writtenKeys => _writtenKeysIn(nodes);
}

Set<String> _writtenKeysIn(List<MiniAppNode> nodes) {
  final keys = <String>{};
  for (final node in nodes) {
    switch (node) {
      case ButtonNode(:final action):
        switch (action) {
          case SetAction(:final key):
            keys.add(key);
          case ToggleAction(:final key):
            keys.add(key);
          case IncrementAction(:final key):
            keys.add(key);
          case AppendAction(:final key):
            keys.add(key);
          case ResetAction():
            break;
        }
      case FieldNode(:final key):
        keys.add(key);
      case ToggleNode(:final key):
        keys.add(key);
      case SliderNode(:final key):
        keys.add(key);
      case ChoiceNode(:final key):
        keys.add(key);
      case ContainerNode(:final children):
        keys.addAll(_writtenKeysIn(children));
      case TextNode():
      case ListNode():
      case ProgressNode():
      case ImageNode():
      case SpacerNode():
        break;
    }
  }
  return keys;
}

Set<String> _placeholdersIn(String template) {
  if (!template.contains('{')) return const <String>{};
  return RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}')
      .allMatches(template)
      .map((match) => match.group(1)!)
      .toSet();
}

List<MiniAppNode> _nodeList(Map<String, Object?> json, String key) =>
    SpecJson.objectList(json, key).map(MiniAppNode.fromJson).toList(
          growable: false,
        );
