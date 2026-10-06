import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_style.dart';
import 'package:finn_ai/src/features/code/ui/code_terminal.dart';
import 'package:finn_ai/src/features/code/ui/code_terminal_page.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The terminal as a panel over the lower part of FinnAI Code: for a quick
/// `ls` or `cat` while the agent's transcript stays in view above it.
/// "Open full screen" moves to [CodeTerminalPage] with the same scrollback.
class CodeTerminalPanel extends StatelessWidget {
  const CodeTerminalPanel({
    super.key,
    required this.services,
    required this.onClose,
    required this.onExpand,
    required this.bottomInset,
  });

  final CodeServices services;
  final VoidCallback onClose;
  final VoidCallback onExpand;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Material(
      key: const ValueKey('code-terminal-panel'),
      color: FluxColors.controlOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        side: BorderSide(color: FluxColors.lineOf(context), width: .5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Drag the handle down to put the panel away.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 250) {
                HapticFeedback.selectionClick();
                onClose();
              }
            },
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FluxColors.lineOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                CodeTerminalBar(
                  title: l10n.codeTerminalTitle,
                  log: services.terminal,
                  trailing: [
                    CodeBarButton(
                      key: const ValueKey('terminal-expand'),
                      icon: CodeIcons.expand,
                      label: l10n.codeTerminalExpand,
                      onTap: onExpand,
                    ),
                    CodeBarButton(
                      key: const ValueKey('terminal-hide'),
                      icon: FluxIcons.close,
                      label: l10n.codeTerminalHide,
                      onTap: onClose,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: CodeTerminalView(
              log: services.terminal,
              autofocus: true,
              header: CodeTerminalIntro(services: services),
              padding: EdgeInsets.fromLTRB(14, 4, 14, 10 + bottomInset),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slides [panel] up from the bottom when [open]. The panel is only built
/// while it is open or on its way out, so a closed terminal costs nothing.
class CodeTerminalSlot extends StatefulWidget {
  const CodeTerminalSlot({
    super.key,
    required this.open,
    required this.height,
    required this.panel,
  });

  final bool open;
  final double height;
  final Widget panel;

  @override
  State<CodeTerminalSlot> createState() => _CodeTerminalSlotState();
}

class _CodeTerminalSlotState extends State<CodeTerminalSlot> {
  late bool _built = widget.open;

  @override
  void didUpdateWidget(covariant CodeTerminalSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open) _built = true;
  }

  @override
  Widget build(BuildContext context) => AnimatedSlide(
        offset: widget.open ? Offset.zero : const Offset(0, 1.05),
        duration: CodeStyle.motion(context, const Duration(milliseconds: 240)),
        curve: widget.open ? Curves.easeOutCubic : Curves.easeInCubic,
        onEnd: () {
          if (!widget.open && mounted) setState(() => _built = false);
        },
        child: IgnorePointer(
          ignoring: !widget.open,
          child: SizedBox(
            height: widget.height,
            child: _built ? widget.panel : const SizedBox.shrink(),
          ),
        ),
      );
}
