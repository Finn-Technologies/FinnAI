import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/line_diff.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// Where a session stands, for its dot and its status line.
enum CodeSessionState { idle, working, needsYou, done, failed }

/// What a session's row says about it: its state, the files it changed and
/// the lines it added and removed. Worked out once per version of a session
/// (diffs are not free on a phone) and cached by its last update.
@immutable
class CodeSessionSummary {
  const CodeSessionSummary({
    required this.state,
    required this.files,
    required this.added,
    required this.removed,
  });

  final CodeSessionState state;
  final int files;
  final int added;
  final int removed;

  static final Map<String, (DateTime, CodeSessionSummary)> _cache = {};

  static CodeSessionSummary of(CodeSession session) {
    final hit = _cache[session.id];
    if (hit != null && hit.$1 == session.updatedAt) return hit.$2;
    final summary = _compute(session);
    if (_cache.length > 300) _cache.clear();
    _cache[session.id] = (session.updatedAt, summary);
    return summary;
  }

  static CodeSessionSummary _compute(CodeSession session) {
    final paths = <String>{};
    var added = 0, removed = 0;
    CodeAction? last;
    for (final message in session.messages) {
      final action = message.action;
      if (action == null) continue;
      last = action;
      if (action.kind == CodeActionKind.shell ||
          action.status != CodeActionStatus.done) {
        continue;
      }
      paths.add(action.path);
      final (a, r) = LineDiff.stats(
        LineDiff.diff(action.previous, action.newText),
      );
      added += a;
      removed += r;
    }
    final state = switch (last?.status) {
      CodeActionStatus.running => CodeSessionState.working,
      CodeActionStatus.proposed => CodeSessionState.needsYou,
      CodeActionStatus.failed ||
      CodeActionStatus.denied =>
        CodeSessionState.failed,
      CodeActionStatus.done => CodeSessionState.done,
      _ => CodeSessionState.idle,
    };
    return CodeSessionSummary(
      state: state,
      files: paths.length,
      added: added,
      removed: removed,
    );
  }
}

/// One session as a row, the way Cursor's mobile app lists agents: a state
/// dot, the title, and one quiet line — how it went, how many files, and
/// the lines it added and removed in green and red.
class CodeSessionRow extends StatelessWidget {
  const CodeSessionRow({
    super.key,
    required this.session,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final CodeSession session;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final summary = CodeSessionSummary.of(session);
    final title = session.title.isEmpty ? l10n.codeNewSession : session.title;
    final muted = FluxColors.timestampOf(context);
    final status = switch (summary.state) {
      CodeSessionState.working => l10n.codeSessionWorking,
      CodeSessionState.needsYou => l10n.codeSessionNeedsYou,
      CodeSessionState.failed => l10n.codeActionFailed,
      CodeSessionState.done => l10n.codeActionDone,
      CodeSessionState.idle => null,
    };
    final files = summary.files == 0
        ? l10n.codeSessionNoChanges
        : summary.files == 1
            ? l10n.codeSessionOneFile
            : l10n.codeSessionFileCount(summary.files);
    final lineStyle = TextStyle(
      fontFamily: 'Geist',
      fontSize: 13,
      height: 1.25,
      color: muted,
    );
    return Semantics(
      button: true,
      onTap: onTap,
      selected: selected,
      label: [title, if (status != null) status, files].join('. '),
      excludeSemantics: true,
      child: Material(
        color: selected ? FluxColors.tileOf(context) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 11, 10, 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 12),
                  child: _StateDot(state: summary.state),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 15,
                                height: 1.25,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.2,
                                color: FluxColors.inkOf(context),
                              ),
                            ),
                          ),
                          if (session.pinned)
                            FluxIcon(
                                icon: CodeIcons.pin, size: 14, color: muted),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(
                          style: lineStyle,
                          children: [
                            if (status != null) ...[
                              TextSpan(text: status),
                              const TextSpan(text: ' · '),
                            ],
                            TextSpan(text: files),
                            if (summary.added > 0 || summary.removed > 0) ...[
                              const TextSpan(text: ' · '),
                              TextSpan(
                                text: '+${summary.added}',
                                style: TextStyle(
                                  color: FluxColors.successOf(context),
                                ),
                              ),
                              const TextSpan(text: ' '),
                              TextSpan(
                                text: '−${summary.removed}',
                                style: TextStyle(
                                  color: FluxColors.destructiveOf(context),
                                ),
                              ),
                            ],
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The session's state at a glance: blue when it finished with changes,
/// amber when it waits for you, red when it failed, grey when quiet, and a
/// breathing ring while it works.
class _StateDot extends StatefulWidget {
  const _StateDot({required this.state});

  final CodeSessionState state;

  @override
  State<_StateDot> createState() => _StateDotState();
}

class _StateDotState extends State<_StateDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _StateDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final working = widget.state == CodeSessionState.working &&
        !MediaQuery.disableAnimationsOf(context);
    if (working && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!working && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.state) {
      CodeSessionState.done => FluxColors.accentOf(context),
      CodeSessionState.needsYou => FluxColors.warningOf(context),
      CodeSessionState.failed => FluxColors.destructiveOf(context),
      CodeSessionState.working => FluxColors.accentOf(context),
      CodeSessionState.idle =>
        FluxColors.mutedOf(context).withValues(alpha: .5),
    };
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        return SizedBox.square(
          dimension: 9,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.state == CodeSessionState.working
                  ? color.withValues(alpha: .35 + .65 * t)
                  : color,
              boxShadow: widget.state == CodeSessionState.working
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: .35 * t),
                        blurRadius: 6,
                        spreadRadius: 1.5 * t,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      },
    );
  }
}
