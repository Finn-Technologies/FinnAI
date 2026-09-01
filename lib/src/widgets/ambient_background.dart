import 'package:flutter/material.dart';

import '../theme/flux_theme.dart';

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
    // Perf-gated: the blurred mint/green ambient is currently a solid canvas
    // to avoid extra layers on low-end devices. When intensity is 0 or the
    // device is constrained, the gradient is skipped entirely. Future: gate
    // on DeviceProfile.isLowEnd and re-enable with a RepaintBoundary +
    // BackdropFilter when headroom allows.
    if (intensity <= 0) {
      return ColoredBox(
        color: FluxColors.canvasOf(context),
        child: child ?? const SizedBox.expand(),
      );
    }
    return ColoredBox(
      color: FluxColors.canvasOf(context),
      child: child ?? const SizedBox.expand(),
    );
  }
}
