import 'package:flutter/foundation.dart';

/// One on-device text-to-speech voice: a Piper VITS model, int8-quantised
/// (~21 MB), run by sherpa-onnx.
///
/// Only voices whose training data is under a licence that allows shipping them
/// in an app are listed: public domain (English LJ Speech), CC0 (German,
/// Spanish, Italian, Russian) and CC BY 4.0 (French Siwis, credited in
/// THIRD_PARTY_NOTICES). Voices under non-commercial, research-only or
/// unspecified licences are deliberately absent, which is why there is no
/// Hindi voice yet.
///
/// Size and SHA-256 are the ones GitHub publishes for the sherpa-onnx
/// `tts-models` release asset; the download is refused if they do not match.
@immutable
class TtsVoice {
  const TtsVoice({
    required this.language,
    required this.id,
    required this.bytes,
    required this.sha256Digest,
  });

  /// ISO 639-1 code the voice speaks, e.g. `en`.
  final String language;

  /// The sherpa-onnx archive name without `.tar.bz2`.
  final String id;
  final int bytes;
  final String sha256Digest;

  String get url =>
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/'
      '$id.tar.bz2';
}

/// The first entry is the default: it speaks a Latin-script reply when no voice
/// matches its language.
const ttsVoices = <TtsVoice>[
  TtsVoice(
    language: 'en',
    id: 'vits-piper-en_US-ljspeech-medium-int8',
    bytes: 21090429,
    sha256Digest:
        '24dc3bd77dd48c291e52c297878d3437c9492f245d823d7f6a06c4bbb67f4b6b',
  ),
  TtsVoice(
    language: 'de',
    id: 'vits-piper-de_DE-thorsten-medium-int8',
    bytes: 20949833,
    sha256Digest:
        '07e240b7b9c1fc9211d5a69512f8cbe11b3286c2ed79c15c076ac6ed427fdf13',
  ),
  TtsVoice(
    language: 'es',
    id: 'vits-piper-es_ES-davefx-medium-int8',
    bytes: 21171632,
    sha256Digest:
        '8bb8ac1cefb727caec9bd9c6c3185c673c8b42c53bd29bb25d5a7715dac37125',
  ),
  TtsVoice(
    language: 'fr',
    id: 'vits-piper-fr_FR-siwis-medium-int8',
    bytes: 20914888,
    sha256Digest:
        '3909cff9b3cfd4820c66aa13bf554315c82e34899c161f0b446ece372bc4b5ec',
  ),
  TtsVoice(
    language: 'it',
    id: 'vits-piper-it_IT-paola-medium-int8',
    bytes: 21143212,
    sha256Digest:
        '2b975ed305391c056944a4dde67ee754dd824099503a860295bb4c1d724662d8',
  ),
  TtsVoice(
    language: 'ru',
    id: 'vits-piper-ru_RU-denis-medium-int8',
    bytes: 21058905,
    sha256Digest:
        'd710e29eb7854c42461d16d65d3cef753cc559639ca75806edc75ba71f23af66',
  ),
];

TtsVoice get defaultTtsVoice => ttsVoices.first;

/// Languages written in a script the default (English) voice cannot read. With
/// no voice of their own they are not spoken at all, rather than spoken wrong.
const ttsNonLatinLanguages = {'ru', 'hi'};

/// The voice for [language] (`en`, `de`, `pt-BR` and `<|ru|>` all work), or
/// null when there is none.
TtsVoice? ttsVoiceFor(String? language) {
  final code = normalizeLanguage(language);
  if (code == null) return null;
  for (final voice in ttsVoices) {
    if (voice.language == code) return voice;
  }
  return null;
}

/// `<|en|>`, `en_US`, `EN` -> `en`; empty or unknown shapes -> null.
String? normalizeLanguage(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'[A-Za-z]{2,3}').firstMatch(raw);
  if (match == null) return null;
  return match.group(0)!.toLowerCase();
}

/// The voices a first-run or upgrading user gets up front: English, and the
/// voice for the phone's language when there is one.
List<TtsVoice> ttsVoicesForSetup(String? deviceLanguage) {
  final local = ttsVoiceFor(deviceLanguage);
  return [
    defaultTtsVoice,
    if (local != null && local != defaultTtsVoice) local,
  ];
}
