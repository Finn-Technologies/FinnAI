import 'package:flutter/material.dart';

/// The shared slide-and-fade transition for full-screen sub-pages.
///
/// Public so creations, decks and mini-app hosts push with the same motion as
/// the sidebar destinations rather than each defining their own.
class FinnPageRoute<T> extends PageRouteBuilder<T> {
  FinnPageRoute({required Widget child})
      : super(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, page) {
            if (MediaQuery.disableAnimationsOf(context)) return page;
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubicEmphasized,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(.08, 0),
                  end: Offset.zero,
                ).animate(curved),
                // A hair of scale gives the incoming page depth, so it reads
                // as arriving from behind the current one instead of sliding
                // flat over it. Anchored to the edge it slides from.
                child: ScaleTransition(
                  scale: Tween<double>(begin: .985, end: 1).animate(curved),
                  alignment: Alignment.centerRight,
                  child: page,
                ),
              ),
            );
          },
        );
}
