import 'package:flutter/foundation.dart';

/// The app deliberately exposes one model choice: a mobile-friendly Qwen
/// 3.5 2B quantization. Keeping the catalog explicit makes downloads,
/// verification, settings, and data deletion use the same artifact identity.
enum QwenTier { standard }

@immutable
class QwenModel {
  const QwenModel({
    required this.tier,
    required this.name,
    required this.parameterLabel,
    required this.fileName,
    required this.downloadUrl,
    required this.expectedBytes,
    required this.sha256Digest,
  });

  final QwenTier tier;
  final String name;
  final String parameterLabel;
  final String fileName;
  final String downloadUrl;
  final int expectedBytes;
  final String sha256Digest;

  String get sizeLabel {
    if (expectedBytes >= 1000 * 1000 * 1000) {
      return '${(expectedBytes / 1000 / 1000 / 1000).toStringAsFixed(2)} GB';
    }
    return '${(expectedBytes / 1000 / 1000).round()} MB';
  }
}

@immutable
class QwenArtifact {
  const QwenArtifact({
    required this.name,
    required this.fileName,
    required this.downloadUrl,
    required this.expectedBytes,
    required this.sha256Digest,
  });

  final String name;
  final String fileName;
  final String downloadUrl;
  final int expectedBytes;
  final String sha256Digest;

  String get sizeLabel => '${(expectedBytes / 1000 / 1000).round()} MB';
}

/// Q4_K_M is a practical quality/size choice for the supported ARM64 mobile
/// target. The LFS object IDs below are the published SHA-256 content hashes,
/// not mutable repository commit IDs.
const qwenModels = <QwenModel>[
  QwenModel(
    tier: QwenTier.standard,
    name: 'Qwen 3.5 2B',
    parameterLabel: 'Qwen 3.5 · 2B · Q4_K_M',
    fileName: 'Qwen3.5-2B-Q4_K_M.gguf',
    downloadUrl:
        'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/4f0c7c8a6dd19d5774b5c73e86d9f7e2a7d4f6b1/Qwen3.5-2B-Q4_K_M.gguf',
    expectedBytes: 1280835840,
    sha256Digest:
        'aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223',
  ),
];

/// Downloaded after the language model, but intentionally not wired into the
/// runtime yet. A later release can enable image input without changing the
/// model installation contract or moving the large projector into the APK.
const qwenMmproj = QwenArtifact(
  name: 'Qwen 3.5 multimodal component',
  fileName: 'Qwen3.5-2B-mmproj-F16.gguf',
  downloadUrl:
      'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/4f0c7c8a6dd19d5774b5c73e86d9f7e2a7d4f6b1/mmproj-F16.gguf',
  expectedBytes: 668227264,
  sha256Digest:
      '7035e9cb8d7c6a9681d07eef9a364783e86ea4cd73faab2eabb4f43a101830c7',
);
