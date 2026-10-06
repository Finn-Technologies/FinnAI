import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/shared/config/app_mode.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/flux_surfaces.dart';

/// How far the brand row's reveal has opened, 0 to 1, as a live animation value.
///
/// The sidebar and the switcher both read this one object rather than each
/// keeping their own copy of "is it open". That is not tidiness: when they kept
/// separate values the panel's height snapped to closed on the same frame the
/// reveal was told to collapse, so for the length of the collapse animation the
/// row was 42dp of content inside a 50dp band and overflowed.
class BrandExpansion extends ChangeNotifier {
  BrandExpansion({this.revealHeight = FinnBrandSwitcher.revealHeight});

  final double revealHeight;
  double _progress = 0;

  /// 0 while closed, 1 while fully open, and easing between.
  double get progress => _progress;

  /// The height the reveal currently occupies, in logical pixels. This is what a
  /// sidebar adds to its layout.
  double get height => _progress * revealHeight;

  bool get isOpen => _progress > 0;

  /// Snaps to [open] with no animation — for restoring state, not for taps.
  void set(bool open) {
    final next = open ? 1.0 : 0.0;
    if (_progress == next) return;
    _progress = next;
    notifyListeners();
  }

  /// Animates towards [open], reporting progress on every frame.
  void animate(
    bool open, {
    required TickerProvider vsync,
    required Curve curve,
    required Duration duration,
  }) {
    final controller = AnimationController(
      vsync: vsync,
      duration: duration,
      value: _progress,
    );
    // Eased on the way in, so both the open and the close pass decelerate.
    final eased = CurvedAnimation(parent: controller, curve: curve);
    void listener() {
      _progress = eased.value;
      notifyListeners();
    }

    // Interrupted by the next toggle before it finishes: dispose the old one
    // now, or it ticks forever and its status listener never fires.
    _running?.dispose();
    _running = controller;

    controller.addListener(listener);
    controller.addStatusListener((_) {
      controller.removeListener(listener);
      // Snap to the exact end: a curve's value at t=1 is 1, but leaving the last
      // frame's float in place would leave the sidebar a fraction of a pixel
      // short of its own height forever.
      _progress = open ? 1 : 0;
      notifyListeners();
      if (identical(_running, controller)) _running = null;
      controller.dispose();
    });
    if (open) {
      controller.forward();
    } else {
      controller.reverse();
    }
  }

  /// Stops any running animation where it stands, keeping the current progress.
  void stop() {
    _running?.dispose();
    _running = null;
  }

  AnimationController? _running;
}

/// The brand row at the top of both sidebars: the name of the app you are in,
/// and the way to the other one.
///
/// Tapping the name reveals the other app directly beneath it, as text.
///
/// This used to open a popup menu: two rows inside a filled card, each with an
/// icon and a check. That put a container and two icons between the user and a
/// two-way choice the screen already answers — the name in the row *is* the
/// current app, so only the other one needs listing. The reveal is part of the
/// sidebar rather than a layer floating over it, and the one decorative element
/// it needs — the blurred panel behind the text — carries no colour at all: it
/// only blurs the history scrolling underneath, ramping up from the wordmark
/// downward.
class FinnBrandSwitcher extends StatefulWidget {
  const FinnBrandSwitcher({
    super.key,
    required this.current,
    this.controller,
    this.expansion,
  });

  final FinnAppMode current;

  /// Overridable for tests; the real app has one.
  final AppModeController? controller;

  /// Shared with the sidebar so both move on the same animation.
  ///
  /// Optional, so the switcher still works standalone — but a sidebar that
  /// resizes around it should pass one, or the two will disagree mid-animation.
  final BrandExpansion? expansion;

  /// The wordmark row's own height, and the height the sidebar reserves for it.
  /// Fixed so opening the reveal moves the panel below without moving the
  /// wordmark.
  static const double rowHeight = 50;

  /// The height the reveal adds to the sidebar's layout. Also the reveal panel's
  /// own height, which is what the blur ramp is measured against.
  static const double revealHeight = 50;

  /// The type both the wordmark and the revealed option are set in.
  ///
  /// They are the same string rendered at the same size as two lines of one
  /// heading, so they share one style: the option used to be 4dp smaller and a
  /// step down the text theme, which read as a lesser label rather than the
  /// equal alternative it is.
  static TextStyle? labelStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w400,
            height: 1.2,
            color: FluxColors.inkOf(context),
          );

  @override
  State<FinnBrandSwitcher> createState() => _FinnBrandSwitcherState();
}

