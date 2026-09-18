/// Recovers the JSON object a small model meant to emit from its raw output.
///
/// A 1.6B model reliably does three things that break naive parsing: it wraps
/// the answer in a `<think>` block, it fences it in ```json, and it runs out of
/// budget mid-object. All three are handled here so the pipeline can treat
/// "malformed" and "truncated" as the same, recoverable case.
library;

import 'dart:convert';

/// Returns the most plausible spec object in [raw], or `null`.
///
/// Browser tool calls are skipped: the shared system prompt advertises them, so
/// a creation turn can emit `<tool_call>{"name":…}</tool_call>` before the real
/// answer, and that object must not be mistaken for a spec.
///
/// A spec-shaped object is preferred over merely the first decodable one,
/// because the prompt carries a worked example and a small model sometimes
/// emits a stray object before its answer. Ranking by shape rather than
/// position means an incidental object no longer wins by arriving first.
Map<String, Object?>? extractJsonObject(String raw) {
  final cleaned = stripReasoning(raw);
  Map<String, Object?>? firstDecodable;
  for (final candidate in _candidateObjects(cleaned)) {
    final decoded = _tryDecode(candidate) ?? _salvage(candidate);
    if (decoded == null || _looksLikeToolCall(decoded)) continue;
    if (_looksLikeSpec(decoded)) return decoded;
    firstDecodable ??= decoded;
  }
  return firstDecodable;
}

/// Whether [json] carries the shape every creation kind shares: a title plus
/// one of the three bodies.
bool _looksLikeSpec(Map<String, Object?> json) =>
    json['title'] is String &&
    (json.containsKey('nodes') ||
        json.containsKey('rows') ||
        json.containsKey('slides'));

/// Removes reasoning traces and Markdown fences.
String stripReasoning(String raw) => raw
    .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), ' ')
    .replaceAll(RegExp(r'<think>[\s\S]*$', caseSensitive: false), ' ')
    .replaceAll(RegExp(r'```[a-zA-Z]*'), ' ')
    .replaceAll('```', ' ');

/// Yields every balanced `{…}` region in order, plus any unterminated tail.
Iterable<String> _candidateObjects(String text) sync* {
  var index = 0;
  while (index < text.length) {
    final start = text.indexOf('{', index);
    if (start < 0) return;
    final end = _balancedEnd(text, start);
    if (end == null) {
      yield text.substring(start);
      return;
    }
    yield text.substring(start, end + 1);
    index = end + 1;
  }
}

/// Index of the `}` closing the object that opens at [start], or `null`.
int? _balancedEnd(String text, int start) {
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var index = start; index < text.length; index++) {
    final char = text[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char == r'\') {
      escaped = true;
      continue;
    }
    if (char == '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;
    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) return index;
    }
  }
  return null;
}

Map<String, Object?>? _tryDecode(String candidate) {
  try {
    final decoded = jsonDecode(candidate);
    if (decoded is Map) return Map<String, Object?>.from(decoded);
  } on Object {
    return null;
  }
  return null;
}

/// Trims the truncated tail of [text] until it decodes as a closed object.
///
/// Walks backwards one character at a time, closing whatever brackets and
/// quotes the model left open. Bounded so a hopeless payload fails fast instead
/// of costing a second of CPU on device.
Map<String, Object?>? _salvage(String text) {
  final start = text.indexOf('{');
  if (start < 0) return null;
  var candidate = text.substring(start);
  const maxTrims = 160;
  for (var attempt = 0;
      attempt <= maxTrims && candidate.length > 1;
      attempt++) {
    final decoded = _tryDecode(candidate + _closersFor(candidate));
    if (decoded != null) return decoded;
    candidate = candidate.substring(0, candidate.length - 1);
  }
  return null;
}

/// The closing characters needed to make [text] structurally complete.
String _closersFor(String text) {
  final stack = <String>[];
  var inString = false;
  var escaped = false;
  for (var index = 0; index < text.length; index++) {
    final char = text[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char == r'\') {
      escaped = true;
      continue;
    }
    if (char == '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;
    switch (char) {
      case '{':
        stack.add('}');
      case '[':
        stack.add(']');
      case '}' || ']':
        if (stack.isNotEmpty) stack.removeLast();
    }
  }
  final buffer = StringBuffer();
  if (inString) buffer.write('"');
  for (var index = stack.length - 1; index >= 0; index--) {
    buffer.write(stack[index]);
  }
  return buffer.toString();
}

bool _looksLikeToolCall(Map<String, Object?> json) {
  final hasName = json['name'] is String;
  final hasArguments =
      json.containsKey('arguments') || json.containsKey('parameters');
  final hasSpecKeys = json.containsKey('nodes') ||
      json.containsKey('rows') ||
      json.containsKey('slides');
  return hasName && hasArguments && !hasSpecKeys;
}
