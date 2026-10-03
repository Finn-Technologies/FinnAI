import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// Height of the top scroll-fade band, in logical pixels.
///
/// Declared once because the gradient's opaque stretch is a fraction of it:
/// the band and the gradient stops have to stay in step.
const double finnTopFadeHeight = 210;

/// Depth of the fully opaque stretch at the top of the fade band.
///
/// The brand row must stay readable while messages scroll beneath it, so the
/// fade is opaque wherever the header can sit. The header is 50 tall at
/// `top: 71 * sy`, and `sy` is clamped to 1.08, so its bottom edge reaches
/// (71 + 50) * 1.08 ≈ 130.7.
const double finnTopFadeOpaqueDepth = 134;

/// A static soft-edge fade that sits over a scrolling list so content appears
/// to slide beneath the header at the top and fade into the very bottom edge
/// of the screen below the composer. It replaces a backdrop blur with a plain
/// gradient — effectively free per scroll frame. The header and composer are
/// drawn above these fades, so they stay crisp and tappable.
///
/// The top band is *fully* opaque across the brand row and only then ramps to
/// transparent. At anything less than opaque, scrolled text stays legible
/// straight through the app title, which reads as a rendering fault rather
/// than as depth. The bottom band has no content drawn over it, so it keeps
/// the softer profile that lets the last row dissolve into the composer.
class FinnEdgeFade extends StatelessWidget {
  const FinnEdgeFade({super.key, required this.top});

  /// True for the fade under the header at the top of the screen, false for
  /// the fade hugging the very bottom edge of the screen.
  final bool top;

  @override
  Widget build(BuildContext context) {
    // The fade has to end on the same colour as the surface it sits on. The
    // canvas is tileOf (#18181C in dark), not canvasOf (#000000), so fading to
    // darkCanvas left a visible black band along the header and footer.
    final color = FluxColors.tileOf(context);
    final stops = top
        ? const <double>[
            0.0,
            finnTopFadeOpaqueDepth / finnTopFadeHeight,
            0.80,
            1.0,
          ]
        : const <double>[0.0, 0.35, 0.7, 1.0];
    final colors = top
        ? <Color>[
            // Opaque across the brand row; the ramp starts below it.
            color,
            color,
            color.withValues(alpha: 0.42),
            color.withValues(alpha: 0.0),
          ]
        : <Color>[
            color.withValues(alpha: 0.93),
            color.withValues(alpha: 0.64),
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.0),
          ];
    return DecoratedBox(
      decoration: BoxDecoration(
        // Progressive: mostly transparent across the band and easing smoothly
        // to near-opaque only at the screen edge, so there is no hard line.
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          stops: stops,
          colors: colors,
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}
