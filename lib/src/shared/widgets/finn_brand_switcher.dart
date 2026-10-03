import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/shared/config/app_mode.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The brand row at the top of both sidebars: the name of the app you are in,
/// and the way to the other one.
///
/// Tapping the name opens a small menu with FinnAI and FinnAI Code; choosing
/// the other one swaps the whole app. The chevron is the only hint that the
/// name is a control, which is how the design treats it.
class FinnBrandSwitcher extends StatelessWidget {
  const FinnBrandSwitcher({
    super.key,
    required this.current,
    this.controller,
  });

  final FinnAppMode current;

  /// Overridable for tests; the real app has one.
  final AppModeController? controller;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final label = current == FinnAppMode.chat
        ? l10n.appBrandFinnAI
        : l10n.appBrandFinnAICode;
    final modes = controller ?? AppModeController.instance;
    return Semantics(
      button: true,
      label: '$label. ${l10n.appModeSwitchSemantic}',
      excludeSemantics: true,
      child: Builder(
        builder: (anchorContext) => FluxPressScale(
          scale: .98,
          child: InkWell(
            key: const ValueKey('brand-switcher'),
            borderRadius: BorderRadius.circular(FluxRadius.sm),
            onTap: () => showFinnMenu(
              context,
              anchor: finnAnchorOf(anchorContext),
              items: [
                FinnMenuItem(
                  label: l10n.appBrandFinnAI,
                  icon: FluxIcons.magic,
                  selected: current == FinnAppMode.chat,
                  onTap: () => modes.set(FinnAppMode.chat),
                ),
                FinnMenuItem(
                  label: l10n.appBrandFinnAICode,
                  icon: FluxIcons.sourceCode,
                  selected: current == FinnAppMode.code,
                  onTap: () => modes.set(FinnAppMode.code),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  FluxIcon(
                    icon: HugeIcons.strokeRoundedArrowDown01,
                    size: 20,
                    strokeWidth: 1.5,
                    color: FluxColors.mutedOf(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
