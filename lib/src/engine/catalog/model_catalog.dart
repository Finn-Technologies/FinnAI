import 'package:flutter/foundation.dart';

/// Two tiers of one model family, LiquidAI's LFM2.5-VL, chosen per device
/// (ADR 0013, `ModelTierPolicy`): the 3B on phones at Snapdragon 845 level or
/// better with 8 GB of RAM, the 1.6B everywhere else. A device holds one tier
/// at a time; download, verification, settings and deletion all key off the
/// selected tier's artifacts.
enum FinnModelTier {
  /// LFM2.5-VL 1.6B: every supported device.
  standard,

  /// LFM2.5-VL 3B: devices that clear [ModelTierPolicy].
  plus,
}

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
    this.projector,
  });

  final FinnModelTier tier;
  final String name;
  final String parameterLabel;
  final String fileName;
  final String downloadUrl;
  final int expectedBytes;
  final String sha256Digest;

  /// The vision projector trained with this model. Each tier has its own;
  /// they are not interchangeable. Null only for evaluation stand-ins.
  final FinnModelArtifact? projector;

  /// Everything this tier downloads.
  int get totalBytes => expectedBytes + (projector?.expectedBytes ?? 0);

  String get sizeLabel => _size(expectedBytes);
  String get totalSizeLabel => _size(totalBytes);

  static String _size(int bytes) {
    if (bytes >= 1000 * 1000 * 1000) {
      return '${(bytes / 1000 / 1000 / 1000).toStringAsFixed(2)} GB';
    }
    return '${(bytes / 1000 / 1000).round()} MB';
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

/// Vision projector for LFM2.5-VL 1.6B (SigLIP2): OCR, documents,
/// screenshots.
const finnMmproj = FinnModelArtifact(
  name: 'LFM2.5-VL multimodal component',
  fileName: 'mmproj-LFM2.5-VL-1.6b-F16.gguf',
  downloadUrl:
      'https://huggingface.co/LiquidAI/LFM2.5-VL-1.6B-GGUF/resolve/36fc16bc95133424921bcc3da009e83b2f23ffb5/mmproj-LFM2.5-VL-1.6b-F16.gguf',
  expectedBytes: 853993856,
  sha256Digest:
      '2cddba98b98390c011c606c416de2e63dcfdd3b21452bf71ad6aab59fa52d2ee',
);

/// Vision projector for LFM2.5-VL 3B. Same size as the 1.6B's, different
/// weights (verified against Hugging Face LFS, revision 6f730e9).
const finnMmprojPlus = FinnModelArtifact(
  name: 'LFM2.5-VL 3B multimodal component',
  fileName: 'mmproj-LFM2.5-VL-3B-F16.gguf',
  downloadUrl:
      'https://huggingface.co/LiquidAI/LFM2.5-VL-3B-GGUF/resolve/6f730e9a2c454e8af9adc29db58e638e01e5957f/mmproj-LFM2.5-VL-3B-F16.gguf',
  expectedBytes: 853993952,
  sha256Digest:
      '74c4b2c095913be3cccce10aefe3b5d6f73aa7b4a15d49a8b68d97c229f8b922',
);

/// The tiers, lightest first. Values verified against Hugging Face LFS
/// metadata (`lfs.oid` is the SHA-256, `size` the byte count); the 3B's
/// digest was also recomputed from a full download.
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
    projector: finnMmproj,
  ),
  FinnModelSpec(
    tier: FinnModelTier.plus,
    name: 'LFM2.5-VL 3B',
    parameterLabel: 'LFM2.5-VL · 3B · Q4_0',
    fileName: 'LFM2.5-VL-3B-Q4_0.gguf',
    downloadUrl:
        'https://huggingface.co/LiquidAI/LFM2.5-VL-3B-GGUF/resolve/6f730e9a2c454e8af9adc29db58e638e01e5957f/LFM2.5-VL-3B-Q4_0.gguf',
    expectedBytes: 1593894944,
    sha256Digest:
        '364224c6bd45b4ff4bf8af71f7be384ea166fa0f573d68bc0b6e10ef9ae7ae58',
    projector: finnMmprojPlus,
  ),
];

/// The catalog entry for [tier].
FinnModelSpec finnModelFor(FinnModelTier tier) =>
    finnModels.firstWhere((model) => model.tier == tier);
