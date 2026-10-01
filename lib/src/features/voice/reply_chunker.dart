import 'package:finn_ai/src/features/voice/speakable_text.dart';

/// Cuts a streaming reply into pieces worth speaking.
///
/// A piece ends at a sentence boundary. The first piece of a reply may also
/// end at a clause (a comma after a few words), because the time to first
/// audio is what makes a voice feel live, and a model's first sentence is
/// often the longest wait in the whole turn.
class ReplyChunker {
  /// The first piece may end at a comma only once it is this long, so a short
  /// lead-in ("Well,") is not spoken on its own.
  static const int earlyClauseMinChars = 40;

  /// A first sentence with no comma in it is cut at a word after this many
  /// characters, rather than making the listener wait for all of it. A small
  /// model's first sentence is often fifty tokens, which is five seconds.
  static const int earlyWordCutChars = 70;

  /// A spoken reply is stopped once this many sentences are complete. The model
  /// is asked for two and does not always oblige; three is what a person will
  /// sit and listen to, and what bounds the wait for the end of it.
  static const int spokenReplyMaxSentences = 3;

  /// How many sentences of [text] are complete (ended and followed by a space,
  /// a newline or the end of what has been written so far).
  static int sentenceCount(String text) {
    var count = 0;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char != '.' && char != '!' && char != '?') continue;
      final atEnd = i + 1 == text.length;
      final next = atEnd ? ' ' : text[i + 1];
      // Only the last mark of a run like "?!" is followed by a space, so a run
      // is one ending.
      if (next == ' ' || next == '\n' || atEnd) count++;
    }
    return count;
  }

  String _spokenUpTo = '';

  bool get spokenAnything => _spokenUpTo.isNotEmpty;

  void reset() => _spokenUpTo = '';

  /// The next piece of [fullText] that can be spoken, or null if the reply has
  /// not got far enough.
  String? next(String fullText) {
    if (fullText.length <= _spokenUpTo.length) return null;
    final fresh = fullText.substring(_spokenUpTo.length);
    final boundary = _boundary(fresh, early: _spokenUpTo.isEmpty);
    if (boundary == null) return null;
    // Sanitize *before* deciding there is nothing to say, so a chunk that is
    // only markup is dropped rather than read aloud character by character.
    // A fence is not a sentence boundary, so a code block used to accumulate
    // until the whole reply had finished and then be spoken in one go.
    final chunk = SpeakableText.flatten(fresh.substring(0, boundary));
    _spokenUpTo += fresh.substring(0, boundary);
    if (chunk.isEmpty) return null;
    return chunk;
  }

  /// What is left to say once the reply has finished.
  String remainder(String fullText) {
    if (fullText.length <= _spokenUpTo.length) return '';
    // The tail of a streaming reply can be half a word, or a dangling tag from
    // the chat template. Speaking that is worse than not speaking it.
    final tail = fullText.substring(_spokenUpTo.length);
    final cleaned = SpeakableText.flatten(tail);
    if (cleaned.isEmpty) return '';
    return SpeakableText.stripTrailingFragment(cleaned) ?? '';
  }

  int? _boundary(String text, {required bool early}) {
    int? boundary;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '.' || char == '!' || char == '?' || char == '\n') {
        final atEnd = i + 1 == text.length;
        final next = atEnd ? ' ' : text[i + 1];
        if (next == ' ' || next == '\n' || atEnd) boundary = i + 1;
      }
    }
    if (boundary != null || !early) return boundary;
    for (var i = earlyClauseMinChars - 1; i < text.length - 1; i++) {
      final char = text[i];
      if ((char == ',' || char == ';' || char == ':') && text[i + 1] == ' ') {
        return i + 1;
      }
    }
    if (text.length > earlyWordCutChars) {
      // The last word of a streaming reply may be half written, so the cut is
      // at the last space, never at the end.
      final space = text.lastIndexOf(' ');
      if (space >= earlyWordCutChars) return space + 1;
    }
    return null;
  }
}
