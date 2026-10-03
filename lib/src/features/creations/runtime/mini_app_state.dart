import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/features/creations/spec/safe_expression.dart';

/// Runtime state for one mini app.
///
/// Every mutation goes through [dispatch] or a direct binding setter, and the
/// only thing that can compute a value is [SafeExpression]. There is no
/// reflection, no scripting host and no dynamic invocation anywhere in this
/// class, which is what makes running model-authored specs safe by
/// construction rather than by sandboxing.
class MiniAppState extends ChangeNotifier {
  MiniAppState(this.spec)
      : _values = initialValuesFor(spec),
        _initial = initialValuesFor(spec);

  final MiniAppSpec spec;

  Map<String, Object?> _values;
  final Map<String, Object?> _initial;

  /// Bumped by [reset] so view state that mirrors a value (a text field, a
  /// slider) knows to re-read it.
  int _revision = 0;
  int get revision => _revision;

  Map<String, Object?> get values => Map.unmodifiable(_values);

  Object? valueOf(String key) => _values[key];

  /// Applies a button action.
  void dispatch(MiniAppAction action) {
    switch (action) {
      case SetAction(:final key, :final expression):
        _values[key] = expression.evaluate(_values);
      case ToggleAction(:final key):
        _values[key] = !_asBool(_values[key]);
      case IncrementAction(:final key, :final by):
        _values[key] = _asInt(_values[key]) + by;
      case AppendAction(:final key, :final value, :final clearKey):
        final text = SafeExpression.interpolate(value, _values).trim();
        // Nothing typed is nothing to add, and the field stays as it was.
        if (text.isEmpty) return;
        final current = _values[key];
        final items =
            current is List ? List<Object?>.from(current) : <Object?>[];
        items.add(text);
        _values[key] = items;
        if (clearKey != null) _values[clearKey] = '';
      case ResetAction():
        reset();
        return;
    }
    notifyListeners();
  }

  /// Writes a value bound directly by an input widget (field, slider, choice,
  /// switch) rather than through an action.
  void setValue(String key, Object? value) {
    if (_values[key] == value) return;
    _values[key] = value;
    notifyListeners();
  }

  /// Puts back what an earlier launch saved.
  ///
  /// Saved values are untrusted input (a file on disk): only keys the spec
  /// still uses are taken, each must have the same shape as the key's starting
  /// value, and text and lists are capped, so a damaged or hand-edited file can
  /// at worst leave a key at its default.
  void restore(Map<String, Object?> saved) {
    var changed = false;
    for (final key in _initial.keys) {
      if (!saved.containsKey(key)) continue;
      final value = _coerce(_initial[key], saved[key]);
      if (value == null) continue;
      _values[key] = value;
      changed = true;
    }
    if (!changed) return;
    _revision++;
    notifyListeners();
  }

  /// Longest saved text, and most saved list entries.
  static const int maxSavedText = 500;
  static const int maxSavedItems = 200;

  static String _cap(String text) => text.runes.length <= maxSavedText
      ? text
      : String.fromCharCodes(text.runes.take(maxSavedText));

  static Object? _coerce(Object? shape, Object? value) {
    switch (shape) {
      case bool _:
        return value is bool ? value : null;
      case int _:
        return switch (value) {
          final int number => number,
          final double number when number.isFinite => number.round(),
          _ => null,
        };
      case double _:
        return value is num && value.isFinite ? value.toDouble() : null;
      case List<Object?> _:
        if (value is! List) return null;
        return [
          for (final item in value.take(maxSavedItems))
            if (item != null) _cap('$item'),
        ];
      default:
        return switch (value) {
          final String text => _cap(text),
          final int number => number.toString(),
          _ => null,
        };
    }
  }

  void reset() {
    _values = Map<String, Object?>.from(_initial);
    _revision++;
    notifyListeners();
  }
}

/// Derives each key's starting value from how the spec uses it.
///
/// Without this a `progress` bound to a key that a button only ever increments
/// would start as `null` and render as a spinner forever. Priority decides the
/// winner when one key is used several ways, because a list that a button
/// appends to must start as a list even if a `text` also shows it.
Map<String, Object?> initialValuesFor(MiniAppSpec spec) {
  final seeds = <String, _Seed>{};
  void note(String key, int priority, Object? value) {
    final existing = seeds[key];
    if (existing == null || priority > existing.priority) {
      seeds[key] = _Seed(priority, value);
    }
  }

  void walk(List<MiniAppNode> nodes) {
    for (final node in nodes) {
      switch (node) {
        case FieldNode(:final key):
          note(key, 3, '');
        case ChoiceNode(:final key, :final options):
          note(key, 3, options.isEmpty ? '' : options.first);
        case ToggleNode(:final key):
          note(key, 4, false);
        case SliderNode(:final key, :final min):
          note(key, 2, min);
        case ButtonNode(:final action):
          switch (action) {
            case AppendAction(:final key):
              // Highest priority: a key that receives appends is a collection.
              note(key, 5, <Object?>[]);
            case ToggleAction(:final key):
              note(key, 4, false);
            case SetAction(:final key):
              note(key, 1, 0);
            case IncrementAction(:final key):
              note(key, 1, 0);
            case ResetAction():
              break;
          }
        case ContainerNode(:final children):
          walk(children);
        case TextNode():
        case ListNode():
        case ProgressNode():
        case ImageNode():
        case SpacerNode():
          break;
      }
    }
  }

  walk(spec.nodes);
  return {for (final entry in seeds.entries) entry.key: entry.value.value};
}

class _Seed {
  const _Seed(this.priority, this.value);

  final int priority;
  final Object? value;
}

int _asInt(Object? value) => switch (value) {
      final int number => number,
      final double number => number.toInt(),
      final bool flag => flag ? 1 : 0,
      final String text => int.tryParse(text.trim()) ?? 0,
      _ => 0,
    };

bool _asBool(Object? value) => switch (value) {
      final bool flag => flag,
      final int number => number != 0,
      final String text => text.toLowerCase() == 'true',
      _ => false,
    };
