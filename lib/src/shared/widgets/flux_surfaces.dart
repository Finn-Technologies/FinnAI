import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The one treatment for a surface that stays on screen.
///
/// Shadows render differently per GPU and disappear entirely on near-black
/// fills, so every permanent raised surface — the composer pill, chat bubbles,
/// the action and error cards — separates from what is behind it with fill plus
/// a 1px hairline. Only transient surfaces (sheets, menus, the sidebar scrim)
/// use [FluxColors.elevationShadow].
///
/// This exists so a screen cannot reintroduce a drop shadow on a permanent
/// surface by hand-rolling a `BoxDecoration`: FinnAI Code's composer pill and
/// action card each carried their own, and in dark mode `elevationOf` returns
/// near-white, so they rendered as a pale halo around a grey slab instead of a
/// hairline — the exact failure the palette was rebuilt to remove.
abstract final class FluxSurfaces {
  /// Fill plus a 1px hairline, no shadow. [color] defaults to [controlOf], the
  /// fill of the raised controls; pass [FluxColors.cardOf] for a card.
  static BoxDecoration flat(
    BuildContext context, {
    required double radius,
    Color? color,
  }) =>
      BoxDecoration(
        color: color ?? FluxColors.controlOf(context),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: FluxColors.lineOf(context), width: 1),
      );

  /// [flat] on the card fill at the design's card radius.
  static BoxDecoration flatCard(
    BuildContext context, {
    double radius = FluxRadius.card,
  }) =>
      flat(context, radius: radius, color: FluxColors.cardOf(context));
}

/// A rounded surface in the raised-control fill, no border. Name kept from the
/// glass era; the design has no blur. New surfaces should use
/// [FluxSurfaces.flat], which also paints the hairline.
class FluxGlass extends StatelessWidget {
  const FluxGlass({
    super.key,
    required this.child,
    this.radius = FluxRadius.card,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final double radius;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? FluxColors.controlOf(context),
          borderRadius: BorderRadius.circular(radius),
          border: borderColor == null ? null : Border.all(color: borderColor!),
        ),
        child: child,
      );
}

/// A panel that blurs what is behind it, ramping up from clear at the top edge
/// to [maxSigma] at the bottom, with no fill of its own.
///
/// Flutter cannot mask a backdrop blur: `ShaderMask` pushes a shader-mask layer,
/// and a `BackdropFilter` nested inside it filters *that layer's* contents, which
/// are empty — so the obvious `ShaderMask` + `BackdropFilter` pair renders
/// nothing at all.
///
/// So the ramp is built from clipped bands instead. Band *k* covers everything
/// below its own top edge and carries a small sigma; painted top to bottom,
/// each band also re-blurs the bands above it, so strength accumulates with
/// depth and the panel goes from clear to [maxSigma] across its height.
///
/// Only what scrolls beneath is affected: over a flat fill there is nothing to
/// blur, so this is for surfaces with moving content under them (the sidebar's
/// history passing under the brand row).
class FluxProgressiveBlur extends StatelessWidget {
  const FluxProgressiveBlur({
    super.key,
    required this.child,
    this.maxSigma = 8,
    this.bands = 8,
  });

  /// The content drawn on top of the blur.
  final Widget child;

  /// The strongest blur at the bottom edge, in logical pixels.
  ///
  /// Deliberately small. The bands accumulate — each one re-blurs the bands
  /// above it — so the sigma at the bottom is roughly [maxSigma], and the point
  /// is depth, not obliteration: the history underneath must still read as
  /// history. Anything past about 10 turns the cards into a grey smear.
  final double maxSigma;

  /// How many steps the ramp is cut into. More bands is a smoother ramp and
  /// more layers; 8 over a 42dp panel is about one band per 5dp.
  final int bands;

  @override
  Widget build(BuildContext context) {
    final count = bands < 1 ? 1 : bands;
    // Every band carries the same small sigma and they accumulate, so the
    // strength at depth k is about k/count of [maxSigma] — a linear ramp that
    // lands on [maxSigma] at the bottom edge.
    //
    // Giving each band a *growing* sigma instead (k * step) compounds, because
    // every band also re-blurs the ones above it: the bottom came out at the
    // square of the target and the cards underneath turned to a grey smear.
    final sigma = maxSigma / count;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var k = 0; k < count; k++)
            // Fractional so the boundaries land on an exact fraction of the
            // height whatever the panel measures.
            Positioned.fill(
              top: k / count,
              child: _BlurBand(sigma: sigma),
            ),
        ],
      ),
    );
  }
}

class _BlurBand extends StatelessWidget {
  const _BlurBand({required this.sigma});

  final double sigma;

  @override
  Widget build(BuildContext context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: const SizedBox.expand(),
      );
}

