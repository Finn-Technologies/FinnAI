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

/// QAD (Quantization-Aware Distillation) Q4_0 provides near-FP16 quality (~97%
/// accuracy recovery) with an ultra-compact ~892 MB footprint, while the LFM2.5-VL
/// multimodal projector adds high-precision OCR and document understanding.
const qwenModels = <QwenModel>[
  QwenModel(
    tier: QwenTier.standard,
    name: 'LFM2.5-VL 1.6B',
    parameterLabel: 'LFM2.5-VL · 1.6B · QAD-4',
    fileName: 'LFM2.5-VL-1.6B-QAD-Q4_0.gguf',
    downloadUrl:
        'https://huggingface.co/LiquidAI/LFM2.5-VL-1.6B-GGUF/resolve/b58c7041a129d28e7e1cb904a4387d8df981b10a/LFM2.5-VL-1.6B-QAD-Q4_0.gguf',
    expectedBytes: 892168704,
    sha256Digest:
        '91a8f9c0e4d7b213840e5bb3057e937d5718a6c81373eefb22a0149021b34371',
  ),
];

/// Vision projector for LFM2.5-VL enabling high-resolution OCR, document understanding,
/// and screenshot/UI grounding.
const qwenMmproj = QwenArtifact(
  name: 'LFM2.5-VL multimodal component',
  fileName: 'mmproj-LFM2.5-VL-1.6B-F16.gguf',
  downloadUrl:
      'https://huggingface.co/LiquidAI/LFM2.5-VL-1.6B-GGUF/resolve/b58c7041a129d28e7e1cb904a4387d8df981b10a/mmproj-F16.gguf',
  expectedBytes: 338421760,
  sha256Digest:
      'a78f234981cb02e88a3cfbe47492c10978921a9ef2394cb5d4ef289a72199f18',
);
