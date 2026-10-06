import 'package:finn_ai/src/features/code/container/container_shell.dart';
import 'package:finn_ai/src/features/code/sandbox/command_policy.dart';
import 'package:finn_ai/src/features/code/sandbox/shell_sandbox.dart';
import 'package:finn_ai/src/features/code/sandbox/workspace.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/sessions/code_session_store.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';

/// Where a command runs.
enum CommandEnvironment {
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
  /// status, output and exit code filled in. Never throws.
  Future<CodeAction> run(String sessionId, CodeAction action);
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
    this.shellSupported,
  });

  final CodeSessionStore sessions;
  final CodeSettingsStore settings;
  final ContainerShell? container;

  /// Overrides [ShellSandbox.supported], for tests.
  final bool? shellSupported;

  @override
  CommandEnvironment get environment {
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
  Future<CodeAction> run(String sessionId, CodeAction action) async {
    final workspace = await sessions.workspaceOf(sessionId);
    return action.isShell
        ? _runShell(workspace, action)
        : _writeFile(workspace, action);
  }

  Future<CodeAction> _writeFile(
      CodeWorkspace workspace, CodeAction action) async {
    try {
      final path = await workspace.writeFile(action.path, action.content);
      return CodeAction(
        kind: action.kind,
        status: CodeActionStatus.done,
        path: path,
        content: action.content,
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

  Future<CodeAction> _runShell(
      CodeWorkspace workspace, CodeAction action) async {
    final current = settings.settings;
    final timeout = Duration(seconds: current.commandTimeoutSeconds);
    final ShellResult result;
    switch (environment) {
      case CommandEnvironment.none:
        return action.copyWith(
          status: CodeActionStatus.failed,
          output: 'Commands cannot run on this device.',
          exitCode: 127,
        );
      case CommandEnvironment.container:
        // The machine is the boundary here: no policy, nothing on the device
        // to protect from it beyond the folder it is handed.
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
