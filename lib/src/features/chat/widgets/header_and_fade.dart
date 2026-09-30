part of '../home_shell.dart';

/// The screen's top row: the menu (and close) control on the left, the
/// conversation title beside it, and the new-chat control on the right while a
/// conversation is on screen — exactly the arrangement in the design.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.onMenu,
    this.title,
    this.onNewChat,
  });

  final VoidCallback onMenu;

  /// Conversation title; null on the empty screen and while listening.
  final String? title;

  /// Starts a new conversation; null hides the control.
  final VoidCallback? onNewChat;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          Tooltip(
            message: L10n.of(context).chatOpenMenuTooltip,
            child: Semantics(
              button: true,
              label: L10n.of(context).chatOpenMenuTooltip,
              onTap: onMenu,
              excludeSemantics: true,
              child: FluxPressScale(
                child: Material(
                  color: FluxColors.controlOf(context),
                  shape: const CircleBorder(),
                  child: SizedBox.square(
                    key: const ValueKey('home-menu-button'),
                    dimension: 50,
                    child: InkWell(
                      onTap: onMenu,
                      customBorder: const CircleBorder(),
                      child: const Center(
                        child: FigmaSvg(
                          asset: FigmaAssets.appMenu,
                          width: 25,
                          height: 25,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (title != null && title.isNotEmpty) ...[
            const SizedBox(width: 20),
            Expanded(
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

/// Height of the chat's top scroll-fade band, in logical pixels.
///
/// Declared once because the gradient's opaque stretch is a fraction of it:
/// the band and the gradient stops have to stay in step.
const double _chatTopFadeHeight = 210;

/// Depth of the fully opaque stretch at the top of the fade band.
///
/// The brand row must stay readable while messages scroll beneath it, so the
/// fade is opaque wherever the header can sit. `_HomeHeader` is 50 tall at
/// `top: 71 * sy`, and `sy` is clamped to 1.08, so its bottom edge reaches
/// (71 + 50) * 1.08 ≈ 130.7.
const double _chatTopFadeOpaqueDepth = 134;

/// A static soft-edge fade that sits over the scrolling chat list so messages
/// appear to slide beneath the header at the top and fade into the very bottom
/// edge of the screen below the composer. It replaces the old progressive
/// backdrop blur with a plain gradient — effectively free per scroll frame.
/// The header and composer are drawn above these fades in the shell Stack, so
/// they stay crisp and tappable.
///
/// The top band is *fully* opaque across the brand row and only then ramps to
/// transparent. At anything less than opaque, scrolled message text stays
/// legible straight through the app title, which reads as a rendering fault
/// rather than as depth. The bottom band has no content drawn over it, so it
/// keeps the softer profile that lets the last row dissolve into the composer.
class _ChatEdgeFade extends StatelessWidget {
  const _ChatEdgeFade({super.key, required this.top});

  /// True for the fade under the header at the top of the screen, false for
  /// the fade hugging the very bottom edge of the screen.
  final bool top;

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    final color = isDark ? FluxColors.darkCanvas : FluxColors.canvas;
    final stops = top
        ? const <double>[
            0.0,
            _chatTopFadeOpaqueDepth / _chatTopFadeHeight,
            0.80,
            1.0,
          ]
        : const <double>[0.0, 0.35, 0.7, 1.0];
    final colors = top
        ? <Color>[
            // Opaque across the brand row; the ramp starts below it.
            color,
            color,
            color.withValues(alpha: 0.42),
            color.withValues(alpha: 0.0),
          ]
        : <Color>[
            color.withValues(alpha: 0.93),
            color.withValues(alpha: 0.64),
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.0),
          ];
    return DecoratedBox(
      decoration: BoxDecoration(
        // Progressive: mostly transparent across the band and easing smoothly
        // to near-opaque only at the screen edge, so there is no hard line.
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          stops: stops,
          colors: colors,
        ),
      ),
      child: const SizedBox.expand(),
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
