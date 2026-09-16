import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    this.intensity = 1,
    this.primaryColor = FluxColors.mint,
    this.secondaryColor = FluxColors.green,
    this.child,
  });

  final double intensity;
  final Color primaryColor;
  final Color secondaryColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final canvas = FluxColors.canvasOf(context);

    if (intensity <= 0) {
      return ColoredBox(
        color: canvas,
        child: child ?? const SizedBox.expand(),
      );
    }

    // Siri AI clean surface: single uniform solid color matching the canvas,
    // zero gradient, running at peak 120 FPS on all devices.
    return ColoredBox(
      color: canvas,
      child: child ?? const SizedBox.expand(),
    );
  }
}
