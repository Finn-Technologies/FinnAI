import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/theme/flux_vivid.dart';

/// The greeting of an empty shell, FinnAI's chat or FinnAI Code: one line at
/// 26sp, centred, said rather than printed (see [FinnWordReveal]), in the
/// brand's violet-blue-pink sweep, with an optional quieter [caption] under it.
class FinnGreeting extends StatelessWidget {
  const FinnGreeting({super.key, required this.text, this.caption});

  final String text;
  final String? caption;

  static const TextStyle style = TextStyle(
    fontFamily: 'Geist',
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.7,
  );

  /// [style] painted with the brand sweep across the laid-out text. A paint
  /// shader rather than a ShaderMask: no extra layer once the reveal is done.
  /// Each stop is at least 3:1 on the canvas (large text), in both themes.
  TextStyle _brandStyle(BuildContext context, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth.isFinite ? maxWidth : double.infinity);
    final size = painter.size;
    painter.dispose();
    final colors =
        FluxColors.isDark(context) ? FluxVivid.brand : FluxVivid.brandDeep;
    return style.copyWith(
      foreground: Paint()
        ..shader = LinearGradient(colors: colors).createShader(
          Rect.fromLTWH(0, 0, size.width, size.height),
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => FinnWordReveal(
                key: ValueKey(text),
                text: text,
                style: _brandStyle(context, constraints.maxWidth),
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 10),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 15,
                  height: 1.35,
                  color: FluxColors.mutedOf(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// [text] arriving rather than appearing: a soft edge sweeps across it from
/// the start of the line while it comes up out of a blur. Still one `Text`;
/// the mask and blur exist only for the 1.1s it runs (one short line, so the
/// layer is small) and are gone once it settles. Reduced motion shows it at
/// once.
class FinnWordReveal extends StatefulWidget {
  const FinnWordReveal({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<FinnWordReveal> createState() => _FinnWordRevealState();
}

class _FinnWordRevealState extends State<FinnWordReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (_controller.value == 0 && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(
      widget.text,
      textAlign: TextAlign.center,
      style: widget.style,
    );
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: text,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          if (t >= 1) return child!;
          final rtl = Directionality.of(context) == TextDirection.rtl;
          // The edge travels from before the start to past the end.
          final edge = -.3 + 1.6 * t;
          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
              end: rtl ? Alignment.centerLeft : Alignment.centerRight,
              colors: const [Colors.white, Color(0x00FFFFFF)],
              stops: [(edge - .3).clamp(0.0, 1.0), edge.clamp(0.0, 1.0)],
            ).createShader(bounds),
            child: Transform.translate(
              offset: Offset(0, 6 * (1 - t)),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 5 * (1 - t),
                  sigmaY: 5 * (1 - t),
                ),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
