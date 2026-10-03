import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// The shared transition for full-screen sub-pages.
///
/// One motion for every page, so a push never feels like a different app from
/// screen to screen. It is a fade-through with a short horizontal travel:
///
/// * the incoming page rises out of a solid backdrop, so whatever it covers
///   (the chat, an open sidebar) is hidden within the first third of the push
///   and is never seen blending through the new page;
/// * going back runs the same motion in reverse, uncovering the page below
///   immediately instead of fading to a blank canvas first.
///
/// Public so creations, decks and mini-app hosts push with the same motion as
/// the sidebar destinations rather than each defining their own.
class FinnPageRoute<T> extends PageRouteBuilder<T> {
  FinnPageRoute({required Widget child, this.onSettled})
      : super(
          transitionDuration: FluxMotion.pageDuration,
          reverseTransitionDuration: FluxMotion.pageReverseDuration,
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: _transition,
        );

  /// Called once the page has finished arriving (or the push was cancelled).
  ///
  /// The sidebar uses it to close itself *behind* the new page, so choosing a
  /// destination is one motion instead of "close the panel, then open a page".
  final VoidCallback? onSettled;

  @override
  TickerFuture didPush() {
    final settled = super.didPush();
    final callback = onSettled;
    if (callback != null) settled.whenCompleteOrCancel(callback);
    return settled;
  }

  /// How far the incoming page travels, as a fraction of its own width.
  static const double _travel = .07;

  static Widget _transition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget page,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return page;

    final slide = CurvedAnimation(
      parent: animation,
      curve: FluxMotion.pageCurve,
      reverseCurve: FluxMotion.pageReverseCurve,
    );
    // Forward: solid within the first third. Reverse: clear within the first
    // 40%, so the page underneath is uncovered while this one is still moving.
    final backdrop = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, .32, curve: Curves.easeOut),
      reverseCurve: const Interval(.6, 1, curve: Curves.easeIn),
    );
    final content = CurvedAnimation(
      parent: animation,
      curve: const Interval(.1, .65, curve: Curves.easeOut),
      reverseCurve: const Interval(0, .5, curve: Curves.easeIn),
    );

    // The page underneath is left alone: moving or fading it would let the
    // route below *it* show through for a few frames, which is the flicker
    // this transition exists to remove.
    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: backdrop,
          child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        ),
        FadeTransition(
          opacity: content,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(_travel, 0),
              end: Offset.zero,
            ).animate(slide),
            child: page,
          ),
        ),
      ],
    );
  }
}
