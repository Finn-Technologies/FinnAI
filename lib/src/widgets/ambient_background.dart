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
  Widget build(BuildContext context) => ColoredBox(
    color: FluxColors.canvasOf(context),
    child: child ?? const SizedBox.expand(),
  );
}
