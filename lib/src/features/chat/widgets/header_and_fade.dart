part of '../home_shell.dart';

/// The screen's top row: the conversation title beside the control slot, and
/// the new-chat control on the right while a conversation is on screen.
///
/// The menu/close control itself is *not* here — it is drawn by the sidebar
/// overlay so it can stay above the scrim and morph as the panel opens. This
/// row keeps its [menuSlotWidth] so the title does not shift under it.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    this.title,
    this.onNewChat,
    this.onTitleTap,
    this.showMenuSlot = true,
  });

  /// False when the sidebar is docked: there is no toggle to leave room for.
  final bool showMenuSlot;

  /// Width the menu/close control occupies at the row's start.
  static const double menuSlotWidth = FinnSidebarToggleButton.dimension;

  /// Conversation title; null on the empty screen and while listening.
  final String? title;

  /// Starts a new conversation; null hides the control.
  final VoidCallback? onNewChat;

  /// Opens the chat's options; null leaves the title inert.
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return SizedBox(
      height: 50,
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
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'InstrumentSans',
                      fontSize: 18,
                      height: 1.2,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ] else
            const Spacer(),
          if (onNewChat != null)
            Semantics(
              button: true,
              label: L10n.of(context).chatNewChat,
              onTap: onNewChat,
              excludeSemantics: true,
              child: FluxPressScale(
                child: Material(
                  color: FluxColors.controlOf(context),
                  shape: const CircleBorder(),
                  child: SizedBox.square(
                    key: const ValueKey('home-new-chat-button'),
                    dimension: 50,
                    child: InkWell(
                      onTap: onNewChat,
                      customBorder: const CircleBorder(),
                      child: const Center(
                        child: FigmaSvg(
                          asset: FigmaAssets.appNewChat,
                          width: 25,
                          height: 25,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cold-start welcome shown when the active conversation has no messages yet:
/// the greeting alone, centred on the screen — no chips, no brand mark.
class _ConversationEmpty extends StatelessWidget {
  const _ConversationEmpty({required this.greeting});

  /// The design greets a listening session differently from a typed one.
  final String greeting;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Text(
            greeting,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'InstrumentSans',
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
}
