import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/src/platform/platform_target.dart';
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
  FinnPageRoute({
    required Widget child,
    this.onSettled,
    bool constrainWidth = true,
  }) : super(
          transitionDuration: FluxMotion.pageDuration,
          reverseTransitionDuration: FluxMotion.pageReverseDuration,
          pageBuilder: (_, __, ___) => _BackKeys(
            child: constrainWidth ? _ReadableColumn(child: child) : child,
          ),
          transitionsBuilder: _transition,
        );

  /// The widest a sub-page is laid out. A settings list stretched across a
  /// 2000 px desktop window is unreadable, so wider windows get a centred
  /// column on the page's own background.
  static const double maxPageWidth = 1000;

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
            // When the next page arrives on top, this one recedes a little
            // the other way: two layers, not one picture replacing another.
            child: SlideTransition(
              position: Tween(
                begin: Offset.zero,
                end: const Offset(-_travel * .45, 0),
              ).animate(CurvedAnimation(
                parent: secondaryAnimation,
                curve: FluxMotion.pageCurve,
                reverseCurve: FluxMotion.pageReverseCurve,
              )),
              child: page,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadableColumn extends StatelessWidget {
  const _ReadableColumn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: FinnPageRoute.maxPageWidth,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Esc and Alt+Left close the page on a desktop, as in any desktop app.
///
/// It listens to the keyboard directly rather than through focus, which is not
/// reliably inside a page that has just opened. It only acts while this page is
/// the one on top (a dialog or sheet above it makes the route not current, so
/// Esc closes that first) and never while text is being edited.
class _BackKeys extends StatefulWidget {
  const _BackKeys({required this.child});

  final Widget child;

  @override
  State<_BackKeys> createState() => _BackKeysState();
}

class _BackKeysState extends State<_BackKeys> {
  @override
  void initState() {
    super.initState();
    if (isDesktop) HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    final keyboard = HardwareKeyboard.instance;
    final escape = event.logicalKey == LogicalKeyboardKey.escape &&
        !keyboard.isAltPressed &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed;
    final altLeft = event.logicalKey == LogicalKeyboardKey.arrowLeft &&
        keyboard.isAltPressed;
    if (!escape && !altLeft) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    final holder = FocusManager.instance.primaryFocus?.context;
    if (holder?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return false;
    }
    Navigator.of(context).maybePop();
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
