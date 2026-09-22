/// Deterministic repair for the mistake a small model keeps making.
///
/// A spec may not display a stored key that nothing in the spec ever writes —
/// `SpecValidator` rejects it, and a repair round that only re-asks tends to
/// get the same mistake back, which is how a habit-tracker brief once ended up
/// as the generic fallback counter twice in a row.
///
/// So instead of re-asking: drop the nodes that display a key with no writer,
/// and let the validator decide whether what is left is usable. The rest of
/// what the user asked for survives, and the caller always re-validates — the
/// repair is only accepted when the pruned spec has no issues at all, so a
/// partial fix can never ship.
///
/// The display sites mirrored here are exactly the ones
/// `SpecValidator.validateMiniApp` collects as `referenced`: a `{key}` inside a
/// `text` value, and the `bind` of a `list` or `progress`. Anything else is
/// left alone rather than risk deleting content the validator never objected
/// to.
library;

import 'dart:convert';

/// Node types whose `key` is written by the node itself.
const Set<String> _keyWritingTypes = {'field', 'toggle', 'slider', 'choice'};

/// Action kinds that write their `key`.
const Set<String> _keyWritingActionKinds = {
  'set',
  'toggle',
  'increment',
  'append',
};

/// Node types whose `bind` displays a stored key.
const Set<String> _bindDisplayTypes = {'list', 'progress'};

/// Container types that become invalid once they lose every child.
const Set<String> _containerTypes = {'row', 'column'};

final RegExp _interpolation = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');

/// Returns a copy of [spec] without nodes that display an unwritten key, or
/// `null` when there is nothing to remove.
Map<String, Object?>? pruneUnwiredNodes(Map<String, Object?> spec) {
  final nodes = spec['nodes'];
  if (nodes is! List || nodes.isEmpty) return null;

  final unwired = _displayedKeys(spec).difference(_writtenKeys(spec));
  if (unwired.isEmpty) return null;

  final kept = <Object?>[];
  for (final node in nodes) {
    final pruned = _pruneNode(node, unwired);
    if (pruned != null) kept.add(pruned);
  }
  // A mini app needs at least one node; an empty result is not a repair.
  if (kept.isEmpty) return null;

  final repaired = Map<String, Object?>.from(spec)..['nodes'] = kept;
  // Compare the encoded form, not just the child count: a removal nested inside
  // a row still has to count as a change.
  return jsonEncode(repaired) == jsonEncode(spec) ? null : repaired;
}

/// Every key the spec stores, wherever it is stored from.
Set<String> _writtenKeys(Object? node, [Set<String>? accumulator]) {
  final written = accumulator ?? <String>{};
  if (node is List) {
    for (final item in node) {
      _writtenKeys(item, written);
    }
    return written;
  }
  if (node is! Map) return written;

  final key = node['key'];
  if (key is String && key.trim().isNotEmpty) {
    final name = key.trim();
    final type = node['type'];
    final kind = node['kind'];
    if (type is String &&
        _keyWritingTypes.contains(type.trim().toLowerCase())) {
      written.add(name);
    }
    if (kind is String &&
        _keyWritingActionKinds.contains(kind.trim().toLowerCase())) {
      written.add(name);
    }
  }
  for (final value in node.values) {
    _writtenKeys(value, written);
  }
  return written;
}

/// Every key a node displays: `{key}` in a `text` value, and the `bind` of a
/// `list` or `progress`.
Set<String> _displayedKeys(Object? node, [Set<String>? accumulator]) {
  final displayed = accumulator ?? <String>{};
  if (node is List) {
    for (final item in node) {
      _displayedKeys(item, displayed);
    }
    return displayed;
  }
  if (node is! Map) return displayed;

  final type = node['type'];
  if (type is String) {
    final name = type.trim().toLowerCase();
    if (_bindDisplayTypes.contains(name)) {
      final bind = node['bind'];
      if (bind is String && bind.trim().isNotEmpty) {
        displayed.add(bind.trim());
      }
    }
    if (name == 'text') {
      final value = node['value'];
      if (value is String) {
        for (final match in _interpolation.allMatches(value)) {
          displayed.add(match.group(1)!);
        }
      }
    }
  }
  for (final value in node.values) {
    _displayedKeys(value, displayed);
  }
  return displayed;
}

/// The node without its unwired parts, or `null` when the node itself displays
/// a key nothing writes.
Object? _pruneNode(Object? node, Set<String> unwired) {
  if (node is! Map) return node;
  final map = Map<String, Object?>.from(node);

  final children = map['children'];
  if (children is List) {
    final kept = <Object?>[];
    for (final child in children) {
      final pruned = _pruneNode(child, unwired);
      if (pruned != null) kept.add(pruned);
    }
    if (kept.isEmpty && _isContainer(map)) return null;
    map['children'] = kept;
  }

  return _displaysUnwiredKey(map, unwired) ? null : map;
}

bool _isContainer(Map<String, Object?> node) {
  final type = node['type'];
  return type is String && _containerTypes.contains(type.trim().toLowerCase());
}

bool _displaysUnwiredKey(Map<String, Object?> node, Set<String> unwired) {
  final type = node['type'];
  final name = type is String ? type.trim().toLowerCase() : '';

  if (_bindDisplayTypes.contains(name)) {
    final bind = node['bind'];
    if (bind is String && unwired.contains(bind.trim())) return true;
  }
  if (name == 'text') {
    final value = node['value'];
    if (value is String) {
      for (final match in _interpolation.allMatches(value)) {
        if (unwired.contains(match.group(1))) return true;
      }
    }
  }
  return false;
}
