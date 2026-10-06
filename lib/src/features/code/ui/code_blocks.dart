import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/ui/code_diff_view.dart';
import 'package:finn_ai/src/features/code/ui/code_style.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// A command and what it printed, in one monospace well. Long output is
/// clipped to [maxLines] with a "show more" row; long-press copies.
class CodeOutputBlock extends StatefulWidget {
  const CodeOutputBlock({
    super.key,
    required this.command,
    required this.output,
    this.truncated = false,
    this.maxLines = 12,
  });

  final String command;
  final String output;
  final bool truncated;
  final int maxLines;

  @override
  State<CodeOutputBlock> createState() => _CodeOutputBlockState();
}

class _CodeOutputBlockState extends State<CodeOutputBlock> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final style = CodeStyle.code(context);
    final muted = FluxColors.mutedOf(context);
    final lines =
        widget.output.isEmpty ? <String>[] : widget.output.split('\n');
    final clipped = !_all && lines.length > widget.maxLines;
    final shown =
        clipped ? lines.take(widget.maxLines).join('\n') : widget.output;

    return GestureDetector(
      onLongPress: () => copyWithNotice(
        context,
        '\$ ${widget.command}\n${widget.output}',
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CodeStyle.radius - 2),
        child: ColoredBox(
          color: CodeStyle.wellOf(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: r'$ ', style: style.copyWith(color: muted)),
                        TextSpan(text: widget.command),
                      ]),
                      style: style,
                    ),
                    if (shown.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      // Output keeps its columns (`ls -l`, tables): long
                      // lines scroll sideways instead of wrapping.
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: Text(
                          shown,
                          softWrap: false,
                          style: style.copyWith(
                            color: FluxColors.secondaryInkOf(context),
                          ),
                        ),
                      ),
                    ] else if (widget.output.isEmpty)
                      Text(l10n.codeActionNoOutput,
                          style: CodeStyle.meta(context)),
                    if (widget.truncated)
                      Text(l10n.codeActionOutputCut,
                          style: CodeStyle.meta(context)),
                  ],
                ),
              ),
              if (lines.length > widget.maxLines)
                CodeMoreRow(
                  label: _all
                      ? l10n.codeShowLess
                      : l10n.codeShowMoreLines(
                          '${lines.length - widget.maxLines}'),
                  onTap: () => setState(() => _all = !_all),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Copies [text] and says so briefly.
void copyWithNotice(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  HapticFeedback.selectionClick();
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(L10n.of(context).commonCopiedToClipboard),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// A 30dp pill button for inline decisions.
class CodeSmallButton extends StatelessWidget {
  const CodeSmallButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fill =
        primary ? FluxColors.actionOf(context) : FluxColors.controlOf(context);
    final ink =
        primary ? FluxColors.canvasOf(context) : FluxColors.inkOf(context);
    return Semantics(
      button: true,
      child: FluxPressScale(
        child: Material(
          color: fill,
          shape: StadiumBorder(
            side: primary
                ? BorderSide.none
                : BorderSide(color: FluxColors.lineOf(context)),
          ),
          child: InkWell(
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
            customBorder: const StadiumBorder(),
            child: ConstrainedBox(
              // The pill is 30dp; the touch target stays 48dp wide enough
              // through its padding and row spacing.
              constraints: const BoxConstraints(minHeight: 32, minWidth: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      FluxIcon(icon: icon!, size: 13, color: ink),
                      const SizedBox(width: 5),
                    ],
                    Text(label, style: CodeStyle.label(context, color: ink)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
