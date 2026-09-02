import 'package:flutter/foundation.dart';

/// The app deliberately exposes one model choice: LiquidAI's LFM2.5-VL 1.6B
/// (Q4_0 GGUF) plus its SigLIP2 vision projector. Keeping the catalog
/// explicit makes downloads, verification, settings, and data deletion use
/// the same artifact identity.
enum FinnModelTier { standard }

@immutable
class FinnModelSpec {
  const FinnModelSpec({
    required this.tier,
    required this.name,
    required this.parameterLabel,
    required this.fileName,
    required this.downloadUrl,
    required this.expectedBytes,
    required this.sha256Digest,
  });

  final FinnModelTier tier;
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
class FinnModelArtifact {
  const FinnModelArtifact({
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

/// LFM2.5-VL 1.6B Q4_0 provides ultra-compact on-device multimodal intelligence,
/// paired with the SigLIP2 vision projector for high-precision OCR and document understanding.
const finnModels = <FinnModelSpec>[
  FinnModelSpec(
    tier: FinnModelTier.standard,
    name: 'LFM2.5-VL 1.6B',
    parameterLabel: 'LFM2.5-VL · 1.6B · Q4_0',
    fileName: 'LFM2.5-VL-1.6B-Q4_0.gguf',
    downloadUrl:
        'https://huggingface.co/LiquidAI/LFM2.5-VL-1.6B-GGUF/resolve/36fc16bc95133424921bcc3da009e83b2f23ffb5/LFM2.5-VL-1.6B-Q4_0.gguf',
    expectedBytes: 695752480,
    sha256Digest:
        '8186364a4e7c3ad30f6dd3d3b7a4e0074c77dd91eed6cad5d8be9090ce285804',
  ),
];

/// Vision projector for LFM2.5-VL enabling high-resolution OCR, document understanding,
/// and screenshot/UI grounding.
const finnMmproj = FinnModelArtifact(
  name: 'LFM2.5-VL multimodal component',
  fileName: 'mmproj-LFM2.5-VL-1.6b-F16.gguf',
  downloadUrl:
      'https://huggingface.co/LiquidAI/LFM2.5-VL-1.6B-GGUF/resolve/36fc16bc95133424921bcc3da009e83b2f23ffb5/mmproj-LFM2.5-VL-1.6b-F16.gguf',
  expectedBytes: 853993856,
  sha256Digest:
      '2cddba98b98390c011c606c416de2e63dcfdd3b21452bf71ad6aab59fa52d2ee',
);
