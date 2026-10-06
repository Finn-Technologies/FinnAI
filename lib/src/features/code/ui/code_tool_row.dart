import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/ui/code_blocks.dart';
import 'package:finn_ai/src/features/code/ui/code_diff_view.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_style.dart';
import 'package:finn_ai/src/features/code/ui/code_text.dart';
import 'package:finn_ai/src/features/code/ui/line_diff.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// One thing the agent did, as a single line: what, on what, and how it went.
/// Tapping it opens the details — the command and its output, or the diff.
///
/// Rows start closed so a session reads as a log. The exceptions open by
/// themselves: an action waiting for approval (its details are what is being
/// approved), a failed command (its output says why), and a small diff
/// (seeing a ten-line change is quicker than tapping for it).
class CodeToolRow extends StatefulWidget {
  const CodeToolRow({
    super.key,
    required this.action,
    this.awaitingApproval = false,
    this.onApprove,
    this.onSkip,
  });

  final CodeAction action;
  final bool awaitingApproval;
  final VoidCallback? onApprove;
  final VoidCallback? onSkip;

  /// A diff with at most this many changed lines opens by itself.
  static const int smallDiff = 12;

  @override
  State<CodeToolRow> createState() => _CodeToolRowState();
}

class _CodeToolRowState extends State<CodeToolRow> {
  bool? _userExpanded;
  List<DiffLine>? _diff;
  CodeAction? _diffFor;

  CodeAction get action => widget.action;

  bool get _finished =>
      action.status == CodeActionStatus.done ||
      action.status == CodeActionStatus.failed;

  List<DiffLine>? get diff {
    if (action.isShell) return null;
    if (!identical(_diffFor, action)) {
      _diffFor = action;
      final after = _finished || action.status == CodeActionStatus.skipped
          ? action.newText
          : action.content;
      // A proposed edit has no result yet: show its blocks as the change.
      _diff = action.isEdit && action.after.isEmpty
          ? _editPreview(action.content)
          : LineDiff.diff(_finished ? action.previous : null, after);
    }
    return _diff;
  }

  bool get _autoExpanded {
    if (widget.awaitingApproval) return true;
    if (action.status == CodeActionStatus.denied) return true;
    if (action.isShell) return action.status == CodeActionStatus.failed;
    final lines = diff;
    if (lines == null) return false;
    final (added, removed) = LineDiff.stats(lines);
    return added + removed <= CodeToolRow.smallDiff;
  }

  bool get _expanded =>
      widget.awaitingApproval || (_userExpanded ?? _autoExpanded);

  @override
  Widget build(BuildContext context) {
    final expanded = _expanded;
    return Semantics(
      container: true,
      child: Column(
        key: const ValueKey('code-tool-row'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            action: action,
            diff: diff,
            expanded: expanded,
            onTap: widget.awaitingApproval
                ? null
                : () => setState(() => _userExpanded = !expanded),
          ),
          if (!expanded && action.isShell && _finished)
            _OutputPeek(output: action.output),
          AnimatedSize(
            duration: CodeStyle.motion(context),
            curve: CodeStyle.curve,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(left: 22, top: 2, bottom: 4),
                    child: _Body(
                      action: action,
                      diff: diff,
                      awaitingApproval: widget.awaitingApproval,
                      onApprove: widget.onApprove,
                      onSkip: widget.onSkip,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  /// The search/replace blocks of a proposed edit, as removed and added
  /// lines.
  static List<DiffLine> _editPreview(String blocks) {
    final out = <DiffLine>[];
    var mode = DiffOp.same;
    for (final line in blocks.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('<<<<<<<')) {
        mode = DiffOp.removed;
      } else if (RegExp(r'^={5,}$').hasMatch(trimmed)) {
        mode = DiffOp.added;
      } else if (trimmed.startsWith('>>>>>>>')) {
        mode = DiffOp.same;
      } else if (mode != DiffOp.same) {
        out.add(DiffLine(mode, line));
      }
    }
    return out;
  }
}

/// The one-line summary: icon, verb, target, result, chevron.
class _Header extends StatelessWidget {
  const _Header({
    required this.action,
    required this.diff,
    required this.expanded,
    required this.onTap,
  });

  final CodeAction action;
  final List<DiffLine>? diff;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final muted = FluxColors.mutedOf(context);
    final verb = action.isShell
        ? l10n.codeVerbRun
        : (action.isEdit ? l10n.codeVerbEdit : l10n.codeVerbWrite);
    final target =
        action.isShell ? action.command.split('\n').first : action.path;
    final icon = action.isShell
        ? CodeIcons.prompt
        : (action.isEdit || action.previous != null
            ? CodeIcons.fileEdit
            : CodeIcons.fileNew);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: CodeStyle.rowHeight,
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: _StatusGlyph(action: action, icon: icon),
            ),
            Text(verb, style: CodeStyle.label(context, color: muted)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                target,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CodeStyle.code(context),
              ),
            ),
            const SizedBox(width: 8),
            _Result(action: action, diff: diff),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: expanded ? .5 : 0,
                duration: CodeStyle.motion(context, CodeStyle.fast),
                child: FluxIcon(
                    icon: CodeIcons.chevronDown, size: 13, color: muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The row's leading glyph: what kind of action, tinted by how it went; a
/// spinner while it runs.
class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({required this.action, required this.icon});

  final CodeAction action;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = switch (action.status) {
      CodeActionStatus.failed => FluxColors.destructiveOf(context),
      CodeActionStatus.denied => FluxColors.warningOf(context),
      CodeActionStatus.done => FluxColors.successOf(context),
      _ => FluxColors.mutedOf(context),
    };
    return AnimatedSwitcher(
      duration: CodeStyle.motion(context, CodeStyle.fast),
      child: action.status == CodeActionStatus.running
          ? SizedBox.square(
              key: const ValueKey('running'),
              dimension: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: FluxColors.mutedOf(context),
              ),
            )
          : Align(
              key: ValueKey(action.status),
              alignment: Alignment.centerLeft,
              child: FluxIcon(icon: icon, size: 14, color: color),
            ),
    );
  }
}

/// Right side of the row: +/− counts for a file, the exit code or state for
/// a command.
class _Result extends StatelessWidget {
  const _Result({required this.action, required this.diff});

