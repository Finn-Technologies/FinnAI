/// Search/replace edits, the format most cloud coding models already know:
///
///     <<<<<<< SEARCH
///     old lines
///     =======
///     new lines
///     >>>>>>> REPLACE
///
/// A whole-file rewrite costs a model the entire file in output tokens and
/// runs out on anything long; an edit names only what changes.
abstract final class EditBlocks {
  static final RegExp _search = RegExp(r'^\s*<{5,}\s*SEARCH\s*$');
  static final RegExp _divider = RegExp(r'^\s*={5,}\s*$');
  static final RegExp _replace = RegExp(r'^\s*>{5,}\s*REPLACE\s*$');

  /// The (search, replace) pairs in [text], or null when it holds none or a
  /// block is unfinished.
  static List<(String, String)>? parse(String text) {
    final pairs = <(String, String)>[];
    final lines = text.split('\n');
    var i = 0;
    while (i < lines.length) {
      if (!_search.hasMatch(lines[i])) {
        i++;
        continue;
      }
      final search = <String>[];
      final replace = <String>[];
      var j = i + 1;
      while (j < lines.length && !_divider.hasMatch(lines[j])) {
        search.add(lines[j++]);
      }
      if (j >= lines.length) return null;
      j++;
      while (j < lines.length && !_replace.hasMatch(lines[j])) {
        replace.add(lines[j++]);
      }
      if (j >= lines.length) return null;
      pairs.add((search.join('\n'), replace.join('\n')));
      i = j + 1;
    }
    return pairs.isEmpty ? null : pairs;
  }

  /// [original] with every pair applied in order. Throws [EditMismatch] when
  /// a search text is not in the file: guessing where it was meant to go
  /// would edit the wrong place.
  static String apply(String original, List<(String, String)> pairs) {
    var text = original;
    for (final (search, replace) in pairs) {
      if (search.isEmpty) {
        // An empty search appends, the usual way to add to a file's end.
        text = text.isEmpty || text.endsWith('\n')
            ? '$text$replace\n'
            : '$text\n$replace\n';
        continue;
      }
      var at = text.indexOf(search);
      var found = search;
      if (at < 0) {
        // Models often get trailing spaces wrong; compare without them.
        final loose = _trimLineEnds(search);
        final looseText = _trimLineEnds(text);
        final looseAt = looseText.indexOf(loose);
        if (looseAt < 0) throw EditMismatch(search);
        text = looseText;
        at = looseAt;
        found = loose;
      }
      text = text.replaceRange(at, at + found.length, replace);
    }
    return text;
  }

  static String _trimLineEnds(String text) =>
      text.split('\n').map((line) => line.trimRight()).join('\n');
}

/// A search text that is not in the file.
class EditMismatch implements Exception {
  const EditMismatch(this.search);

  final String search;

  /// The first line of the missing text, for the model and the card.
  String get firstLine => search.split('\n').first.trim();

  @override
  String toString() => 'The SEARCH text was not found: "$firstLine"';
}
