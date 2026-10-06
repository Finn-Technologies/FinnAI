import 'package:flutter/foundation.dart';

enum DiffOp { same, added, removed }

/// One line of a diff, with its numbers in the old and the new file.
@immutable
class DiffLine {
  const DiffLine(this.op, this.text, {this.oldLine, this.newLine});

  final DiffOp op;
  final String text;
  final int? oldLine;
  final int? newLine;
}

/// A run of unchanged lines folded away between two changes.
@immutable
class DiffGap {
  const DiffGap(this.lines);

  final int lines;
}

/// A line diff of two texts, for showing what a write or an edit changed.
abstract final class LineDiff {
  /// Above this many cells the exact diff is not worth its time on a phone;
  /// the change is shown as everything removed and everything added.
  static const int _maxCells = 250000;

  static List<DiffLine> diff(String? before, String after) {
    final b = _lines(after);
    if (before == null) {
      return [
        for (var i = 0; i < b.length; i++)
          DiffLine(DiffOp.added, b[i], newLine: i + 1),
      ];
    }
    final a = _lines(before);
    // Common head and tail first: an edit usually touches a few lines in
    // the middle, and this keeps the table small.
    var head = 0;
    while (head < a.length && head < b.length && a[head] == b[head]) {
      head++;
    }
    var tail = 0;
    while (tail < a.length - head &&
        tail < b.length - head &&
        a[a.length - 1 - tail] == b[b.length - 1 - tail]) {
      tail++;
    }
    final midA = a.sublist(head, a.length - tail);
    final midB = b.sublist(head, b.length - tail);

    final out = <DiffLine>[
      for (var i = 0; i < head; i++)
        DiffLine(DiffOp.same, a[i], oldLine: i + 1, newLine: i + 1),
    ];
    if (midA.length * midB.length > _maxCells) {
      for (var i = 0; i < midA.length; i++) {
        out.add(DiffLine(DiffOp.removed, midA[i], oldLine: head + i + 1));
      }
      for (var i = 0; i < midB.length; i++) {
        out.add(DiffLine(DiffOp.added, midB[i], newLine: head + i + 1));
      }
    } else {
      out.addAll(_lcs(midA, midB, head));
    }
    for (var i = 0; i < tail; i++) {
      final oldIndex = a.length - tail + i;
      final newIndex = b.length - tail + i;
      out.add(DiffLine(DiffOp.same, a[oldIndex],
          oldLine: oldIndex + 1, newLine: newIndex + 1));
    }
    return out;
  }

  /// Added and removed line counts.
  static (int, int) stats(List<DiffLine> lines) {
    var added = 0;
    var removed = 0;
    for (final line in lines) {
      if (line.op == DiffOp.added) added++;
      if (line.op == DiffOp.removed) removed++;
    }
    return (added, removed);
  }

  /// [lines] with unchanged runs longer than 2×[context] folded to a gap,
  /// keeping [context] lines around each change.
  static List<Object> hunks(List<DiffLine> lines, {int context = 2}) {
    final keep = List<bool>.filled(lines.length, false);
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].op == DiffOp.same) continue;
      for (var j = i - context; j <= i + context; j++) {
        if (j >= 0 && j < lines.length) keep[j] = true;
      }
    }
    final out = <Object>[];
    var folded = 0;
    for (var i = 0; i < lines.length; i++) {
      if (keep[i]) {
        if (folded > 0) out.add(DiffGap(folded));
        folded = 0;
        out.add(lines[i]);
      } else {
        folded++;
      }
    }
    if (folded > 0) out.add(DiffGap(folded));
    return out;
  }

  static List<String> _lines(String text) {
    if (text.isEmpty) return const [];
    final lines = text.split('\n');
    // A trailing newline ends the last line; it is not one more line.
    if (lines.last.isEmpty) lines.removeLast();
    return lines;
  }

  static List<DiffLine> _lcs(List<String> a, List<String> b, int offset) {
    final n = a.length;
    final m = b.length;
    // lengths[i][j]: longest common subsequence of a[i..] and b[j..].
    final lengths = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        lengths[i][j] = a[i] == b[j]
            ? lengths[i + 1][j + 1] + 1
            : (lengths[i + 1][j] >= lengths[i][j + 1]
                ? lengths[i + 1][j]
                : lengths[i][j + 1]);
      }
    }
    final out = <DiffLine>[];
    var i = 0;
    var j = 0;
    while (i < n && j < m) {
      if (a[i] == b[j]) {
        out.add(DiffLine(DiffOp.same, a[i],
            oldLine: offset + i + 1, newLine: offset + j + 1));
        i++;
        j++;
      } else if (lengths[i + 1][j] >= lengths[i][j + 1]) {
        out.add(DiffLine(DiffOp.removed, a[i], oldLine: offset + i + 1));
        i++;
      } else {
        out.add(DiffLine(DiffOp.added, b[j], newLine: offset + j + 1));
        j++;
      }
    }
    for (; i < n; i++) {
      out.add(DiffLine(DiffOp.removed, a[i], oldLine: offset + i + 1));
    }
    for (; j < m; j++) {
      out.add(DiffLine(DiffOp.added, b[j], newLine: offset + j + 1));
    }
    return out;
  }
}