class _FinnBrandSwitcherState extends State<FinnBrandSwitcher>
    with TickerProviderStateMixin {
  BrandExpansion? _owned;

  BrandExpansion get _expansion =>
      widget.expansion ?? (_owned ??= BrandExpansion());

  bool get _open => _expansion.isOpen;

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    // Tearing down for an inherited-widget change: the animation must not
    // resume into a shell that is being replaced.
    _owned?.stop();
    super.deactivate();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    final next = !_open;
    if (widget.expansion != null) {
      // Shared: the sidebar reads the same value, so the panel resizes on the
      // same frame the reveal moves.
      _expansion.animate(
        next,
        vsync: this,
        curve: FluxMotion.revealCurve,
        duration: FluxMotion.revealDuration,
      );
    } else {
      _expansion.set(next);
    }
    if (mounted) setState(() {});
  }

  Future<void> _go(FinnAppMode mode) async {
    _toggle();
    await (widget.controller ?? AppModeController.instance).set(mode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final label = widget.current == FinnAppMode.chat
        ? l10n.appBrandFinnAI
        : l10n.appBrandFinnAICode;
    final other = widget.current == FinnAppMode.chat
        ? l10n.appBrandFinnAICode
        : l10n.appBrandFinnAI;
    final otherMode = widget.current == FinnAppMode.chat
        ? FinnAppMode.code
        : FinnAppMode.chat;

    // Fixed height and the reveal below it, so the wordmark does not move when
    // the reveal opens — only the panel grows. Sizing the row from the text
    // would make the column's height depend on the font and overflow the
    // sidebar's band.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: FinnBrandSwitcher.rowHeight,
          child: Semantics(
            button: true,
            expanded: _open,
            label: '$label. ${l10n.appModeSwitchSemantic}',
            excludeSemantics: true,
            child: FluxPressScale(
              scale: .98,
              alignment: Alignment.centerLeft,
              child: InkWell(
                key: const ValueKey('brand-switcher'),
                borderRadius: BorderRadius.circular(FluxRadius.sm),
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FinnBrandSwitcher.labelStyle(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Turns to point back up while the reveal is open, so the
                      // row reads as expanded rather than as a closed menu.
                      AnimatedRotation(
                        turns: _open ? .5 : 0,
                        duration: FluxMotion.revealDuration,
                        curve: FluxMotion.revealCurve,
                        child: FluxIcon(
                          icon: PhosphorIconsFill.caretDown,
                          size: 20,
                          color: FluxColors.mutedOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: _expansion,
          builder: (context, _) => _Reveal(
            progress: _expansion.progress,
            label: other,
            onTap: () => _go(otherMode),
          ),
        ),
      ],
    );
  }
}

/// The other app's name, under the wordmark, over a blurred panel that carries
/// no colour.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.progress,
    required this.label,
    required this.onTap,
  });

  /// 0 closed, 1 open, easing between.
  final double progress;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final height = FinnBrandSwitcher.revealHeight * progress;
    return SizedBox(
      height: height,
      width: double.infinity,
      // Nothing in the tree once closed: an off-screen-but-present option would
      // still be findable, and still take a tap.
      child: progress <= 0
          ? null
          : ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: FinnBrandSwitcher.revealHeight,
                maxHeight: FinnBrandSwitcher.revealHeight,
                child: SizedBox(
                  height: FinnBrandSwitcher.revealHeight,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: FluxProgressiveBlur(
                          child: SizedBox.expand(),
                        ),
                      ),
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Semantics(
                            button: true,
                            label: label,
                            excludeSemantics: true,
                            child: InkWell(
                              key: const ValueKey('brand-switcher-option'),
                              borderRadius:
                                  BorderRadius.circular(FluxRadius.sm),
                              onTap: onTap,
                              child: Padding(
                                // 8dp of vertical padding around 24dp type
                                // lands the option's baseline on the same
                                // rhythm as the wordmark's above it, so the two
                                // read as one heading split over two lines.
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 8,
                                ),
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: FinnBrandSwitcher.labelStyle(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
