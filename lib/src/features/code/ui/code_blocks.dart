import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/ui/code_diff_view.dart';
import 'package:finn_ai/src/features/code/ui/code_style.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// A command and what it printed, in one monospace well. Long output is
/// clipped to [maxLines] with a "show more" row; long-press copies.
class CodeOutputBlock extends StatefulWidget {
  const CodeOutputBlock({
    super.key,
    required this.command,
    required this.output,
    this.truncated = false,
    this.maxLines = 12,
    this.exitCode,
    this.timedOut = false,
    this.tail = false,
  });

  final String command;
  final String output;
  final bool truncated;
  final int maxLines;

  /// Shown after the output when the command failed.
  final int? exitCode;
  final bool timedOut;

  /// Live output: show the newest [maxLines], not the first.
  final bool tail;

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
    final shown = !clipped
        ? widget.output
        : (widget.tail
            ? lines.skip(lines.length - widget.maxLines).join('\n')
            : lines.take(widget.maxLines).join('\n'));

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
                    ] else if (widget.output.isEmpty && !widget.tail)
                      Text(l10n.codeActionNoOutput,
                          style: CodeStyle.meta(context)),
                    if (widget.truncated)
                      Text(l10n.codeActionOutputCut,
                          style: CodeStyle.meta(context)),
                    if (widget.timedOut || widget.exitCode != null)
                      Text(
                        widget.timedOut
                            ? l10n.codeActionTimedOut
                            : l10n.codeExitCode('${widget.exitCode}'),
                        style: CodeStyle.meta(
                          context,
                          color: FluxColors.destructiveOf(context),
                        ),
                      ),
                  ],
                ),
              ),
              if (lines.length > widget.maxLines && !widget.tail)
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
