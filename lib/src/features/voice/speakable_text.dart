/// Turns a model's Markdown answer into something worth listening to.
///
/// The controller used to hand the raw response to the TTS engine. That means
/// a fenced code block was read aloud character by character — "backtick
/// d-a-r-t backtick" — and a bullet list was read as "dash one, dash two".
/// On a phone, at 0.45 rate, in public, that is the difference between the
/// feature being usable and being embarrassing.
///
/// Every rule here is about *removing* something. The alternative, rewriting,
/// is how a spoken answer starts disagreeing with the written one; the reader
/// is looking at the same text the model produced.
library;

import 'package:flutter/foundation.dart';

/// What one piece of a spoken answer is.
enum SpeakSegmentKind {
  /// Ordinary prose. Spoken as written.
  prose,

  /// A fenced or indented code block. Replaced by a short spoken marker.
  code,

  /// A line of inline code. Spoken without its backticks.
  inlineCode,

  /// A heading. The hashes are dropped; the words are kept.
  heading,

  /// A bullet or numbered list item. The marker is dropped.
  listItem,

  /// A table row. Tables are read as their cell contents, without the pipes.
  tableRow,
}

@immutable
class SpeakSegment {
  const SpeakSegment(this.kind, this.text);

  final SpeakSegmentKind kind;
  final String text;

  /// Whether this segment has anything to say.
  ///
  /// A code block whose body is empty is silence, not a marker.
  bool get isEmpty => text.trim().isEmpty;
}

/// Marker spoken in place of a code block.
///
/// Short, and it says what happened rather than apologising for it. "Skipping
/// code" every time is worse than useless; the user is told there *is* code
/// and can ask for it to be read.
const String codeBlockMarker = 'Code block skipped.';

/// Marker for a table, which reads badly aloud in any form.
const String tableMarker = 'Table skipped.';

/// Splits Markdown into speakable segments.
///
/// Pure and synchronous, so the whole rule set is testable without a TTS
/// engine — which matters, because "does this read well aloud" is exactly the
/// kind of judgement that a passing test should pin down rather than leave to
/// whoever happens to try it on a train.
class SpeakableText {
  const SpeakableText._();

  static final RegExp _fence = RegExp(r'^\s*(?:```|~~~)');
  static final RegExp _heading = RegExp(r'^\s*#{1,6}\s+');
  static final RegExp _quote = RegExp(r'^\s*>\s?');
  static final RegExp _bullet = RegExp(r'^\s*[-*+]\s+');
  static final RegExp _numbered = RegExp(r'^\s*(\d+)[.)]\s+');
  static final RegExp _tableRow = RegExp(r'^\s*\|.*\|\s*$');
  static final RegExp _tableDivider = RegExp(r'^\s*\|[\s:|-]+\|\s*$');
  static final RegExp _inlineCode = RegExp(r'`([^`\n]+)`');
  static final RegExp _bold = RegExp(r'\*\*([^*]+)\*\*');
  static final RegExp _italicOrStrike =
      RegExp(r'(?<![\w*])[*_]([^*_\n]+)[*_](?![\w*])');
  static final RegExp _link = RegExp(r'\[([^\]]+)\]\((?:[^)]*)\)');
  static final RegExp _image = RegExp(r'!\[([^\]]*)\]\((?:[^)]*)\)');
  static final RegExp _htmlTag = RegExp(r'</?[A-Za-z][^>\n]*>');
  static final RegExp _url = RegExp(r'https?://\S+');
  static final RegExp _leadingPunctuation = RegExp(r'^[¿¡«»“”‘’\s.!?,:;()\-]+');
  static final RegExp _collapsedSpace = RegExp(r'[ \t]{2,}');

