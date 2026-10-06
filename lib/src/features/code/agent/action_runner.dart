import 'dart:io';

import 'package:finn_ai/src/features/code/agent/edit_blocks.dart';
import 'package:finn_ai/src/features/code/container/container_shell.dart';
import 'package:finn_ai/src/features/code/linux/linux_sandbox.dart';
import 'package:finn_ai/src/features/code/sandbox/command_policy.dart';
import 'package:finn_ai/src/features/code/sandbox/shell_sandbox.dart';
import 'package:finn_ai/src/features/code/sandbox/workspace.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/sessions/code_session_store.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';

/// Where a command runs.
enum CommandEnvironment {
  /// The native Linux sandbox: Alpine under proot, on the device's own CPU,
  /// with the network (ADR 0012).
  linux,

  /// The Linux container: an emulated PC with busybox, isolated from the
  /// device (`docs/decisions/0011-code-linux-container.md`).
  container,

  /// The device's own shell, confined to the project folder by policy.
  device,

  /// Nowhere: only files can be written.
  none,
}

/// Carries out an action the agent proposed. Behind an interface so the agent
/// loop is tested without a shell or a disk.
abstract class CodeActionRunner {
  /// Where the next command would run.
  CommandEnvironment get environment;

  /// False where no command can run (iOS without the container). File actions
  /// still work.
  bool get canRunCommands => environment != CommandEnvironment.none;

  /// Runs [action] in [sessionId]'s project folder and returns it with its
  /// status, output and exit code filled in. Never throws. [onOutput] gets a
  /// command's output as it arrives, where the environment can stream it.
  Future<CodeAction> run(
    String sessionId,
    CodeAction action, {
    void Function(String chunk)? onOutput,
  });
}

/// The real runner: files through [CodeWorkspace]; commands in the Linux
/// [container] when it is chosen and installed, otherwise through
/// [ShellSandbox] on the device. Both are confined to the session's project
/// folder.
class WorkspaceActionRunner extends CodeActionRunner {
  WorkspaceActionRunner({
    required this.sessions,
    required this.settings,
    this.container,
    this.linux,
    this.shellSupported,
  });

  final CodeSessionStore sessions;
  final CodeSettingsStore settings;
  final ContainerShell? container;

  /// The proot + Alpine sandbox (ADR 0012), preferred over [container]
  /// wherever it runs.
  final LinuxSandbox? linux;

  /// Overrides [ShellSandbox.supported], for tests.
  final bool? shellSupported;

  @override
  CommandEnvironment get environment {
    final linux = this.linux;
    if (linux != null && linux.ready && settings.settings.useContainer) {
      return CommandEnvironment.linux;
    }
    final container = this.container;
    if (container != null &&
        container.ready &&
        settings.settings.useContainer) {
      return CommandEnvironment.container;
    }
    return (shellSupported ?? ShellSandbox.supported)
        ? CommandEnvironment.device
        : CommandEnvironment.none;
  }

  @override
  Future<CodeAction> run(
    String sessionId,
    CodeAction action, {
    void Function(String chunk)? onOutput,
  }) async {
    final workspace = await sessions.workspaceOf(sessionId);
    return action.isShell
        ? _runShell(workspace, action, onOutput)
        : _writeFile(workspace, action);
  }

  /// Installs and builds outlast any sensible limit for `ls`: a package
  /// manager, a clone or a build gets ten minutes in Linux.
  static final RegExp _longRunning = RegExp(
    r'\b(apk|apt|apt-get|pip3?|npm|npx|yarn|pnpm|git\s+clone|make|cargo|go\s+(build|get|mod)|gcc|g\+\+|cc|cmake)\b',
  );

  static Duration timeoutFor(String command, int seconds,
      {required bool linux}) {
    final base = Duration(seconds: seconds);
    if (linux && _longRunning.hasMatch(command)) {
      return base > const Duration(minutes: 10)
          ? base
          : const Duration(minutes: 10);
    }
    return base;
  }

  Future<CodeAction> _writeFile(
      CodeWorkspace workspace, CodeAction action) async {
    try {
      final previous = await _current(workspace, action.path);
      final String next;
      if (action.isEdit) {
        final pairs = EditBlocks.parse(action.content);
        if (pairs == null) {
          return action.copyWith(
            status: CodeActionStatus.failed,
            output: 'No complete SEARCH/REPLACE block.',
          );
        }
        if (previous == null) {
          return action.copyWith(
            status: CodeActionStatus.failed,
            output: 'No such file. Create it with a file action.',
          );
        }
        next = EditBlocks.apply(previous, pairs);
      } else {
        next = action.content;
      }
      final path = await workspace.writeFile(action.path, next);
      return CodeAction(
        kind: action.kind,
        status: CodeActionStatus.done,
        path: path,
        content: action.content,
        previous: previous,
        after: action.isEdit ? next : '',
      );
    } on EditMismatch catch (error) {
      return action.copyWith(
        status: CodeActionStatus.failed,
        output: error.toString(),
      );
    } on WorkspaceEscape {
      return action.copyWith(
        status: CodeActionStatus.denied,
        deniedReason: PolicyReason.outsideWorkspace,
        deniedDetail: action.path,
      );
    } on FormatException catch (error) {
      return action.copyWith(
        status: CodeActionStatus.failed,
        output: error.message,
      );
    } catch (error) {
      return action.copyWith(
        status: CodeActionStatus.failed,
        output: error is Exception ? error.toString() : 'Could not write.',
      );
    }
  }

  /// The file's text before the action, or null when it does not exist.
  static Future<String?> _current(CodeWorkspace workspace, String path) async {
    try {
      final file = workspace.fileFor(path);
      if (!await file.exists()) return null;
      return await workspace.readFile(path);
    } on FileSystemException {
      return null;
    }
  }

  Future<CodeAction> _runShell(
    CodeWorkspace workspace,
    CodeAction action,
    void Function(String chunk)? onOutput,
  ) async {
    final current = settings.settings;
    final timeout = timeoutFor(
      action.command,
      current.commandTimeoutSeconds,
      linux: environment == CommandEnvironment.linux,
    );
    final ShellResult result;
    switch (environment) {
      case CommandEnvironment.none:
        return action.copyWith(
          status: CodeActionStatus.failed,
          output: 'Commands cannot run on this device.',
          exitCode: 127,
        );
      case CommandEnvironment.linux:
        // Linux is the boundary here: no command policy. The sandbox sees
        // its own filesystem and the project folder, nothing else.
        result = await linux!.run(
          workspace,
          action.command,
          timeout: timeout,
          onOutput: onOutput,
        );
      case CommandEnvironment.container:
        // The emulated machine is the boundary: no policy, nothing on the
        // device to protect from it beyond the folder it is handed.
        result =
            await container!.run(workspace, action.command, timeout: timeout);
      case CommandEnvironment.device:
        result = await ShellSandbox(
          workspace: workspace,
          policy: CommandPolicy(allowNetwork: current.allowNetwork),
          timeout: timeout,
        ).run(action.command);
    }
    if (result.denied != null) {
      return action.copyWith(
        status: CodeActionStatus.denied,
        deniedReason: result.denied,
        deniedDetail: result.deniedDetail,
      );
    }
    return action.copyWith(
      status: result.ok ? CodeActionStatus.done : CodeActionStatus.failed,
      output: result.output,
      exitCode: result.exitCode,
      truncated: result.truncated,
      timedOut: result.timedOut,
    );
  }
}
