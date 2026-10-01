part of '../creations_page.dart';

enum _WidgetSize { small, medium, large }

/// A widget creation up close: a preview at the chosen size, where it came
/// from, and the ways to put it on the home screen or change it.
class _WidgetDetailPage extends StatefulWidget {
  const _WidgetDetailPage({
    required this.creation,
    required this.spec,
    required this.onAddToHome,
    required this.onEdit,
    required this.onMenu,
  });

  final FinnCreation creation;
  final HomeWidgetSpec spec;
  final Future<void> Function() onAddToHome;
  final VoidCallback onEdit;
  final void Function(Rect anchor) onMenu;

  @override
  State<_WidgetDetailPage> createState() => _WidgetDetailPageState();
}

class _WidgetDetailPageState extends State<_WidgetDetailPage> {
  _WidgetSize _size = _WidgetSize.medium;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final width = switch (_size) {
      _WidgetSize.small => 150.0,
      _WidgetSize.medium => 230.0,
      _WidgetSize.large => double.infinity,
    };
    return FinnPage(
      title: widget.creation.title,
      actions: [
        Builder(
          builder: (menuContext) => FinnCircleButton.icon(
            icon: FluxIcons.moreHorizontal,
            label: l10n.flowsActionsTooltip,
            onTap: () => widget.onMenu(finnAnchorOf(menuContext)),
          ),
        ),
      ],
      children: [
        FinnReveal(
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB9C9D0), Color(0xFF8EA3AC)],
              ),
            ),
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: FluxMotion.revealDuration,
              curve: FluxMotion.revealCurve,
              width: width == double.infinity ? 300 : width,
              constraints: const BoxConstraints(minHeight: 130),
              child: _WidgetSurface(spec: widget.spec),
            ),
          ),
        ),
        Row(
          children: [
            for (final size in _WidgetSize.values) ...[
              FluxChip(
                label: switch (size) {
                  _WidgetSize.small => l10n.creationsSizeSmall,
                  _WidgetSize.medium => l10n.creationsSizeMedium,
                  _WidgetSize.large => l10n.creationsSizeLarge,
                },
                selected: _size == size,
                onTap: () => setState(() => _size = size),
              ),
              const SizedBox(width: 10),
            ],
          ],
        ),
        FinnCaption(l10n.creationsUpdatesOnDevice),
        FinnTile(
          icon: FluxIcons.note,
          title: l10n.creationsMadeInChat,
          subtitle: widget.creation.prompt,
        ),
        FinnTile(
          icon: FluxIcons.lock,
          title: l10n.creationsDataLabel,
          subtitle: l10n.creationsDataSub,
        ),
        FinnButton(
          label: l10n.creationsAddToHomeScreen,
          icon: FluxIcons.canvas,
          onTap: () => unawaited(widget.onAddToHome()),
        ),
        FinnButton(
          label: l10n.creationsMenuEditWithFinn,
          icon: FluxIcons.edit,
          secondary: true,
          onTap: widget.onEdit,
        ),
      ],
    );
  }
}
