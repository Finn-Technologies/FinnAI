import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The design's 50dp circular control: white on the canvas, dark glyph.
///
/// [dark] flips it to the filled `#414141` variant used for send and voice.
class FinnCircleButton extends StatelessWidget {
  const FinnCircleButton({
    super.key,
    required this.glyph,
    required this.label,
    required this.onTap,
    this.dark = false,
    this.dimmed = false,
  });

  /// A 24-25dp glyph; see [FinnCircleButton.icon] for the common case.
  final Widget glyph;
  final String label;
  final VoidCallback? onTap;
  final bool dark;

  /// A control that is present but not yet actionable — a send button with an
  /// empty field. The glyph stays legible; the whole disc sits back so the two
  /// states are told apart without the affordance disappearing.
  final bool dimmed;

  factory FinnCircleButton.icon({
    Key? key,
    required List<List<dynamic>> icon,
    required String label,
    required VoidCallback? onTap,
    bool dark = false,
    bool dimmed = false,
  }) =>
      FinnCircleButton(
        key: key,
        glyph: _Glyph(icon: icon, dark: dark),
        label: label,
        onTap: onTap,
        dark: dark,
        dimmed: dimmed,
      );

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: FluxPressScale(
          enabled: onTap != null,
          child: Material(
            color: dark
                ? FluxColors.actionOf(context)
                : FluxColors.controlOf(context),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox.square(
                dimension: 50,
                child: Center(
                  child: Opacity(
                    opacity: dimmed ? .38 : 1,
                    child: glyph,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.icon, required this.dark});

  final List<List<dynamic>> icon;
  final bool dark;

  @override
  Widget build(BuildContext context) => FluxIcon(
        icon: icon,
        size: 24,
        strokeWidth: 1.5,
        color:
            dark ? FluxColors.canvasOf(context) : FluxColors.actionOf(context),
      );
}

/// A settings-style row card: white, 20dp radius, a 44dp tinted icon circle,
/// a 16dp title with a 14dp caption, and a trailing chevron or custom widget.
class FinnTile extends StatelessWidget {
  const FinnTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.chevron = true,
  });

  final String title;
  final String? subtitle;
  final List<List<dynamic>>? icon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  /// Whether to show the chevron when [onTap] is set and [trailing] is not.
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final titleColor = destructive
        ? FluxColors.destructiveOf(context)
        : FluxColors.inkOf(context);
    final radius = BorderRadius.circular(FluxRadius.card);
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          if (leading != null || icon != null) ...[
            leading ??
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: FluxColors.tileOf(context),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: FluxIcon(
                    icon: icon!,
                    size: 22,
                    strokeWidth: 1.5,
                    color: destructive
                        ? FluxColors.destructiveOf(context)
                        : FluxColors.actionOf(context),
                  ),
                ),
            const SizedBox(width: 15),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.bodyMedium?.copyWith(color: titleColor)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.bodySmall?.copyWith(
                      color: FluxColors.secondaryInkOf(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ] else if (onTap != null && chevron) ...[
            const SizedBox(width: 10),
            FluxIcon(
              icon: FluxIcons.arrowRight01,
              size: 22,
              strokeWidth: 1.5,
              color: FluxColors.mutedOf(context),
            ),
          ],
        ],
      ),
    );
    return Material(
      color: FluxColors.controlOf(context),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : Semantics(
              button: true,
              label: title,
              onTap: onTap,
              excludeSemantics: true,
              child: InkWell(onTap: onTap, child: body),
            ),
    );
  }
}

/// The design's 54x32 switch: `#414141` when on, a soft lilac-grey when off.
class FinnSwitch extends StatelessWidget {
  const FinnSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final onColor = FluxColors.actionOf(context);
    final offColor = FluxColors.isDark(context)
        ? FluxColors.darkLine
        : const Color(0xFFE6E0E9);
    final knob =
        FluxColors.isDark(context) ? FluxColors.darkCanvas : Colors.white;
    return Semantics(
      toggled: value,
      label: label,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: SizedBox(
          width: 54,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: FluxMotion.revealDuration,
              curve: FluxMotion.revealCurve,
              width: 54,
              height: 32,
              decoration: BoxDecoration(
                color: value ? onColor : offColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedAlign(
                duration: FluxMotion.revealDuration,
                curve: Curves.easeOutBack,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: DecoratedBox(
                    decoration:
                        BoxDecoration(color: knob, shape: BoxShape.circle),
                    child: const SizedBox.square(dimension: 26),
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

/// Fades and lifts its child in once, staggered by [index].
///
/// The one entrance animation: list rows, cards and empty states all use it so
/// pages arrive the same way. It does nothing under reduced motion.
class FinnReveal extends StatefulWidget {
  const FinnReveal({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<FinnReveal> createState() => _FinnRevealState();
}

class _FinnRevealState extends State<FinnReveal>
    with SingleTickerProviderStateMixin {
  static const _run = 360;

  /// The stagger is part of one longer animation rather than a delayed start,
  /// so there is no timer to outlive the widget.
  late final int _delay = 45 * widget.index.clamp(0, 8);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _run + _delay),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _delay / (_run + _delay),
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        alwaysIncludeSemantics: true,
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - _curve.value)),
          child: child,
        ),
      ),
    );
  }
}
