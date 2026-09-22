/// Drops `<tool_call>` / `<tool_response>` blocks from streamed model output.
///
/// [FinnAccelerator] already removes these tags before a reply is shown, but
/// that only ever matched *whole* tags. When the model streamed the opening `<`
/// in one token and the rest in the next, the stray `<` survived and became the
/// entire visible answer of a turn that ran out of budget mid-call.
///
/// This filter holds back a trailing fragment that could still grow into a tag,
/// so a split tag is recognised instead of leaking, and once it sees an opening
/// tag it drops everything through the matching close — or the rest of the
/// stream if the block never closes, because truncated tool machinery is not
/// prose. Text that merely contains a `<` is passed through: only a fragment
/// that is a real prefix of one of these tags is held.
class ToolTagFilter {
  static const List<String> _names = <String>['tool_call', 'tool_response'];

  /// Matches either direction of either tag, case-insensitively.
  static final RegExp _anyTag = RegExp(
    '</?(?:${_names.join('|')})>',
    caseSensitive: false,
  );

  /// Longest tag length minus one: the tail that has to be retained so a tag
  /// split across tokens is still recognised once its last character arrives.
  static final int _holdLength = _names
          .expand((name) => <String>['<$name>', '</$name>'])
          .map((tag) => tag.length)
          .reduce((a, b) => a > b ? a : b) -
      1;

  final StringBuffer _held = StringBuffer();
  bool _inside = false;

  /// Feeds [chunk] and returns the text that may be displayed.
  String add(String chunk) {
    if (chunk.isEmpty) return '';
    _held.write(chunk);
    return _drain();
  }

  /// Returns any text still buffered when the stream ends, which is always
  /// empty: whatever is left over is an unfinished tag or an unclosed block.
  String flush() {
    _held.clear();
    _inside = false;
    return '';
  }

  String _drain() {
    final out = StringBuffer();
    while (true) {
      final text = _held.toString();
      if (text.isEmpty) break;
      final match = _anyTag.firstMatch(text);
      if (match == null) {
        // Inside a dropped block nothing may be shown, and the tail has to be
        // retained whatever it looks like, so that a closing tag split across
        // chunks is still recognised. Outside one only a fragment that could
        // still grow into a tag is held back.
        final hold = _inside
            ? (_holdLength < text.length ? _holdLength : text.length)
            : _partialTagLength(text);
        if (!_inside) out.write(text.substring(0, text.length - hold));
        _held
          ..clear()
          ..write(text.substring(text.length - hold));
        break;
      }
      final tag = match.group(0)!;
      final isClosing = tag.startsWith('</');
      _held
        ..clear()
        ..write(text.substring(match.end));
      if (_inside) {
        // Everything up to the end of this tag belongs to the dropped block.
        if (isClosing) _inside = false;
        continue;
      }
      out.write(text.substring(0, match.start));
      if (!isClosing) _inside = true;
    }
    return out.toString();
  }

  /// Length of the longest suffix of [text] that is a prefix of one of the
  /// tags, so it must be held back rather than shown.
  static int _partialTagLength(String text) {
    final limit = text.length < _holdLength ? text.length : _holdLength;
    for (var length = limit; length > 0; length--) {
      final suffix = text.substring(text.length - length).toLowerCase();
      for (final name in _names) {
        if ('<$name>'.startsWith(suffix) || '</$name>'.startsWith(suffix)) {
          return length;
        }
      }
    }
    return 0;
  }
}
