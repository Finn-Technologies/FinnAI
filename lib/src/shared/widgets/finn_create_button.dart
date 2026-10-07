import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_morph_sheet.dart';
import 'package:finn_ai/src/shared/widgets/flux_icons.dart';
import 'package:finn_ai/src/shared/widgets/flux_motion.dart';

/// The one way to make something new on a list screen: a 50dp "+" centred at
/// the bottom, where a thumb rests. Creations started it; Flows and You use
/// the same control in the same place, so "new" is never hunted for in a
/// header. Put it in a page's `footer`.
class FinnCreateButton extends StatefulWidget {
  const FinnCreateButton({
    super.key,
    required this.label,
    this.onTap,
    this.onTapFrom,
  }) : assert(onTap != null || onTapFrom != null);

  /// What it makes, for screen readers and the tooltip: "New flow".
  final String label;
  final VoidCallback? onTap;

  /// Like [onTap], with the button's on-screen rectangle, so a sheet can grow
  /// out of it (`showFinnSheet(origin: …)`).
  final ValueChanged<Rect?>? onTapFrom;

  static const double dimension = 50;

  @override
  State<FinnCreateButton> createState() => _FinnCreateButtonState();
}

class _FinnCreateButtonState extends State<FinnCreateButton>
    with SingleTickerProviderStateMixin {
  final _surface = GlobalKey();

  // Settles in with a small overshoot when the page appears.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _enter.value = 1;
      } else {
        _enter.forward();
      }
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  void _tap() {
    HapticFeedback.lightImpact();
    widget.onTap?.call();
    widget.onTapFrom?.call(globalRectOf(_surface));
  }

  @override
  Widget build(BuildContext context) {
    // A beat after the page, then a small overshoot.
    final scale = CurvedAnimation(
      parent: _enter,
      curve: const Interval(.2, 1, curve: ElasticOutCurve(.7)),
    );
    final fade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(.2, .6, curve: Curves.easeOut),
    );
    return Center(
      heightFactor: 1,
      child: Tooltip(
        message: widget.label,
        child: Semantics(
          button: true,
          label: widget.label,
          onTap: _tap,
          excludeSemantics: true,
          child: FadeTransition(
            opacity: fade,
            child: ScaleTransition(
              scale: Tween<double>(begin: .6, end: 1).animate(scale),
              child: FluxPressScale(
                child: Material(
                  key: _surface,
                  color: FluxColors.controlOf(context),
                  shape: CircleBorder(
                    side: BorderSide(
                      color: FluxColors.lineOf(context),
                      width: .5,
                    ),
                  ),
                  child: InkWell(
                    onTap: _tap,
                    customBorder: const CircleBorder(),
                    child: SizedBox.square(
                      key: const ValueKey('finn-create-button'),
                      dimension: FinnCreateButton.dimension,
                      child: Center(
                        child: FluxIcon(
                          icon: FluxIcons.add,
                          size: 24,
                          color: FluxColors.inkOf(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
