import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_icons.dart';

/// A compact pill that reveals supporting detail beneath it.
///
/// Chat replies use it for cited pages and browser steps, so both read as one
/// disclosure affordance instead of two lookalikes. The body is always laid out
/// — clipped to an animated height factor — so its height can be measured the
/// first time it opens.
class FluxDisclosure extends StatefulWidget {
  const FluxDisclosure({
    super.key,
    required this.leading,
    required this.label,
    required this.child,
    this.trailing,
    this.onHeightDelta,
    this.expandLabel,
    this.collapseLabel,
  });

  /// Glyph before [label]: a status spinner or the thing's own mark.
  final Widget leading;

  /// Primary text on the pill.
  final String label;

  /// Optional de-emphasised text after [label], e.g. `+2` or `3 steps`.
  final String? trailing;

  /// Revealed under the pill.
  final Widget child;

  /// Per-frame growth (or shrink) of the revealed area in pixels, so callers
  /// can keep surrounding content anchored while it animates.
  final ValueChanged<double>? onHeightDelta;

  /// Accessibility labels for the two states.
  final String? expandLabel;
  final String? collapseLabel;

  @override
  State<FluxDisclosure> createState() => _FluxDisclosureState();
}

class _FluxDisclosureState extends State<FluxDisclosure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: FluxMotion.modalDuration,
    reverseDuration: FluxMotion.modalDuration,
  )..addListener(_onFrame);

  late final CurvedAnimation _factor = CurvedAnimation(
    parent: _controller,
    curve: FluxMotion.modalCurve,
  );

  final GlobalKey _contentKey = GlobalKey();
  double? _fullHeight;
  double _lastHeight = 0;

  bool get _expanded => _controller.value > 0;

  void _onFrame() {
    final full = _fullHeight;
    if (full == null) return;
    final current = full * _factor.value;
    final delta = current - _lastHeight;
    if (delta == 0) return;
    _lastHeight = current;
    widget.onHeightDelta?.call(delta);
    setState(() {});
  }

  void _toggle() {
    final size = _contentKey.currentContext?.size;
    if (size == null) return;
    _fullHeight = size.height;
    _lastHeight = size.height * _controller.value;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _controller.value = _expanded ? 0 : 1);
    } else if (_controller.isAnimating) {
      _controller.reverse();
    } else if (_controller.isDismissed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant FluxDisclosure oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The revealed area is scaled from a height measured once, in `_toggle`.
    // A caller that swaps its child behind the same message — a reply's
    // sources, replaced by a regenerate — used to keep the stale height for
    // the life of the widget, so the panel opened at the old size and either
    // clipped rows off or left a slab of empty space. Re-measure whenever the
    // child is a different widget.
    if (oldWidget.child == widget.child) return;
    final size = _contentKey.currentContext?.size;
    if (size == null || size.height == _fullHeight) return;
    _fullHeight = size.height;
    setState(() {});
  }

  @override
  void dispose() {
    _factor.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = FluxColors.mutedOf(context);
    final trailing = widget.trailing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: _expanded
              ? widget.collapseLabel ?? widget.label
              : widget.expandLabel ?? widget.label,
          onTap: _toggle,
          excludeSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: FluxMotion.minTapTarget,
              minHeight: FluxMotion.minTapTarget,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(FluxRadius.pill),
              child: InkWell(
                onTap: _toggle,
                borderRadius: BorderRadius.circular(FluxRadius.pill),
                child: Align(
                  widthFactor: 1,
                  heightFactor: 1,
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
                    decoration: BoxDecoration(
                      color: FluxColors.disclosureOf(context),
                      borderRadius: BorderRadius.circular(FluxRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        widget.leading,
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: FluxColors.inkOf(context),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12.5,
                                ),
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            trailing,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: muted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: _expanded ? 0.25 : 0.0,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : FluxMotion.revealDuration,
                          curve: FluxMotion.revealCurve,
                          child: FluxIcon(
                            icon: FluxIcons.arrowRight01,
                            size: 14,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // The list is always laid out (so its full height can be measured)
        // but clipped to the animated height factor: it grows downward from
        // the button without a card background. Semantics are excluded while
        // collapsed so the hidden rows are not announced.
        ExcludeSemantics(
          excluding: !_expanded,
          child: ClipRect(
            child: Align(
              heightFactor: _factor.value,
              alignment: Alignment.topCenter,
              child: Column(
                key: _contentKey,
                mainAxisSize: MainAxisSize.min,
                children: [widget.child],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A row inside a [FluxDisclosure]: a leading mark, a title, an optional second
/// line. Tappable — and showing its chevron — only when [onTap] is given, so an
/// informational row never looks actionable.
class FluxDisclosureRow extends StatelessWidget {
  const FluxDisclosureRow({
    super.key,
    required this.leading,
    required this.title,
    this.onTap,
    this.subtitle,
    this.titleStyle,
    this.subtitleStyle,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final onTap = this.onTap;
    final radius = BorderRadius.circular(FluxRadius.sm);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              leading,
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle ??
                      Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                FluxIcon(
                  icon: FluxIcons.arrowRight01,
                  size: 13,
                  color: FluxColors.mutedOf(context),
                ),
              ],
            ],
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: subtitleStyle ??
                  Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: FluxColors.mutedOf(context),
                        fontSize: 12,
                        height: 1.3,
                      ),
            ),
          ],
        ],
      ),
    );

    final painted = Container(
      decoration: BoxDecoration(
        color: FluxColors.disclosureRowOf(context),
        borderRadius: radius,
      ),
      child: content,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: onTap == null
          ? painted
          : Semantics(
              button: true,
              label: title,
              onTap: onTap,
              excludeSemantics: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: FluxMotion.minTapTarget,
                  minHeight: FluxMotion.minTapTarget,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: radius,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: radius,
                    child: Align(
                      widthFactor: 1,
                      heightFactor: 1,
                      alignment: Alignment.center,
                      child: painted,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