  final CodeAction action;
  final List<DiffLine>? diff;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final style = CodeStyle.meta(context);
    switch (action.status) {
      case CodeActionStatus.skipped:
        return Text(l10n.codeActionSkipped, style: style);
      case CodeActionStatus.denied:
        return Text(l10n.codeActionDenied,
            style: style.copyWith(color: FluxColors.warningOf(context)));
      case CodeActionStatus.running:
        return Text(l10n.codeActionRunning, style: style);
      case CodeActionStatus.proposed:
      case CodeActionStatus.done:
      case CodeActionStatus.failed:
        break;
    }
    if (action.isShell) {
      if (action.timedOut) {
        return Text(l10n.codeActionTimedOut,
            style: style.copyWith(color: FluxColors.destructiveOf(context)));
      }
      final code = action.exitCode;
      if (action.status == CodeActionStatus.failed && code != null) {
        return Text(l10n.codeExitCode('$code'),
            style: style.copyWith(color: FluxColors.destructiveOf(context)));
      }
      return const SizedBox.shrink();
    }
    if (action.status == CodeActionStatus.failed) {
      return Text(l10n.codeActionFailed,
          style: style.copyWith(color: FluxColors.destructiveOf(context)));
    }
    final lines = diff;
    if (lines == null) return const SizedBox.shrink();
    final (added, removed) = LineDiff.stats(lines);
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: '+$added',
          style: style.copyWith(color: CodeStyle.addedSignOf(context)),
        ),
        if (removed > 0)
          TextSpan(
            text: ' −$removed',
            style: style.copyWith(color: CodeStyle.removedSignOf(context)),
          ),
      ]),
    );
  }
}

/// Under a closed command row: the last line it printed, so a session can be
/// followed without opening every row.
class _OutputPeek extends StatelessWidget {
  const _OutputPeek({required this.output});

  final String output;

  @override
  Widget build(BuildContext context) {
    final lines = output.trimRight().split('\n');
    final last = lines.lastWhere(
      (line) => line.trim().isNotEmpty,
      orElse: () => '',
    );
    if (last.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 22, bottom: 2),
      child: Text(
        lines.length > 1 ? '└ $last  (${lines.length})' : '└ $last',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: CodeStyle.meta(context),
      ),
    );
  }
}

/// The opened row: the full command and its output, or the diff, and the
/// approval bar while one is waited for.
class _Body extends StatelessWidget {
  const _Body({
    required this.action,
    required this.diff,
    required this.awaitingApproval,
    required this.onApprove,
    required this.onSkip,
  });

  final CodeAction action;
  final List<DiffLine>? diff;
  final bool awaitingApproval;
  final VoidCallback? onApprove;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final children = <Widget>[];
    if (action.status == CodeActionStatus.denied) {
      children.add(Text(
        CodeText.denied(l10n, action),
        style: CodeStyle.label(context, color: FluxColors.warningOf(context)),
      ));
    }
    if (action.isShell) {
      final output = action.output.trimRight();
      children.add(CodeOutputBlock(
        command: action.command,
        output: output,
        truncated: action.truncated,
      ));
    } else {
      if (action.status == CodeActionStatus.failed &&
          action.output.isNotEmpty) {
        children.add(Text(
          action.output,
          style: CodeStyle.label(context,
              color: FluxColors.destructiveOf(context)),
        ));
      }
      final lines = diff;
      if (lines != null && lines.isNotEmpty) {
        children.add(CodeDiffView(lines: lines));
      }
    }
    if (awaitingApproval) {
      children.add(_ApprovalBar(
        question: action.isShell
            ? l10n.codeApproveRun
            : (action.isEdit ? l10n.codeApproveEdit : l10n.codeApproveWrite),
        approveLabel: action.isShell ? l10n.codeActionRun : l10n.codeApply,
        onApprove: onApprove,
        onSkip: onSkip,
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) const SizedBox(height: 6),
          child,
        ],
      ],
    );
  }
}

/// "Run this command?  [Reject] [Run]" — small, inline, under what it asks
/// about.
class _ApprovalBar extends StatelessWidget {
  const _ApprovalBar({
    required this.question,
    required this.approveLabel,
    required this.onApprove,
    required this.onSkip,
  });

  final String question;
  final String approveLabel;
  final VoidCallback? onApprove;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Row(
      key: const ValueKey('code-approval-bar'),
      children: [
        Expanded(
          child: Text(question, style: CodeStyle.label(context)),
        ),
        CodeSmallButton(
          key: const ValueKey('code-approval-reject'),
          label: l10n.codeReject,
          onTap: onSkip,
        ),
        const SizedBox(width: 6),
        CodeSmallButton(
          key: const ValueKey('code-approval-approve'),
          label: approveLabel,
          onTap: onApprove,
          primary: true,
        ),
      ],
    );
  }
}
