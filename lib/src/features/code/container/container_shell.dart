import 'dart:async';

import 'package:flutter/services.dart';

import 'package:finn_ai/src/features/code/container/container_host.dart';
import 'package:finn_ai/src/features/code/container/container_image.dart';
import 'package:finn_ai/src/features/code/container/container_installer.dart';
import 'package:finn_ai/src/features/code/container/container_view.dart';
import 'package:finn_ai/src/features/code/container/workspace_sync.dart';
import 'package:finn_ai/src/features/code/sandbox/shell_sandbox.dart';
import 'package:finn_ai/src/features/code/sandbox/workspace.dart';

/// Runs commands in the Linux container instead of on the device.
///
/// The project folder on the device stays the truth: it is copied in before
/// each command and the container's copy is applied back after
/// ([WorkspaceSync]). The machine itself is an emulated x86 PC, so a command
/// can do anything to it and nothing to the phone.
class ContainerShell {
  ContainerShell({
    required this.installer,
    ContainerHost? host,
    bool? platformSupported,
  })  : _platformSupported = platformSupported ?? ContainerView.supported,
        host = host ??
            ContainerHost(
              loadAsset: (name) async => (await rootBundle
                      .load('${ContainerImage.assetDirectory}/$name'))
                  .buffer
                  .asUint8List(),
              imageDirectory: installer.directory,
            );

  final ContainerInstaller installer;
  final ContainerHost host;
  final bool _platformSupported;

  /// This platform can host the container at all.
  bool get platformSupported => _platformSupported;

  /// The container can run a command now (or after booting).
  bool get ready => _platformSupported && installer.installed;

  Future<ShellResult> run(
    CodeWorkspace workspace,
    String command, {
    required Duration timeout,
    int maxOutputBytes = 32 * 1024,
  }) async {
    final started = DateTime.now();
    final sync = WorkspaceSync(workspace);
    try {
      final tar = await sync.pack();
      final run = await host.run(
        command,
        projectTar: tar,
        // The first command also boots the machine; that is not its time.
        timeout: timeout,
        maxOutputBytes: maxOutputBytes,
      );
      var output = run.output;
      final back = run.tar;
      if (back != null) {
        await sync.apply(back);
      } else {
        output = '$output\n[The project could not be copied back from the '
            'container; the folder on the device is unchanged.]';
      }
      return ShellResult(
        exitCode: run.exitCode,
        output: output,
        truncated: run.truncated,
        timedOut: run.timedOut,
        duration: DateTime.now().difference(started),
      );
    } on WorkspaceTooLarge catch (error) {
      return ShellResult(
        exitCode: 1,
        output: 'The project is too large for the container '
            '(${error.bytes ~/ (1024 * 1024)} MB; the limit is '
            '${sync.maxBytes ~/ (1024 * 1024)} MB).',
      );
    } on ContainerUnavailable catch (error) {
      return ShellResult(exitCode: 127, output: 'Linux container: $error');
    } catch (error) {
      return ShellResult(
          exitCode: 127, output: 'Linux container failed: $error');
    }
  }

  /// Shuts the machine down (leaving FinnAI Code, deleting data).
  Future<void> stop() => host.stop();
}
