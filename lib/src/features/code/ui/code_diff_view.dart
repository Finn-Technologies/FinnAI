import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/ui/code_style.dart';
import 'package:finn_ai/src/features/code/ui/line_diff.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// What a write or an edit did to a file: removed lines on red, added on
/// green, each with its sign and line number, unchanged runs folded.
///
/// A new file is all additions; [maxLines] clips it (and any long diff) with
/// a "show more" row so a big file never floods the transcript.
class CodeDiffView extends StatefulWidget {
  const CodeDiffView({
    super.key,
    required this.lines,
    this.maxLines = 14,
  });

  final List<DiffLine> lines;
  final int maxLines;

  @override
  State<CodeDiffView> createState() => _CodeDiffViewState();
}

class _CodeDiffViewState extends State<CodeDiffView> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final rows = LineDiff.hunks(widget.lines);
    final clipped = !_all && rows.length > widget.maxLines;
    final shown = clipped ? rows.take(widget.maxLines).toList() : rows;
    final style = CodeStyle.code(context);
    final digits = '${widget.lines.length}'.length;
    final numberWidth = 7.4 * digits + 6;

    return ClipRRect(
      borderRadius: BorderRadius.circular(CodeStyle.radius - 2),
      child: ColoredBox(
        color: CodeStyle.wellOf(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Long lines scroll sideways as one block, so the columns of a
            // diff stay aligned instead of wrapping into each other.
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final row in shown)
                          if (row is DiffLine)
                            _Line(
                              line: row,
                              style: style,
                              numberWidth: numberWidth,
                            )
                          else
                            _Gap(
                              text: l10n.codeUnchangedLines(
                                  '${(row as DiffGap).lines}'),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (rows.length > widget.maxLines)
              CodeMoreRow(
                label: _all
                    ? l10n.codeShowLess
                    : l10n
                        .codeShowMoreLines('${rows.length - widget.maxLines}'),
                onTap: () => setState(() => _all = !_all),
              ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.line,
    required this.style,
    required this.numberWidth,
  });

  final DiffLine line;
  final TextStyle style;
  final double numberWidth;

  @override
  Widget build(BuildContext context) {
    final (Color? fill, Color signColor, String sign) = switch (line.op) {
      DiffOp.added => (
          CodeStyle.addedOf(context),
          CodeStyle.addedSignOf(context),
          '+'
        ),
      DiffOp.removed => (
          CodeStyle.removedOf(context),
          CodeStyle.removedSignOf(context),
          '−'
        ),
      DiffOp.same => (null, FluxColors.mutedOf(context), ' '),
    };
    final number = line.newLine ?? line.oldLine;
    return Container(
      color: fill,
      padding: const EdgeInsets.only(right: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: numberWidth,
            child: Text(
              number == null ? '' : '$number',
              textAlign: TextAlign.right,
              style: style.copyWith(color: FluxColors.mutedOf(context)),
            ),
          ),
          SizedBox(
            width: 18,
            child: Text(
              sign,
              textAlign: TextAlign.center,
              style: style.copyWith(color: signColor),
            ),
          ),
          Text(
            line.text.isEmpty ? ' ' : line.text,
            softWrap: false,
            style: line.op == DiffOp.same
                ? style.copyWith(color: FluxColors.secondaryInkOf(context))
                : style,
          ),
        ],
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text('⋯ $text', style: CodeStyle.meta(context)),
      );
}

/// The quiet full-width "show more / show less" control under a clipped
/// block of code or output.
class CodeMoreRow extends StatelessWidget {
  const CodeMoreRow({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 28,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: FluxColors.lineOf(context), width: .5),
              ),
            ),
            child: Text(label, style: CodeStyle.meta(context)),
          ),
        ),
      );
}
