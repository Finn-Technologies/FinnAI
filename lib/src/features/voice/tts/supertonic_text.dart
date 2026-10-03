import 'package:finn_ai/src/features/voice/tts/supertonic_nfkd.dart';

/// Turns text into what the Supertonic voice model reads: cleaned text wrapped
/// in a language tag, split into pieces it can speak in one go, as a list of
/// character ids.
///
/// A port of the reference implementation's text handling (`UnicodeProcessor`
/// and `chunk_text`, MIT licence). The model has no phonemizer: it reads
/// characters, which is why it needs no GPL speech-synthesis library.
abstract final class SupertonicText {
  /// Languages the model can speak. `na` reads text without knowing its
  /// language.
  static const languages = {
    'ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'hi', //
    'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'nl', 'pl', 'pt', 'ro',
    'ru', 'sk', 'sl', 'sv', 'tr', 'uk', 'vi', 'na',
  };

  /// Longest piece spoken in one go, by language (Korean and Japanese carry more
  /// per character).
  static int maxChunk(String language) =>
      language == 'ko' || language == 'ja' ? 120 : 300;

  static final _emoji = RegExp(
    '[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}'
    '\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}'
    '\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}'
    '☀-⛿✀-➿\u{1F1E6}-\u{1F1FF}]+',
    unicode: true,
  );

  static const _replacements = {
    '–': '-', '‑': '-', '—': '-', '_': ' ', //
    '“': '"', '”': '"', '‘': "'", '’': "'",
    '´': "'", '`': "'", '[': ' ', ']': ' ', '|': ' ', '/': ' ', '#': ' ',
    '→': ' ', '←': ' ',
  };

  static const _expressions = {
    '@': ' at ',
    'e.g.,': 'for example, ',
    'i.e.,': 'that is, ',
  };

  static final _special = RegExp(r'[♥☆♡©\\]');
  static final _ending = RegExp(r'''[.!?;:,'")\]}…。」』】〉》›»]$''');

  /// Decomposes accented letters and Hangul the way Unicode NFKD does.
  static String decompose(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      final mapped = supertonicNfkd[rune];
      if (mapped != null) {
        out.write(mapped);
      } else if (rune >= 0xAC00 && rune <= 0xD7A3) {
        // A Hangul syllable is a lead, a vowel and maybe a tail consonant.
        final index = rune - 0xAC00;
        out.writeCharCode(0x1100 + index ~/ 588);
        out.writeCharCode(0x1161 + (index % 588) ~/ 28);
        final tail = index % 28;
        if (tail != 0) out.writeCharCode(0x11A7 + tail);
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  /// The text as the model wants it, wrapped in `<lang>…</lang>`.
  static String preprocess(String text, String language) {
    var value = decompose(text).replaceAll(_emoji, '');
    _replacements.forEach((from, to) => value = value.replaceAll(from, to));
    value = value.replaceAll(_special, '');
    _expressions.forEach((from, to) => value = value.replaceAll(from, to));
    for (final mark in const [',', '.', '!', '?', ';', ':', "'"]) {
      value = value.replaceAll(' $mark', mark);
    }
    for (final quote in const ['"', "'", '`']) {
      while (value.contains('$quote$quote')) {
        value = value.replaceAll('$quote$quote', quote);
      }
    }
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (value.isNotEmpty && !_ending.hasMatch(value)) value += '.';
    final tag = languages.contains(language) ? language : 'na';
    return '<$tag>$value</$tag>';
  }

  /// Character ids for [preprocessed] text. A character the model does not know
  /// is left out rather than sent as garbage.
  static List<int> ids(String preprocessed, List<int> indexer) => [
        for (final rune in preprocessed.runes)
          if (rune < indexer.length && indexer[rune] >= 0) indexer[rune],
      ];

  static final _sentenceEnd = RegExp(
    r'(?<!Mr\.)(?<!Mrs\.)(?<!Ms\.)(?<!Dr\.)(?<!Prof\.)(?<!Sr\.)(?<!Jr\.)'
    r'(?<!Ph\.D\.)(?<!etc\.)(?<!e\.g\.)(?<!i\.e\.)(?<!vs\.)(?<!Inc\.)'
    r'(?<!Ltd\.)(?<!Co\.)(?<!Corp\.)(?<!St\.)(?<!Ave\.)(?<!Blvd\.)'
    r'(?<!\b[A-Z]\.)(?<=[.!?])\s+',
  );

  /// Splits [text] into pieces of at most [maxLength] characters, at paragraph
  /// and sentence boundaries.
  static List<String> chunk(String text, {int maxLength = 300}) {
    final chunks = <String>[];
    for (final raw in text.trim().split(RegExp(r'\n\s*\n+'))) {
      final paragraph = raw.trim();
      if (paragraph.isEmpty) continue;
      var current = '';
      for (final sentence in paragraph.split(_sentenceEnd)) {
        if (current.length + sentence.length + 1 <= maxLength) {
          current += (current.isEmpty ? '' : ' ') + sentence;
        } else {
          if (current.isNotEmpty) chunks.add(current.trim());
          current = sentence;
        }
      }
      if (current.isNotEmpty) chunks.add(current.trim());
    }
    return chunks;
  }
}
