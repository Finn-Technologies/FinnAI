/// Notices a reply that has started repeating itself.
///
/// A small model sometimes falls into a loop: the same line, verse or
/// sentence over and over until the token budget runs out (the eval saw a
/// haiku reach 1536 tokens and a one-line translation 672). Fed the reply as
/// it streams, [add] answers true once the end of the text is the same block
/// repeated back to back: three times for a short block, twice for one of
/// [longBlock] characters or more, where a verbatim repeat is never meant.
/// Text that varies (numbered steps, a list) never trips it.
class LoopGuard {
  LoopGuard({
    this.minBlock = 8,
    this.longBlock = 40,
    this.maxBlock = 240,
    this.minSpan = 60,
  });

  /// Shortest block that counts as a repeat, in characters.
  final int minBlock;

  /// From this length, two copies in a row are already a loop.
  final int longBlock;

  /// Longest block looked for.
  final int maxBlock;

  /// Repeats shorter than this in total never count ("ha ha ha").
  final int minSpan;

  final StringBuffer _text = StringBuffer();

  /// The length of the repeating block once tripped; 0 before.
  int period = 0;

  bool get tripped => period > 0;

  /// Adds the next piece of the reply; true once it is looping.
  bool add(String piece) {
    if (tripped) return true;
    _text.write(piece);
    // Checked on every piece: a few thousand character comparisons per
    // token, nothing next to decoding it.
    final text = _text.toString();
    final tail = text.length > 3 * maxBlock
        ? text.substring(text.length - 3 * maxBlock)
        : text;
    final found = repeatingBlock(tail);
    if (found > 0) period = found;
    return tripped;
  }

  /// The length of the block [text] ends by repeating, or 0.
  int repeatingBlock(String text) {
    final n = text.length;
    for (var p = minBlock; p <= maxBlock && 2 * p <= n; p++) {
      final copies = p >= longBlock ? 2 : 3;
      if (copies * p > n || copies * p < minSpan) continue;
      final block = text.substring(n - p);
      if (block.trim().isEmpty) continue;
      var ok = true;
      for (var k = 2; k <= copies && ok; k++) {
        ok = text.substring(n - k * p, n - (k - 1) * p) == block;
      }
      if (ok) return p;
    }
    return 0;
  }
}