  /// The segments of [source], in order.
  ///
  /// An unterminated code fence still closes at the end of the input: a reply
  /// cut off mid-block is exactly the case where reading "code block
  /// skipped" matters, since the alternative is reading the half-block.
  static List<SpeakSegment> segment(String source) {
    final segments = <SpeakSegment>[];
    final lines = source.split('\n');

    var inCode = false;
    var codeBody = StringBuffer();
    var inTable = false;

    void closeCode() {
      final body = codeBody.toString().trim();
      codeBody = StringBuffer();
      inCode = false;
      if (body.isNotEmpty) {
        segments.add(SpeakSegment(SpeakSegmentKind.code, codeBlockMarker));
      }
    }

    for (final line in lines) {
      if (inCode) {
        if (_fence.hasMatch(line)) {
          closeCode();
        } else {
          codeBody.writeln(line);
        }
        continue;
      }
      if (_fence.hasMatch(line)) {
        inCode = true;
        continue;
      }

      // A table is a run of pipe-delimited rows; read past it rather than
      // reciting cell by cell, which produces "pipe Name pipe pipe Age pipe".
      if (_tableRow.hasMatch(line)) {
        if (_tableDivider.hasMatch(line)) continue;
        inTable = true;
        continue;
      }
      if (inTable) {
        if (_tableRow.hasMatch(line)) {
          if (!_tableDivider.hasMatch(line)) continue;
          continue;
        }
        inTable = false;
        segments.add(SpeakSegment(SpeakSegmentKind.tableRow, tableMarker));
      }

      if (line.trim().isEmpty) {
        // A blank line is a pause between sentences, not a spoken gap.
        segments.add(const SpeakSegment(SpeakSegmentKind.prose, ' '));
        continue;
      }

      var kind = SpeakSegmentKind.prose;
      var text = line;
      if (_heading.hasMatch(text)) {
        kind = SpeakSegmentKind.heading;
        text = text.replaceFirst(_heading, '');
      } else if (_quote.hasMatch(text)) {
        // A blockquote's "greater than" is read as "greater than", which turns
        // a note into a maths comparison. The sentence end is not cosmetic: a
        // quote on its own line follows whatever came before, and without one
        // the two run together into one sentence.
        kind = SpeakSegmentKind.prose;
        final quoted = text.replaceFirst(_quote, '').trimRight();
        text = RegExp(r'[.!?]$').hasMatch(quoted) ? quoted : '$quoted.';
      } else if (_bullet.hasMatch(text)) {
        kind = SpeakSegmentKind.listItem;
        text = text.replaceFirst(_bullet, '');
      } else if (_numbered.hasMatch(text)) {
        kind = SpeakSegmentKind.listItem;
        // Only the delimiter goes, not the digit: "2. turn it off" is a
        // sequence the listener needs, and "turn it off" is not.
        // `replaceFirstMapped` rather than `replaceFirst(r'$1. ')`, because a
        // replacement string in Dart is not a group reference.
        final number = _numbered.firstMatch(text)?.group(1) ?? '';
        text = text.replaceFirst(_numbered, '$number. ');
      }

      final cleaned = _inline(text);
      if (cleaned.trim().isNotEmpty) {
        segments.add(SpeakSegment(kind, cleaned));
      }
    }

    if (inCode) closeCode();
    return segments;
  }

  /// The whole answer as one speakable string.
  ///
  /// Paragraphs are separated by a blank line so the TTS engine takes its
  /// natural pause there instead of the text running together.
  static String flatten(String source) {
    final buffer = StringBuffer();
    for (final segment in segment(source)) {
      if (segment.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(segment.text.trim());
    }
    return buffer.toString().replaceAll(_collapsedSpace, ' ').trim();
  }

  /// Strips inline markup from a single line of prose.
  ///
  /// Uses `replaceAllMapped` with an explicit group read rather than
  /// `replaceAll(r'$1')`: a raw-string replacement in `replaceAll` is taken
  /// literally, so the `$1` version spoke the dollar sign and the one out loud
  /// instead of the link's label.
  ///
  /// The order matters: images before links (so `![alt](url)` loses its
  /// parentheses rather than reading the alt text as a link), code spans
  /// before emphasis (so `` `*x*` `` stays literal), and URLs last.
  static String _inline(String value) {
    var text = value
        .replaceAll(_image, ' ')
        .replaceAllMapped(_link, (match) => match.group(1) ?? '')
        .replaceAllMapped(_inlineCode, (match) => match.group(1) ?? '')
        .replaceAllMapped(_bold, (match) => match.group(1) ?? '')
        .replaceAllMapped(_italicOrStrike, (match) => match.group(1) ?? '')
        .replaceAll(_htmlTag, ' ')
        .replaceAll(_url, ' ')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
    text = text.replaceFirst(_leadingPunctuation, '');
    return text;
  }

  /// A trailing fragment a TTS engine would spell out.
  ///
  /// A reply cut off mid-token can end in `<|im_`, `<|im_end` or a dangling
  /// HTML tag. Those are the model's plumbing, not its answer, and a TTS
  /// engine reads "less-than, pipe, i, m, underscore" aloud with total
  /// sincerity.
  static String? stripTrailingFragment(String text) {
    var trimmed = text.trimRight();
    if (trimmed.isEmpty) return null;
    // Cut back to the last position that is certainly real prose, rather than
    // rejecting the whole tail: the sentence before the fragment is still worth
    // speaking.
    final dangling = RegExp(r'<[|/!]?[A-Za-z_|>]*$').firstMatch(trimmed);
    if (dangling != null) {
      trimmed = trimmed.substring(0, dangling.start).trimRight();
    }
    return trimmed.isEmpty ? null : trimmed;
  }
}
