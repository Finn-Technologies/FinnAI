import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/widgets/finn_sidebar_surface.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';

/// The top row of a shell, FinnAI's chat or FinnAI Code: the slot the
/// sidebar toggle is drawn in, the title of what is on screen, and the
/// "start again" button on the right.
///
/// The menu/close control itself is not here: the sidebar overlay draws it so
/// it can stay above the scrim and morph as the panel opens. This row keeps
/// its slot so the title does not shift under it.
class FinnShellHeader extends StatelessWidget {
  const FinnShellHeader({
    super.key,
    this.title,
    this.titleKey,
    this.onTitleTap,
    this.action,
    this.showMenuSlot = true,
  });

  /// What is on screen; null on an empty screen.
  final String? title;
  final Key? titleKey;

  /// Opens the options of what is on screen; null leaves the title inert.
  final VoidCallback? onTitleTap;

  /// The right-hand button (new chat, new session), usually a
  /// [FinnCircleButton]; null hides it.
  final Widget? action;

  /// False when the sidebar is docked: there is no toggle to leave room for.
  final bool showMenuSlot;

  /// Width the menu/close control occupies at the row's start.
  static const double menuSlotWidth = FinnSidebarToggleButton.dimension;

  static const double height = FinnCircleButton.dimension;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final action = this.action;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          if (showMenuSlot) const SizedBox(width: menuSlotWidth),
          if (title != null && title.isNotEmpty) ...[
            if (showMenuSlot) const SizedBox(width: 20),
            Expanded(
              child: Semantics(
                button: onTitleTap != null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTitleTap,
                  // The whole row height is the target, not just the line.
                  child: SizedBox(
                    height: height,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        title,
                        key: titleKey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 18,
                          height: 1.2,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // A title that just fits must not touch the button.
            if (action != null) const SizedBox(width: 12),
          ] else
            const Spacer(),
          if (action != null) action,
        ],
      ),
    );
  }
}
