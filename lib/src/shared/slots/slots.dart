import 'package:flutter/foundation.dart';

/// What kind of value a template slot holds.
enum SlotKind { text, integer, list, emoji, choice }

/// One fillable field of a template (a creation or a flow).
///
/// Shared so the two features never import each other.
///
/// A slot is deliberately tiny: a name, a kind, a limit and a fallback. The
/// model only ever has to produce these values, never a layout, and every value
/// passes through [SlotSanitizer] so nothing a model (or a person editing the
/// slot) types can break the template it is poured into.
@immutable
class TemplateSlot {
  const TemplateSlot(
    this.key,
    this.kind, {
    required this.fallback,
    required this.example,
    this.description = '',
    this.maxChars = 40,
    this.minValue = 0,
    this.maxValue = 100,
    this.maxItems = 6,
    this.minItems = 1,
    this.options = const [],
  });

  /// JSON key, and the name the model is told.
  final String key;
  final SlotKind kind;

  /// Used when the model or the user gave nothing usable. Always valid.
  final Object fallback;

  /// Shown to the model as a *shape*, never as content to copy.
  final Object example;

  /// One line for the model: what this value is for.
  final String description;

  final int maxChars;
  final int minValue;
  final int maxValue;
  final int maxItems;
  final int minItems;
  final List<String> options;
}

/// The sanitised values for one template.
@immutable
class SlotValues {
  const SlotValues(this._values);

  final Map<String, Object?> _values;

  String text(String key) => _values[key] as String? ?? '';
  int integer(String key) => _values[key] as int? ?? 0;
  List<String> list(String key) =>
      (_values[key] as List<Object?>? ?? const []).cast<String>();

  Map<String, Object?> toJson() => Map.unmodifiable(_values);
}

/// Turns untrusted slot input into values a template can always use.
///
/// Never throws and never returns an invalid value: a slot that is missing,
/// the wrong type or out of range takes its fallback. Text loses control
/// characters, runs of whitespace and `{}` (a brace would let a value inject a
/// `{key}` placeholder into a mini app's text).
abstract final class SlotSanitizer {
  static SlotValues sanitize(
    List<TemplateSlot> slots,
    Map<String, Object?> raw,
  ) =>
      SlotValues({
        for (final slot in slots) slot.key: _one(slot, raw[slot.key]),
      });

  /// How many slots carried a usable value of their own (not a fallback).
  /// A reply with none is treated as "the model gave us nothing".
  static int usable(List<TemplateSlot> slots, Map<String, Object?> raw) {
    var count = 0;
    for (final slot in slots) {
      if (raw[slot.key] == null) continue;
      if (_one(slot, raw[slot.key]) != _one(slot, null) ||
          slot.kind == SlotKind.choice) {
        count++;
      }
    }
    return count;
  }

  static Object _one(TemplateSlot slot, Object? value) {
    switch (slot.kind) {
      case SlotKind.text:
        final text = cleanText(value, slot.maxChars);
        return text.isEmpty ? slot.fallback : text;
      case SlotKind.integer:
        final number = switch (value) {
          final num n => n.round(),
          final String s => int.tryParse(s.trim()),
          _ => null,
        };
        if (number == null) return slot.fallback;
        return number.clamp(slot.minValue, slot.maxValue);
      case SlotKind.list:
        final items = <String>[];
        final source = switch (value) {
          final List<Object?> l => l,
          final String s => s.split(RegExp(r'[\n;]')),
          _ => const <Object?>[],
        };
        for (final item in source) {
          final text = cleanText(item, slot.maxChars);
          if (text.isEmpty) continue;
          if (items.any((e) => e.toLowerCase() == text.toLowerCase())) continue;
          items.add(text);
          if (items.length == slot.maxItems) break;
        }
        return items.length < slot.minItems
            ? List<String>.of(slot.fallback as List<String>)
            : items;
      case SlotKind.emoji:
        if (value is! String) return slot.fallback;
        final runes = value.trim().runes.where((r) => r > 0x2000).toList();
        if (runes.isEmpty) return slot.fallback;
        return String.fromCharCodes(runes.take(2));
      case SlotKind.choice:
        final wanted = (value ?? '').toString().trim().toLowerCase();
        for (final option in slot.options) {
          if (option.toLowerCase() == wanted) return option;
        }
        return slot.fallback;
    }
  }

  /// Plain, single-line text of at most [maxChars] characters.
  static String cleanText(Object? value, int maxChars) {
    if (value == null) return '';
    var text = value
        .toString()
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F{}]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.length > maxChars) {
      text = text.substring(0, maxChars).trimRight();
    }
    return text;
  }
}
