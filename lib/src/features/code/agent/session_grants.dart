import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';

/// Whether [action] waits for a tap under [mode] (before session grants).
bool codeNeedsApproval(CodePermissionMode mode, CodeAction action) =>
    switch (mode) {
      CodePermissionMode.askEveryTime => true,
      CodePermissionMode.acceptEdits => action.isShell,
      CodePermissionMode.autoRun => false,
    };

/// "Allow in this session": approvals the user widened from one action to
/// the rest of a session, as Codex's remote approvals do. File changes are
/// granted as a kind; a command is granted by its program (`npm`, `python`),
/// never every command. Held in memory only: a restart asks again.
class CodeSessionGrants {
  final Map<String, Set<String>> _grants = {};

  /// A command that chains or nests others (`a && b`, `a; b`, a pipe, a
  /// second line, `$(…)`) or redirects into a file can never be granted:
  /// its first program would vouch for the rest.
  static final RegExp _compound = RegExp(r'[\n;&|`<>]|\$\(');

  /// Whether "Allow in session" is offered for [action] at all.
  static bool canGrant(CodeAction action) =>
      !action.isShell || !_compound.hasMatch(action.command.trim());

  static String _scope(CodeAction action) {
    if (!action.isShell) return 'files';
    final program = action.command.trim().split(RegExp(r'\s+')).first;
    return 'sh:$program';
  }

  /// True when [action] in [sessionId] was allowed for the whole session.
  bool covers(String sessionId, CodeAction action) =>
      canGrant(action) &&
      (_grants[sessionId]?.contains(_scope(action)) ?? false);

  void grant(String sessionId, CodeAction action) {
    if (canGrant(action)) (_grants[sessionId] ??= {}).add(_scope(action));
  }

  void clear() => _grants.clear();
}
