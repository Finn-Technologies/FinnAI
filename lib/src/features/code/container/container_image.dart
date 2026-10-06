import 'package:flutter/foundation.dart';

/// One file the Linux container needs that is not shipped in the app.
///
/// Like the model, each one is downloaded once, checked against a pinned
/// size and SHA-256, and kept in private storage. A mismatch is a failed
/// install, never a container that boots something else.
@immutable
class ContainerArtifact {
  const ContainerArtifact({
    required this.fileName,
    required this.url,
    required this.bytes,
    required this.sha256,
  });

  /// Name on disk, and the path the runtime page fetches it by.
  final String fileName;
  final String url;
  final int bytes;
  final String sha256;
}

/// What FinnAI Code's container is made of.
///
/// The emulator (v86, BSD-2-Clause) is small and ships in the app as
/// `assets/code_container/`. The Linux kernel with its busybox userland
/// (GPL-2.0) and the BIOS images (LGPL-3.0) are downloaded from v86's own
/// published builds, pinned to the commit the bundled emulator was built from
/// (`6db8b15`). `docs/decisions/0011-code-linux-container.md` explains the
/// choice; verify any change here the way the model's digest is verified.
abstract final class ContainerImage {
  static const String emulatorCommit =
      '6db8b157974dbaf1b54d2c2ec12dd71ddc1891e9';

  static const List<ContainerArtifact> artifacts = [
    ContainerArtifact(
      fileName: 'bzimage.bin',
      url: 'https://i.copy.sh/buildroot-bzimage68.bin',
      bytes: 10068480,
      sha256:
          '507a759c70ab7a490a233be454d0b5b88bc667956a410b531cb4edc091e2eb1c',
    ),
    ContainerArtifact(
      fileName: 'seabios.bin',
      url: 'https://raw.githubusercontent.com/copy/v86/'
          '$emulatorCommit/bios/seabios.bin',
      bytes: 131072,
      sha256:
          '73e3f359102e3a9982c35fce98eb7cd08f18303ac7f1ba6ebfbe6cdc1c244d98',
    ),
    ContainerArtifact(
      fileName: 'vgabios.bin',
      url: 'https://raw.githubusercontent.com/copy/v86/'
          '$emulatorCommit/bios/vgabios.bin',
      bytes: 36352,
      sha256:
          'a4bc0d80cc3ca028c73dafa8fee396b8d054ce87ebd8abfbd31b06b437607880',
    ),
  ];

  /// Files served from the app bundle rather than downloaded.
  static const String assetDirectory = 'assets/code_container';
  static const List<String> bundled = ['runtime.html', 'libv86.js', 'v86.wasm'];

  static int get downloadBytes =>
      artifacts.fold(0, (sum, artifact) => sum + artifact.bytes);
}
