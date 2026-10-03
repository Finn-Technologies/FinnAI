import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/creations/creation_palette.dart';
import 'package:finn_ai/src/features/creations/runtime/mini_app_persistence.dart';
import 'package:finn_ai/src/features/creations/runtime/mini_app_renderer.dart';
import 'package:finn_ai/src/features/creations/runtime/mini_app_state.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// Full-screen host for a generated mini app.
///
/// The app owns the whole screen: there is no page header above it. A tinted
/// wash in the app's own accent colour, a large title and its content are all
/// the user sees, with two small floating controls (back, more) on top, so it
/// reads as an app rather than as a page inside another app.
///
/// What the app holds is saved on the device when [creationId] is given, so a
/// list is still there the next time it is opened. Reset clears it.
class MiniAppHost extends StatefulWidget {
  const MiniAppHost({
    super.key,
    required this.title,
    required this.spec,
    required this.onBack,
    this.creationId,
    this.stateStore,
    this.onAddToHome,
    this.onEdit,
  });

  final String title;
  final MiniAppSpec spec;
  final VoidCallback onBack;

  /// Which saved state belongs to this app. Null keeps the state in memory only.
  final String? creationId;
  final MiniAppStateStore? stateStore;

  /// Extra entries for the "more" menu; omitted when the host has no route
  /// back to the creations screen.
  final VoidCallback? onAddToHome;
  final VoidCallback? onEdit;

  @override
  State<MiniAppHost> createState() => _MiniAppHostState();
}

class _MiniAppHostState extends State<MiniAppHost> {
  late final MiniAppState _state = MiniAppState(widget.spec);
  MiniAppAutosave? _autosave;

  /// The emoji the app leads with, drawn beside the title.
  late final String? _heroEmoji = _leadingEmoji(widget.spec);

  @override
  void initState() {
    super.initState();
    final id = widget.creationId;
    if (id != null) {
      _autosave = MiniAppAutosave(
        creationId: id,
        state: _state,
        store: widget.stateStore ?? MiniAppStateStore(),
      )..start();
    }
  }

  @override
  void dispose() {
    _autosave?.dispose();
    _state.dispose();
    super.dispose();
  }

  static String? _leadingEmoji(MiniAppSpec spec) {
    final first = spec.nodes.firstOrNull;
    if (first is ImageNode && first.url.isEmpty && first.emoji.isNotEmpty) {
      return first.emoji;
    }
    return null;
  }

  Future<void> _reset() async {
    final l10n = L10n.of(context);
    final ok = await showFinnConfirm(
      context,
      title: l10n.creationsResetAppTitle,
      body: l10n.creationsResetAppBody,
      confirmLabel: l10n.creationsResetApp,
      destructive: true,
    );
    if (ok != true || !mounted) return;
    _state.reset();
    final id = widget.creationId;
    if (id != null) await (widget.stateStore ?? MiniAppStateStore()).clear(id);
  }

  void _openMenu(Rect anchor) {
    final l10n = L10n.of(context);
    showFinnMenu(
      context,
      anchor: anchor,
      items: [
        FinnMenuItem(
          label: l10n.creationsResetApp,
          icon: FluxIcons.refresh,
          onTap: _reset,
        ),
        if (widget.onAddToHome != null)
          FinnMenuItem(
            label: l10n.creationsAddToHomeScreen,
            icon: FluxIcons.canvas,
            onTap: widget.onAddToHome!,
          ),
        if (widget.onEdit != null)
          FinnMenuItem(
            label: l10n.creationsMenuEditWithFinn,
            icon: FluxIcons.edit,
            onTap: widget.onEdit!,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final accent = CreationPalette.pastel(widget.spec.accent);
    final dark = FluxColors.isDark(context);
    final canvas = FluxColors.canvasOf(context);
    final top = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: canvas,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // The wash: the app's accent fading into the page, so the screen has
          // a colour of its own without a coloured toolbar.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 340 + top,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accent.withValues(alpha: dark ? .28 : .85),
                    accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const FluxBouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                24,
                top + 84,
                24,
                56 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_heroEmoji != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: dark ? .35 : 1),
                            borderRadius: BorderRadius.circular(FluxRadius.md),
                          ),
                          // Two emoji must still fit the tile.
                          child: FittedBox(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                _heroEmoji,
                                style: const TextStyle(fontSize: 32),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Semantics(
                    header: true,
                    child: Text(
                      widget.title,
                      style: theme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  MiniAppRenderer(
                    state: _state,
                    skipFirst: _heroEmoji == null ? 0 : 1,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: top + 12,
            child: Row(
              children: [
                FinnCircleButton(
                  key: const ValueKey('page-back-button'),
                  glyph: const FigmaSvg(
                    asset: FigmaAssets.back,
                    width: 25,
                    height: 25,
                  ),
                  label: l10n.commonBack,
                  onTap: widget.onBack,
                ),
                const Spacer(),
                Builder(
                  builder: (menuContext) => FinnCircleButton.icon(
                    icon: FluxIcons.moreHorizontal,
                    label: l10n.flowsActionsTooltip,
                    onTap: () => _openMenu(finnAnchorOf(menuContext)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
