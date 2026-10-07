import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/theme/flux_vivid.dart';
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
    this.color,
    this.gradient,
    this.hitKey,
    this.surfaceKey,
  });

  /// Fills the disc with this sweep instead of [color] while it is not
  /// [dimmed] (the send button once there is something to send).
  final List<Color>? gradient;

  /// The diameter: the composer's circles, the header's buttons and the
  /// sidebar toggle in both apps.
  static const double dimension = 50;

  /// Overrides the fill (the stop control, a voice state).
  final Color? color;

  /// Keys for the tap target and the filled surface, for tests and for
  /// anything that grows out of the button (the "+" sheet).
  final Key? hitKey;
  final Key? surfaceKey;

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
    required IconData icon,
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

  /// A filled disc that is [dimmed] fades too: a bright send button with
  /// only its arrow faded still read as ready in dark mode.
  Color _fill(BuildContext context) {
    final base = color ??
        (dark ? FluxColors.actionOf(context) : FluxColors.controlOf(context));
    if (!dimmed || !(dark || color != null)) return base;
    return Color.alphaBlend(
      base.withValues(alpha: base.a * .38),
      FluxColors.controlOf(context),
    );
  }

  List<Color>? get _sweep => dimmed ? null : gradient;

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
            key: surfaceKey,
            color: _sweep == null ? _fill(context) : Colors.transparent,
            shape: const CircleBorder(),
            child: Ink(
              decoration: _sweep == null
                  ? null
                  : BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _sweep!,
                      ),
                    ),
              child: SizedBox.square(
                key: hitKey,
                dimension: dimension,
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
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
        ),
      );
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.icon, required this.dark});

  final IconData icon;
  final bool dark;

  @override
  Widget build(BuildContext context) => FluxIcon(
        icon: icon,
        size: 24,
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
    this.hue,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Fills the icon's well with this hue and draws the glyph white.
  final FluxHue? hue;
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
                (hue != null && !destructive
                    ? FluxIconWell(hue: hue!, icon: icon)
                    : null) ??
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
              color: FluxColors.mutedOf(context),
            ),
          ],
        ],
      ),
    );
    final card = Material(
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
              // A soft wash rather than the Material ripple: the card dims
              // under the thumb and settles back, the same answer as the
              // circle buttons give.
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
                splashFactory: NoSplash.splashFactory,
                highlightColor:
                    FluxColors.inkOf(context).withValues(alpha: .05),
                child: body,
              ),
            ),
    );
    return onTap == null ? card : FluxPressScale(scale: .985, child: card);
  }
}

/// The design's 54x32 switch: `#414141` when on, a quiet neutral when off.
///
/// The knob stretches toward its destination while pressed and settles with
/// a little overshoot, and casts a soft shadow so it reads as a part on top of
/// the track rather than a hole in it.
class FinnSwitch extends StatefulWidget {
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
  State<FinnSwitch> createState() => _FinnSwitchState();
}

class _FinnSwitchState extends State<FinnSwitch> {
  bool _pressed = false;

  void _toggle() {
    final onChanged = widget.onChanged;
    if (onChanged == null) return;
    HapticFeedback.lightImpact();
    onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final enabled = widget.onChanged != null;
    final dark = FluxColors.isDark(context);
    final onColor = FluxColors.actionOf(context);
    final offColor = dark ? FluxColors.darkLine : const Color(0xFFE3E3E8);
    final knob = dark ? FluxColors.darkCanvas : Colors.white;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 260);
    // A disabled switch shows where it would be, faded, so "off because the
    // section is off" never reads as "on".
    return Semantics(
      toggled: value,
      label: widget.label,
      enabled: enabled,
      onTap: enabled ? _toggle : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _toggle : null,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedOpacity(
          duration: duration,
          opacity: enabled ? 1 : .45,
          child: SizedBox(
            width: 54,
            height: 48,
            child: Center(
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                width: 54,
                height: 32,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: value ? onColor : offColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AnimatedAlign(
                  duration: duration,
                  curve: Curves.easeOutBack,
                  alignment:
                      value ? Alignment.centerRight : Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: FluxMotion.revealDuration,
                    curve: Curves.easeOutCubic,
                    width: _pressed ? 32 : 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: knob,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withValues(alpha: dark ? .4 : .16),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
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
