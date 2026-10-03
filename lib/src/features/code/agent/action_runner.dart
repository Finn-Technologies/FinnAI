import 'package:finn_ai/src/features/code/sandbox/command_policy.dart';
import 'package:finn_ai/src/features/code/sandbox/shell_sandbox.dart';
import 'package:finn_ai/src/features/code/sandbox/workspace.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/sessions/code_session_store.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';

/// Carries out an action the agent proposed. Behind an interface so the agent
/// loop is tested without a shell or a disk.
abstract class CodeActionRunner {
  /// False where the platform cannot start a shell (iOS). File actions still
  /// work.
  bool get canRunCommands;

  /// Runs [action] in [sessionId]'s project folder and returns it with its
  /// status, output and exit code filled in. Never throws.
  Future<CodeAction> run(String sessionId, CodeAction action);
}

/// The real runner: files through [CodeWorkspace], commands through
/// [ShellSandbox], both confined to the session's project folder.
class WorkspaceActionRunner implements CodeActionRunner {
  WorkspaceActionRunner({
    required this.sessions,
    required this.settings,
    this.shellSupported,
  });

  final CodeSessionStore sessions;
  final CodeSettingsStore settings;

  /// Overrides [ShellSandbox.supported], for tests.
  final bool? shellSupported;

  @override
  bool get canRunCommands => shellSupported ?? ShellSandbox.supported;

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
    if (!canRunCommands) {
      return action.copyWith(
        status: CodeActionStatus.failed,
        output: 'Commands cannot run on this device.',
        exitCode: 127,
      );
    }
    final current = settings.settings;
    final sandbox = ShellSandbox(
      workspace: workspace,
      policy: CommandPolicy(allowNetwork: current.allowNetwork),
      timeout: Duration(seconds: current.commandTimeoutSeconds),
    );
    final result = await sandbox.run(action.command);
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
