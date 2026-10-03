import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/voice/tts/supertonic_text.dart';

/// One file of a voice: where it comes from and what it must be.
@immutable
class TtsFile {
  const TtsFile({
    required this.path,
    required this.bytes,
    required this.sha256Digest,
  });

  /// Where it lives in the voice's folder, and in the model's repository.
  final String path;
  final int bytes;
  final String sha256Digest;

  String url(String repository) =>
      'https://huggingface.co/$repository/resolve/main/$path';
}

/// An on-device text-to-speech voice: the Supertonic 3 model and a few of its
/// speaking styles.
///
/// One model speaks 31 languages, which is why there is one entry and not one
/// per language. The weights are under the BigScience OpenRAIL-M licence and the
/// sample code under MIT; neither is copyleft, and the model reads characters
/// directly, so it needs no phonemizer. (The Piper voices this replaced needed
/// espeak-ng, which is GPL-3.0.) The licence text and its use restrictions are
/// shown in the app's licence screen and in THIRD_PARTY_NOTICES.md.
///
/// Sizes and SHA-256 are those the repository publishes (the digest of a
/// large file is its LFS object id); a download is refused if they differ.
@immutable
class TtsVoice {
  const TtsVoice({
    required this.id,
    required this.repository,
    required this.files,
  });

  final String id;

  /// Hugging Face repository, `owner/name`.
  final String repository;
  final List<TtsFile> files;

  int get bytes => files.fold(0, (sum, file) => sum + file.bytes);

  /// The folder, inside the voice's, that holds the `.onnx` files.
  static const modelFolder = 'onnx';
}

/// The speaking styles offered, in the order shown. `F` voices are female, `M`
/// male; each is a small JSON file next to the model.
const ttsStyles = ['F2', 'F1', 'M1', 'M2'];

const defaultTtsStyle = 'F2';

const supertonicVoice = TtsVoice(
  id: 'supertonic-3',
  repository: 'supertone-oss-archive/supertonic-3',
  files: [
    TtsFile(
      path: 'onnx/duration_predictor.onnx',
      bytes: 3700147,
      sha256Digest:
          'c3eb91414d5ff8a7a239b7fe9e34e7e2bf8a8140d8375ffb14718b1c639325db',
    ),
    TtsFile(
      path: 'onnx/text_encoder.onnx',
      bytes: 36416150,
      sha256Digest:
          'c7befd5ea8c3119769e8a6c1486c4edc6a3bc8365c67621c881bbb774b9902ff',
    ),
    TtsFile(
      path: 'onnx/vector_estimator.onnx',
      bytes: 256534781,
      sha256Digest:
          '883ac868ea0275ef0e991524dc64f16b3c0376efd7c320af6b53f5b780d7c61c',
    ),
    TtsFile(
      path: 'onnx/vocoder.onnx',
      bytes: 101424195,
      sha256Digest:
          '085de76dd8e8d5836d6ca66826601f615939218f90e519f70ee8a36ed2a4c4ba',
    ),
    TtsFile(
      path: 'onnx/tts.json',
      bytes: 8253,
      sha256Digest:
          '42078d3aef1cd43ab43021f3c54f47d2d75ceb4e75f627f118890128b06a0d09',
    ),
    TtsFile(
      path: 'onnx/unicode_indexer.json',
      bytes: 277676,
      sha256Digest:
          '9bf7346e43883a81f8645c81224f786d43c5b57f3641f6e7671a7d6c493cb24f',
    ),
    TtsFile(
      path: 'voice_styles/F1.json',
      bytes: 292046,
      sha256Digest:
          'bbdec6ee00231c2c742ad05483df5334cab3b52fda3ba38e6a07059c4563dbc2',
    ),
    TtsFile(
      path: 'voice_styles/F2.json',
      bytes: 292423,
      sha256Digest:
          '7c722c6a72707b1a77f035d67f0d1351ba187738e06f7683e8c72b1df3477fc6',
    ),
    TtsFile(
      path: 'voice_styles/M1.json',
      bytes: 291748,
      sha256Digest:
          'e35604687f5d23694b8e91593a93eec0e4eca6c0b02bb8ed69139ab2ea6b0a5b',
    ),
    TtsFile(
      path: 'voice_styles/M2.json',
      bytes: 292055,
      sha256Digest:
          'b76cbf62bac707c710cf0ae5aba5e31eea1a6339a9734bfae33ab98499534a50',
    ),
  ],
);

const ttsVoices = <TtsVoice>[supertonicVoice];

TtsVoice get defaultTtsVoice => supertonicVoice;

/// Every language the voice speaks is read, so none is left silent.
const ttsNonLatinLanguages = <String>{};

/// The voice for [language] (`en`, `de`, `pt-BR` and `<|ru|>` all work), or
/// null when it cannot speak it.
TtsVoice? ttsVoiceFor(String? language) {
  final code = normalizeLanguage(language);
  if (code == null || !SupertonicText.languages.contains(code)) return null;
  return supertonicVoice;
}

/// `<|en|>`, `en_US`, `EN` -> `en`; empty or unknown shapes -> null.
String? normalizeLanguage(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'[A-Za-z]{2,3}').firstMatch(raw);
  if (match == null) return null;
  return match.group(0)!.toLowerCase();
}

/// What a first-run or upgrading user is offered up front.
List<TtsVoice> ttsVoicesForSetup(String? deviceLanguage) => const [
      supertonicVoice,
    ];
