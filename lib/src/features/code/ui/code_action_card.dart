import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_text.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/flux_surfaces.dart';

/// What the agent did, or wants to do: the command or the file, how it went,
/// and — while it waits — the two buttons that decide it.
class CodeActionCard extends StatefulWidget {
  const CodeActionCard({
    super.key,
    required this.action,
    this.awaitingApproval = false,
    this.onApprove,
    this.onSkip,
  });

  final CodeAction action;

  /// This is the action the agent is waiting on.
  final bool awaitingApproval;
  final VoidCallback? onApprove;
  final VoidCallback? onSkip;

  /// Lines of a file or of output shown before "show more".
  static const int previewLines = 8;

  @override
  State<CodeActionCard> createState() => _CodeActionCardState();
}

class _CodeActionCardState extends State<CodeActionCard> {
  bool _expanded = false;

  CodeAction get action => widget.action;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context).textTheme;
    final body = action.isShell ? action.command : action.content;
    final status = _status(context);
    final detail = _detail(context);

    return Semantics(
      container: true,
      child: Container(
        key: const ValueKey('code-action-card'),
        padding: const EdgeInsets.all(14),
        // Flat with a hairline, like a chat bubble. This used to use
        // elevationShadow, which is a lift for *transient* surfaces — over the
        // dark canvas it rendered as an almost invisible 6% wash, so the card
        // had no edge at all and read as a grey slab.
        decoration: FluxSurfaces.flatCard(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: FluxColors.tileOf(context),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: FluxIcon(
                    icon: action.isShell ? CodeIcons.terminal : CodeIcons.file,
                    size: 18,
                    color: FluxColors.actionOf(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    action.isShell
                        ? l10n.codeActionRunCommand
                        : l10n.codeActionWriteFile(action.path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                // The pill changes in place: the old state shrinks away as
                // the new one grows in, so "Running…" visibly becomes "Done".
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale:
                          Tween<double>(begin: .85, end: 1).animate(animation),
                      alignment: Alignment.centerRight,
                      child: child,
                    ),
                  ),
                  child: status ?? const SizedBox.shrink(),
                ),
              ],
            ),
            // Output arriving and the approval row leaving resize the card
            // smoothly instead of making the transcript jump.
            AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 320),
              curve: const Cubic(.2, .9, .25, 1),
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (body.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _CodeBox(
                      text: body,
                      prompt: action.isShell,
                      expanded: _expanded,
                      onToggle: () => setState(() => _expanded = !_expanded),
                    ),
                  ],
                  if (detail != null) ...[const SizedBox(height: 10), detail],
                  if (widget.awaitingApproval) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FinnButton(
                            label: l10n.codeActionSkip,
                            onTap: widget.onSkip,
                            secondary: true,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FinnButton(
                            label: action.isShell
                                ? l10n.codeActionRun
                                : l10n.codeActionAllow,
                            onTap: widget.onApprove,
                            icon: action.isShell ? CodeIcons.play : null,
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The small status pill on the right of the title.
  Widget? _status(BuildContext context) {
    final l10n = L10n.of(context);
    final (String label, Color color, Widget? lead) = switch (action.status) {
      CodeActionStatus.proposed => ('', Colors.transparent, null),
      CodeActionStatus.running => (
          l10n.codeActionRunning,
          FluxColors.mutedOf(context),
          SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: FluxColors.mutedOf(context),
            ),
          ),
        ),
      CodeActionStatus.done => (
          l10n.codeActionDone,
          FluxColors.successOf(context),
          FluxIcon(
            icon: FluxIcons.check,
            size: 16,
            color: FluxColors.successOf(context),
          ),
        ),
      CodeActionStatus.failed => (
          action.timedOut
              ? l10n.codeActionTimedOut
              : (action.isShell && action.exitCode != null
                  ? l10n.codeActionFailedExit('${action.exitCode}')
                  : l10n.codeActionFailed),
          FluxColors.destructiveOf(context),
          FluxIcon(
            icon: FluxIcons.error,
            size: 16,
            color: FluxColors.destructiveOf(context),
          ),
        ),
      CodeActionStatus.skipped => (
          l10n.codeActionSkipped,
          FluxColors.mutedOf(context),
          null,
        ),
      CodeActionStatus.denied => (
          l10n.codeActionDenied,
          FluxColors.warningOf(context),
          FluxIcon(
            icon: CodeIcons.warning,
            size: 16,
            color: FluxColors.warningOf(context),
          ),
        ),
    };
    if (label.isEmpty) return null;
    return Row(
      key: ValueKey('code-action-status-${action.status.name}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (lead != null) ...[lead, const SizedBox(width: 5)],
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: color, fontSize: 13),
        ),
      ],
    );
  }

  /// Output, or the reason a refused action was refused.
  Widget? _detail(BuildContext context) {
    final l10n = L10n.of(context);
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: FluxColors.secondaryInkOf(context),
        );
    if (action.status == CodeActionStatus.denied) {
      return Text(CodeText.denied(l10n, action), style: style);
    }
    final finished = action.status == CodeActionStatus.done ||
        action.status == CodeActionStatus.failed;
    if (!finished) return null;
    if (!action.isShell) {
      return action.output.isEmpty ? null : Text(action.output, style: style);
    }
    final output = action.output.trimRight();
    if (output.isEmpty) {
      return Text(l10n.codeActionNoOutput, style: style);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.codeActionOutput, style: style),
        const SizedBox(height: 6),
        _CodeBox(
          text: output,
          expanded: _expanded,
          onToggle: () => setState(() => _expanded = !_expanded),
        ),
        if (action.truncated) ...[
          const SizedBox(height: 6),
          Text(l10n.codeActionOutputCut, style: style),
        ],
      ],
    );
  }
}

/// Monospace text in a quiet box, cut to a few lines until tapped.
class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.text,
    required this.expanded,
    required this.onToggle,
    this.prompt = false,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  /// Draws a `$` before the first line, for a command.
  final bool prompt;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final clipped = !expanded && lines.length > CodeActionCard.previewLines;
    final shown =
        clipped ? lines.take(CodeActionCard.previewLines).join('\n') : text;
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.35,
      color: FluxColors.inkOf(context),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: text));
        HapticFeedback.selectionClick();
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(L10n.of(context).commonCopiedToClipboard),
              duration: const Duration(milliseconds: 900),
            ),
          );
      },
      onTap: lines.length > CodeActionCard.previewLines ? onToggle : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: FluxColors.tileOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.sm),
          // Sunk inside the card, so it reads as a well rather than another
          // card: a hairline, not a shadow.
          border: Border.all(color: FluxColors.lineOf(context), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prompt)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: r'$ ',
                      style: style.copyWith(color: FluxColors.mutedOf(context)),
                    ),
                    TextSpan(text: shown),
                  ],
                ),
                style: style,
              )
            else
              // Output keeps its columns (`ls -l`, tables): long lines scroll
              // sideways instead of wrapping into the next row.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(shown, style: style, softWrap: false),
              ),
            if (clipped)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '… +${lines.length - CodeActionCard.previewLines}',
                  style: style.copyWith(color: FluxColors.mutedOf(context)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
