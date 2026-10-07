import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_morph_sheet.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

export 'package:finn_ai/src/shared/widgets/finn_morph_sheet.dart';

/// A tall primary action: `#414141`, 50dp, 25dp radius, 18dp label.
class FinnButton extends StatelessWidget {
  const FinnButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.secondary = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  /// A 44dp button with 14dp text, for use inside cards.
  final bool compact;

  /// The white variant, for the quieter of two actions.
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final fg =
        secondary ? FluxColors.inkOf(context) : FluxColors.actionInkOf(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: FluxPressScale(
        enabled: onTap != null,
        child: Opacity(
          opacity: onTap == null ? .4 : 1,
          child: Material(
            color: secondary
                ? (compact
                    ? FluxColors.tileOf(context)
                    : FluxColors.controlOf(context))
                : FluxColors.actionOf(context),
            borderRadius: BorderRadius.circular(compact ? 22 : 25),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(compact ? 22 : 25),
              child: SizedBox(
                height: compact ? 44 : 50,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      FluxIcon(
                        icon: icon!,
                        size: 22,
                        color: fg,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: (compact
                                ? Theme.of(context).textTheme.bodySmall
                                : Theme.of(context).textTheme.titleMedium)
                            ?.copyWith(color: fg),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Confirms or declines something, in the design's dialog.
///
/// Resolves to `true` when the confirm block is tapped, `false` for the other,
/// and `null` when the scrim or system back dismisses it.
Future<bool?> showFinnConfirm(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) =>
    showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: const Color(0x8C000000),
      transitionDuration: FluxMotion.modalDuration,
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: FluxMotion.modalCurve,
          reverseCurve: FluxMotion.modalReverseCurve,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: .94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, __) => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Semantics(
              scopesRoute: true,
              explicitChildNodes: true,
              namesRoute: true,
              label: title,
              child: Material(
                color: FluxColors.controlOf(context),
                borderRadius: BorderRadius.circular(25),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 25, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (body != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          body,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: FluxColors.actionOf(context),
                                  ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: _DialogBlock(
                              label:
                                  cancelLabel ?? L10n.of(context).commonCancel,
                              dark: false,
                              onTap: () => Navigator.of(context).pop(false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DialogBlock(
                              label: confirmLabel,
                              dark: true,
                              destructive: destructive,
                              onTap: () => Navigator.of(context).pop(true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

class _DialogBlock extends StatelessWidget {
  const _DialogBlock({
    required this.label,
    required this.dark,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final bool dark;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The design's asymmetric corners: three 10dp and one 25dp, the large one
    // on the outer bottom corner of each button.
    final radius = dark
        ? const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(25),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(25),
            bottomRight: Radius.circular(10),
          );
    final bg = dark
        ? (destructive
            ? FluxColors.destructiveOf(context)
            : FluxColors.actionOf(context))
        : FluxColors.tileOf(context);
    // On the filled button the label takes the fill's own ink: white on the
    // light theme's #414141, near-black on the dark theme's near-white (white
    // on white made "Allow" vanish there).
    final fg = !dark
        ? FluxColors.inkOf(context)
        : destructive
            ? (FluxColors.isDark(context)
                ? FluxColors.darkCanvas
                : Colors.white)
            : FluxColors.actionInkOf(context);
    void tap() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      button: true,
      label: label,
      onTap: tap,
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: radius,
        child: InkWell(
          onTap: tap,
          borderRadius: radius,
          child: SizedBox(
            height: 60,
            child: Center(
              child: Text(
                label,
                style:
                    Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's sheet: a floating glass panel with a grab handle, a title, an
/// optional sentence, and [children] stacked below.
///
/// Pass the opener's on-screen rectangle as [origin] (see [globalRectOf]) and
/// the sheet grows out of that control and shrinks back into it on close;
/// [originColor] and [originRadius] describe the control so the first frame of
/// the sheet is the control itself.
Future<T?> showFinnSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<Widget> Function(BuildContext context) children,
  Rect? origin,
  Color? originColor,
  double? originRadius,
}) =>
    showFinnMorphSheet<T>(
      context,
      origin: origin,
      originColor: originColor,
      originRadius: originRadius,
      builder: (context) => FinnSheetFrame(
        title: title,
        subtitle: subtitle,
        children: children(context),
      ),
    );

/// The inside of a [showFinnSheet]: handle, title, sentence, children. The
/// panel itself — glass, margins, corners — is [FinnFloatingSheet]'s.
class FinnSheetFrame extends StatelessWidget {
  const FinnSheetFrame({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FinnSheetHandle(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.3,
                      ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FluxColors.secondaryInkOf(context),
                          height: 1.35,
                        ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );
}

/// One row in a [showFinnMenu] popup.
class FinnMenuItem {
  const FinnMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  /// Marks the row as the current choice, with a check on its trailing edge.
  final bool selected;
}

/// Chooses [item] from an open menu: a tick, the menu closes, the item runs.
void _pick(BuildContext context, FinnMenuItem item) {
  HapticFeedback.selectionClick();
  Navigator.of(context).pop();
  item.onTap();
}

/// A 260dp white popup anchored under [anchor] (usually a header action), with
/// the design's light scrim behind it.
Future<void> showFinnMenu(
  BuildContext context, {
  required Rect anchor,
  required List<FinnMenuItem> items,
}) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: L10n.of(context).commonDismiss,
      barrierColor: const Color(0x1A000000),
      transitionDuration: const Duration(milliseconds: 380),
      // The menu grows out of the control that opened it (see
      // [FinnMorphSurface]); a long-pressed card is too big to grow from, so
      // a menu for one simply rises into place.
      transitionBuilder: (context, animation, _, child) => child,
      pageBuilder: (context, animation, __) {
        final size = MediaQuery.sizeOf(context);
        const width = 260.0;
        final left =
            (anchor.right - width).clamp(16.0, size.width - width - 16);
        // Under the anchor when it fits; above it when it does not; and never
        // off the screen.
        final height = items.length * 50.0 + 16;
        final below = anchor.bottom + 10;
        final top = below + height <= size.height - 16
            ? below
            : (anchor.top - 10 - height >= 16
                ? anchor.top - 10 - height
                : (size.height - 16 - height).clamp(16.0, size.height));
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: width,
              child: FinnMorphSurface(
                progress: MediaQuery.disableAnimationsOf(context)
                    ? animation
                    : CurvedAnimation(
                        parent: animation,
                        curve: FluxMotion.morphCurve,
                        reverseCurve: FluxMotion.morphReverseCurve,
                      ),
                origin: anchor.shortestSide <= 64 ? anchor : null,
                originColor: FluxColors.controlOf(context),
                radius: 25,
                child: Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in items)
                          Semantics(
                            button: true,
                            selected: item.selected,
                            label: item.label,
                            onTap: () => _pick(context, item),
                            excludeSemantics: true,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(17),
                              onTap: () => _pick(context, item),
                              child: SizedBox(
                                height: 50,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  child: Row(
                                    children: [
                                      FluxIcon(
                                        icon: item.icon,
                                        size: 22,
                                        color: item.destructive
                                            ? FluxColors.destructiveOf(context)
                                            : FluxColors.actionOf(context),
                                      ),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: item.destructive
                                                    ? FluxColors.destructiveOf(
                                                        context,
                                                      )
                                                    : null,
                                              ),
                                        ),
                                      ),
                                      if (item.selected)
                                        FluxIcon(
                                          icon: FluxIcons.check,
                                          size: 20,
                                          color: FluxColors.actionOf(context),
                                        ),
                                    ],
                                  ),
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
          ],
        );
      },
    );

/// The anchor rect of the widget behind [context], for [showFinnMenu].
Rect finnAnchorOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Asks for one line of text in the design's dialog. Null when dismissed.
Future<String?> showFinnPrompt(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  required String confirmLabel,
}) {
  final controller = TextEditingController(text: initial);
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: const Color(0x8C000000),
    transitionDuration: FluxMotion.modalDuration,
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: FluxMotion.modalCurve,
        reverseCurve: FluxMotion.modalReverseCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: .94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, _, __) => SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Material(
              color: FluxColors.controlOf(context),
              borderRadius: BorderRadius.circular(25),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 25, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      style: Theme.of(context).textTheme.bodyMedium,
                      onSubmitted: (value) => Navigator.of(context).pop(value),
                      decoration: InputDecoration(
                        hintText: hint,
                        filled: true,
                        fillColor: FluxColors.tileOf(context),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _DialogBlock(
                            label: L10n.of(context).commonCancel,
                            dark: false,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DialogBlock(
                            label: confirmLabel,
                            dark: true,
                            onTap: () =>
                                Navigator.of(context).pop(controller.text),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ).whenComplete(controller.dispose);
}
