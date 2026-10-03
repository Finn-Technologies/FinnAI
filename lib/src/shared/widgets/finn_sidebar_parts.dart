import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

// The sidebar's brand row belongs with its other parts, so a screen that builds
// a sidebar imports one library.
export 'package:finn_ai/src/shared/config/app_mode.dart';
export 'package:finn_ai/src/shared/widgets/finn_brand_switcher.dart';

/// A circular shortcut in the sidebar: the destinations under the brand row.
///
/// Either an [asset] from the design file or a [icon] from [FluxIcons].
class FinnSidebarTile extends StatelessWidget {
  const FinnSidebarTile({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.asset,
    this.size = 70,
  }) : assert(icon != null || asset != null);

  final List<List<dynamic>>? icon;
  final String? asset;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: FluxPressScale(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(FluxRadius.sm),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(FluxRadius.sm),
              child: SizedBox(
                width: size,
                height: size + 22,
                child: Column(
                  children: [
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: FluxColors.tileOf(context),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: asset != null
                            ? FigmaSvg(
                                asset: asset!,
                                width: size * .57,
                                height: size * .57,
                              )
                            : FluxIcon(
                                icon: icon!,
                                size: size * 0.42,
                                color: FluxColors.inkOf(context),
                              ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 17,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'InstrumentSans',
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w400,
                            color: FluxColors.inkOf(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// A circular icon-only control, e.g. close, new chat or settings.
class FinnSidebarCircleButton extends StatelessWidget {
  const FinnSidebarCircleButton({
    super.key,
    required this.tooltip,
    required this.background,
    required this.onTap,
    this.icon,
    this.asset,
  }) : assert(icon != null || asset != null);

  final List<List<dynamic>>? icon;
  final String? asset;
  final String tooltip;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          onTap: onTap,
          excludeSemantics: true,
          child: FluxPressScale(
            child: Material(
              color: background,
              shape: const CircleBorder(),
              child: SizedBox.square(
                dimension: 50,
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: asset != null
                        ? FigmaSvg(asset: asset!, width: 25, height: 25)
                        : FluxIcon(
                            icon: icon!,
                            size: 22,
                            color: FluxColors.inkOf(context),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
