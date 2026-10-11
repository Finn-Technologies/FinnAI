import 'dart:io';

import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/agent/agent_tools.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/sessions/code_session_store.dart';
import 'package:finn_ai/src/features/code/sandbox/workspace.dart';

/// Carries out one [AgentCall] and returns a [ToolResult]. Behind an interface
/// so the agent loop is tested without a disk or a shell.
abstract class CodeToolRunner {
  /// Where the next command would run.
  CommandEnvironment get environment;

  /// False where no command can run (iOS without the container). File tools
  /// still work.
  bool get allowShell => environment != CommandEnvironment.none;

  /// Runs [call] in [sessionId]'s project folder. Never throws. [onOutput] gets
  /// a command's output as it arrives.
  Future<ToolResult> run(
    String sessionId,
    AgentCall call, {
    void Function(String chunk)? onOutput,
  });
}

/// The real runner: read/list/write/edit go straight to the exact file
/// [CodeWorkspace]; write/edit/bash are carried by the existing
/// [CodeActionRunner], which already picks the Linux sandbox, the container, or
/// the device shell. One tool vocabulary, the same confinement rules.
class WorkspaceCodeToolRunner implements CodeToolRunner {
  WorkspaceCodeToolRunner({required this.sessions, required this.actions});

  final CodeSessionStore sessions;
  final CodeActionRunner actions;

  @override
  CommandEnvironment get environment => actions.environment;

  @override
  bool get allowShell => environment != CommandEnvironment.none;

  @override
  Future<ToolResult> run(
    String sessionId,
    AgentCall call, {
    void Function(String chunk)? onOutput,
  }) async {
    final workspace = await sessions.workspaceOf(sessionId);
    switch (call.tool) {
      case AgentTool.read:
        return _read(workspace, call.path);
      case AgentTool.list:
        return _list(workspace, call.path);
      case AgentTool.write:
      case AgentTool.edit:
        return _file(actions, sessionId, call);
      case AgentTool.bash:
        if (!allowShell) {
          return const ToolResult(
            ok: false,
            text: 'Commands cannot run on this device.',
          );
        }
        return _fromAction(await actions.run(
          sessionId,
          CodeAction.shell(call.command),
          onOutput: onOutput,
        ));
    }
  }

  Future<ToolResult> _read(CodeWorkspace workspace, String path) async {
    try {
      return ToolResult(
          ok: true, path: path, text: await workspace.readFile(path));
    } on WorkspaceEscape {
      return ToolResult(
        ok: false,
        path: path,
        text: 'Path is outside the project folder: $path',
      );
    } on FileSystemException catch (error) {
      return ToolResult(ok: false, path: path, text: error.message);
    }
  }

  Future<ToolResult> _list(CodeWorkspace workspace, String directory) async {
    try {
      final entries = await workspace.list(directory: directory);
      final text = entries.isEmpty
          ? '(empty folder)'
          : entries
              .map((e) => e.isDirectory ? '${e.path}/' : e.path)
              .join('\n');
      return ToolResult(ok: true, path: directory, text: text);
    } on WorkspaceEscape {
      return ToolResult(
        ok: false,
        path: directory,
        text: 'Path is outside the project folder: $directory',
      );
    }
  }

  Future<ToolResult> _file(
    CodeActionRunner actions,
    String sessionId,
    AgentCall call,
  ) =>
      actions
          .run(
            sessionId,
            call.isEdit
                ? CodeAction.edit(call.path, call.content)
                : CodeAction.write(call.path, call.content),
          )
          .then(_fromAction);

  static ToolResult _fromAction(CodeAction action) => ToolResult(
        ok: action.status == CodeActionStatus.done,
        path: action.path,
        text: action.output,
        exitCode: action.exitCode,
        truncated: action.truncated,
        timedOut: action.timedOut,
        denied: action.deniedReason,
        deniedDetail: action.deniedDetail,
        previous: action.previous,
        after: action.isEdit ? action.after : action.content,
      );
}
