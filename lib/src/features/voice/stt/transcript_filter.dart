/// Cleans a raw Whisper transcript.
///
/// Whisper does not return "nothing" for a stretch of noise: it returns
/// something plausible. The voice activity detector keeps most silence away
/// from it, and this removes what still gets through — the bracketed
/// non-speech tags it was trained to emit — so a cough does not become a
/// question sent to the model.
String cleanTranscript(String raw) {
  var text = raw.replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*\)|\*[^*]*\*'), ' ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Nothing left but punctuation or symbols is not speech.
  if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(text)) return '';
  return text;
}