/// The app's pill-shaped label: a filter in Flows or Creations, the model and
/// permission chips in FinnAI Code.
///
/// It grew an [icon] and a [trailing] slot because two features had each
/// hand-rolled a second chip to carry one — FinnAI Code's composer chips, and
/// before that Creations' gallery filter. One widget, so a chip cannot drift
/// again.
class FluxChip extends StatelessWidget {
  const FluxChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.semanticLabel,
    this.dense = false,
    this.icon,
    this.trailing,
  });

  final String label;
  final bool selected;

  /// A 36dp pill for use inside cards, on a tinted rather than white fill.
  final bool dense;
  final VoidCallback? onTap;

  /// Overrides what a screen reader announces. Defaults to [label].
  final String? semanticLabel;

  /// A glyph before the label. FinnAI Code's model and permission chips both
  /// carry one; it used to mean a second, private chip widget.
  final List<List<dynamic>>? icon;

  /// A glyph after the label — a chevron on a chip that opens something.
  final List<List<dynamic>>? trailing;

  @override
  Widget build(BuildContext context) {
    final ink = FluxColors.inkOf(context);
    final bg = selected
        ? FluxColors.actionOf(context)
        : dense
            ? FluxColors.tileOf(context)
            : FluxColors.controlOf(context);
    final fg = selected ? FluxColors.actionInkOf(context) : ink;

    final painted = Material(
      color: bg,
      borderRadius: BorderRadius.circular(FluxRadius.pill),
      child: SizedBox(
        height: dense ? 36 : 44,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: dense ? 16 : 20),
          // A shrink-wrapping Row, not a Center: a Center expands to the
          // incoming max width, so every chip in a Wrap would go full-bleed.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                FluxIcon(
                  icon: icon!,
                  size: 18,
                  strokeWidth: 1.5,
                  color: selected ? fg : FluxColors.actionOf(context),
                ),
                const SizedBox(width: 7),
              ],
              // Flexible so a long label ellipsises instead of overflowing the
              // row it sits in.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: fg,
                      ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                FluxIcon(
                  icon: trailing!,
                  size: 16,
                  strokeWidth: 1.5,
                  color: selected
                      ? fg.withValues(alpha: .7)
                      : FluxColors.mutedOf(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final hit = math.max(FluxMotion.minTapTarget, 44.0);
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      onTap: onTap,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(minWidth: FluxMotion.minTapTarget, minHeight: hit),
        child: FluxPressScale(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(FluxRadius.pill),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(FluxRadius.pill),
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

/// A single-line field in the design's pill: a leading glyph, 16dp type, and a
/// hint that steps back from the ink.
///
/// FinnAI Code carried three private copies of this (an API key field, a model
/// search box and the terminal's prompt), each with its own hint alpha and its
/// own inset, which is how the three drifted apart. Pass [label] to put it under
/// a [FluxSectionLabel], [leading] for a glyph, and [maxLength] to cap input.
///
/// The pill is flat with a 1px hairline, like every other permanent surface.
class FluxPillField extends StatelessWidget {
  const FluxPillField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.fieldKey,
    this.label,
    this.leading,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.enabled = true,
    this.autocorrect = false,
    this.enableSuggestions = false,
    this.monospace = false,
    this.maxLength = 400,
    this.fontSize = 16,
    this.horizontalInset = 18,
    this.trailing,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Key? fieldKey;

  /// Rendered above the pill under a [FluxSectionLabel].
  final String? label;

  /// A glyph at the leading edge — a search mark, a `$` prompt.
  final Widget? leading;

  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool enabled;
  final bool autocorrect;
  final bool enableSuggestions;

  /// Renders in the platform monospace face, for keys and shell commands.
  final bool monospace;

  final int? maxLength;
  final double fontSize;
  final double horizontalInset;
  final Widget? trailing;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final ink = FluxColors.inkOf(context);
    final field = TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      obscureText: obscure,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: maxLength == null
          ? null
          : [LengthLimitingTextInputFormatter(maxLength!)],
      style: TextStyle(
        fontFamily: monospace ? 'monospace' : 'InstrumentSans',
        fontSize: fontSize,
        color: ink,
      ),
      cursorColor: ink,
      decoration: InputDecoration.collapsed(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: monospace ? 'monospace' : 'InstrumentSans',
          fontSize: fontSize,
          color: ink.withValues(alpha: .55),
        ),
      ),
    );

    final pill = Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalInset),
      constraints: const BoxConstraints(minHeight: 50),
      decoration: FluxSurfaces.flat(context, radius: FluxRadius.pill),
      alignment: Alignment.center,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(child: field),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );

    if (label == null) return pill;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FluxSectionLabel(label!),
        pill,
      ],
    );
  }
}
