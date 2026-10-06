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
                      fontFamily: 'Geist',
                      fontSize: 18,
                      height: 1.2,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
            // A title that just fits must not touch the button.
            if (onNewChat != null) const SizedBox(width: 12),
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
          child: _WordReveal(
            key: ValueKey(greeting),
            text: greeting,
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 26,
              height: 1.2,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.7,
            ),
          ),
        ),
      );
}

/// [text] arriving rather than appearing: a soft edge sweeps across it from
/// the start of the line while it comes up out of a blur, so a greeting is
/// said rather than printed. Still one `Text`; reduced motion shows it at
/// once.
class _WordReveal extends StatefulWidget {
  const _WordReveal({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_WordReveal> createState() => _WordRevealState();
}

class _WordRevealState extends State<_WordReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (_controller.value == 0 && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(
      widget.text,
      textAlign: TextAlign.center,
      style: widget.style,
    );
    return AnimatedBuilder(
      animation: _controller,
      child: text,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        if (t >= 1) return child!;
        final rtl = Directionality.of(context) == TextDirection.rtl;
        // The edge travels from before the start to past the end.
        final edge = -.3 + 1.6 * t;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
            end: rtl ? Alignment.centerLeft : Alignment.centerRight,
            colors: const [Colors.white, Color(0x00FFFFFF)],
            stops: [(edge - .3).clamp(0.0, 1.0), edge.clamp(0.0, 1.0)],
          ).createShader(bounds),
          child: Transform.translate(
            offset: Offset(0, 6 * (1 - t)),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 5 * (1 - t),
                sigmaY: 5 * (1 - t),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
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
