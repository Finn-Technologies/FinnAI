part of '../home_shell.dart';

/// The screen's top row: the shared [FinnShellHeader] with the new-chat
/// button, the same row FinnAI Code uses.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    this.title,
    this.onNewChat,
    this.onTitleTap,
    this.showMenuSlot = true,
  });

  final bool showMenuSlot;

  /// Conversation title; null on the empty screen and while listening.
  final String? title;

  /// Starts a new conversation; null hides the control.
  final VoidCallback? onNewChat;

  /// Opens the chat's options; null leaves the title inert.
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) => FinnShellHeader(
        showMenuSlot: showMenuSlot,
        title: title,
        onTitleTap: onTitleTap,
        action: onNewChat == null
            ? null
            : FinnCircleButton(
                hitKey: const ValueKey('home-new-chat-button'),
                label: L10n.of(context).chatNewChat,
                onTap: onNewChat,
                glyph: const FigmaSvg(
                  asset: FigmaAssets.appNewChat,
                  width: 25,
                  height: 25,
                ),
              ),
      );
}

/// Cold-start welcome shown when the active conversation has no messages yet:
/// the greeting alone, centred on the screen — no chips, no brand mark.
class _ConversationEmpty extends StatelessWidget {
  const _ConversationEmpty({required this.greeting});

  /// The design greets a listening session differently from a typed one.
  final String greeting;

  @override
  Widget build(BuildContext context) => FinnGreeting(text: greeting);
}

/// The ambient green wash under an empty chat. It belongs to the empty state
/// only: once a conversation has messages the canvas is flat, as in the
/// design's chat screens. Resolved per theme: the light wash is a soft green
/// over a near-white canvas, and the same 25% green on #18181C reads as a
/// lurid glow rather than depth.
class _AmbientWash extends StatelessWidget {
  const _AmbientWash({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: height,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: FluxColors.ambientWashOf(context),
              ),
            ),
          ),
        ),
      );
}
