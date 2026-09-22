/// Removes bare tool-call JSON from model output before it reaches the UI.
///
/// Tool calls are meant to arrive wrapped in `<tool_call>` tags, which
/// [FinnAccelerator] strips and parses. Small models sometimes emit the same
/// object without the wrapper (and can then repeat it until the token budget
/// runs out). Those bytes are not prose: the engine cannot act on them and the
/// user must never see them.
///
/// The filter holds back a short lookahead so it can recognise the start of a
/// call, then drops the object through its closing brace. Anything that is not
/// a recognised call passes through unchanged, so ordinary text (including
/// prose that happens to contain braces) still streams normally.
class BareToolCallFilter {
  BareToolCallFilter({Iterable<String>? toolNames})
      : _toolNames = Set<String>.unmodifiable(
          toolNames ?? defaultToolNames,
        );

  /// Tool names the engine knows how to execute, plus the aliases its parser
  /// accepts. Only these are treated as droppable calls.
  static const List<String> defaultToolNames = <String>[
    'browser_search',
    'browser_open',
    'browser_find',
    'search_browser',
    'web_search',
    'browse',
    'search',
    'open_url',
    'open',
    'navigate',
    'visit',
    'find_on_page',
    'find',
  ];

  /// Characters held back while deciding whether `{` begins a call.
  static const int _maxLookahead = 96;

  final Set<String> _toolNames;
  final StringBuffer _held = StringBuffer();

  bool _suppressing = false;
  int _depth = 0;
  bool _inString = false;
  bool _escaped = false;
  bool _skipLeadWhitespace = false;

  /// True once at least one tool call has been dropped.
  bool droppedToolCall = false;

  /// Feeds [chunk] and returns the text that may be displayed.
  String add(String chunk) {
    if (chunk.isEmpty) return '';
    _held.write(chunk);
    return _drain();
  }

  /// Returns any text still buffered when the stream ends.
  String flush() {
    if (_suppressing) {
      // A call truncated mid-object is not prose; drop it.
      _held.clear();
      return '';
    }
    _skipLeadWhitespace = false;
    final remaining = _drain(allowHold: false);
    if (_held.isEmpty) return remaining;
    final tail = _held.toString();
    _held.clear();
    return '$remaining$tail';
  }

  String _drain({bool allowHold = true}) {
    final out = StringBuffer();
    while (_held.isNotEmpty) {
      final text = _held.toString();
      if (_suppressing) {
        // The object bytes are dropped, so only the unconsumed remainder is
        // kept. Re-scanning already-counted bytes would double-count braces.
        final remainder = _consumeSuppressed(text);
        _held.clear();
        if (remainder == null) return out.toString();
        _held.write(remainder);
        continue;
      }
      if (_skipLeadWhitespace) {
        final trimmed = text.replaceFirst(RegExp(r'^\s+'), '');
        if (trimmed.isEmpty && allowHold) return out.toString();
        _skipLeadWhitespace = false;
        _held
          ..clear()
          ..write(trimmed);
        continue;
      }
      final brace = text.indexOf('{');
      if (brace < 0) {
        out.write(text);
        _held.clear();
        break;
      }
      if (brace > 0) {
        out.write(text.substring(0, brace));
        _held
          ..clear()
          ..write(text.substring(brace));
        continue;
      }
      // The buffer starts with '{': decide whether it opens a tool call.
      final head =
          text.length > _maxLookahead ? text.substring(0, _maxLookahead) : text;
      final looksLikeCall = _looksLikeToolCall(head);
      if (looksLikeCall != null) {
        if (!looksLikeCall) {
          out.write('{');
          _held
            ..clear()
            ..write(text.substring(1));
          continue;
        }
        _suppressing = true;
        _depth = 0;
        _inString = false;
        _escaped = false;
        continue;
      }
      if (text.length < _maxLookahead) {
        if (allowHold) return out.toString();
        // End of stream with an undecidable prefix: show it.
        out.write(text);
        _held.clear();
        break;
      }
      // Too long to be the call we are looking for.
      out.write('{');
      _held
        ..clear()
        ..write(text.substring(1));
    }
    return out.toString();
  }

  /// `true` when the buffered head starts a droppable tool call, `false` when
  /// it definitely does not, and `null` when more input is needed.
  bool? _looksLikeToolCall(String head) {
    final nameMatch = RegExp(r'"name"\s*:\s*"([A-Za-z_]+)"').firstMatch(head);
    if (nameMatch != null) {
      final name = nameMatch.group(1)!;
      // A complete "name" whose value is a tool the engine can execute is a
      // call, whether or not the argument bag has finished streaming. Any
      // other name is ordinary JSON and is left alone.
      return _toolNames.contains(name);
    }
    // No complete name field yet. While the object is still open and short we
    // wait for more input; once it closes (or outgrows the window) without a
    // recognised tool name it is ordinary text and streams through.
    if (!head.contains('}') && head.length < _maxLookahead) return null;
    return false;
  }

  /// Consumes [text] while inside a dropped object. Returns the unconsumed
  /// remainder once the object closes, or `null` when it is still open (the
  /// rest of the stream belongs to the object and is dropped).
  String? _consumeSuppressed(String text) {
    for (var index = 0; index < text.length; index++) {
      final char = text[index];
      if (_escaped) {
        _escaped = false;
        continue;
      }
      if (_inString) {
        if (char == r'\') {
          _escaped = true;
        } else if (char == '"') {
          _inString = false;
        }
        continue;
      }
      if (char == '"') {
        _inString = true;
      } else if (char == '{') {
        _depth++;
      } else if (char == '}') {
        _depth--;
        if (_depth <= 0) {
          _suppressing = false;
          _skipLeadWhitespace = true;
          droppedToolCall = true;
          return text.substring(index + 1);
        }
      }
    }
    return null;
  }
}
