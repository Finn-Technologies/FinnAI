part of '../creations_page.dart';

/// The design's gallery: two columns of white cards, each with a preview of
/// what the creation looks like, its name and its kind.
class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.creations,
    required this.onOpen,
    required this.onMenu,
  });

  final List<FinnCreation> creations;
  final ValueChanged<FinnCreation> onOpen;

  /// Long-press (or the menu gesture): the creation and the card's rect.
  final void Function(FinnCreation creation, Rect anchor) onMenu;

  static const double _gap = 15;
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(25, 6, 25, 20);

  @override
  Widget build(BuildContext context) {
    final left = <FinnCreation>[];
    final right = <FinnCreation>[];
    for (var index = 0; index < creations.length; index++) {
      (index.isEven ? left : right).add(creations[index]);
    }
    Widget column(List<FinnCreation> items) => Column(
          children: [
            for (final creation in items)
              Padding(
                padding: const EdgeInsets.only(bottom: _gap),
                child: FinnReveal(
                  index: creations.indexOf(creation),
                  child: _CreationCard(
                    creation: creation,
                    onTap: () => onOpen(creation),
                    onMenu: (anchor) => onMenu(creation, anchor),
                  ),
                ),
              ),
          ],
        );
    return SingleChildScrollView(
      physics: const FluxBouncingScrollPhysics(),
      padding: _padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: column(left)),
          const SizedBox(width: _gap),
          Expanded(child: column(right)),
        ],
      ),
    );
  }
}

class _CreationCard extends StatelessWidget {
  const _CreationCard({
    required this.creation,
    required this.onTap,
    required this.onMenu,
  });

  final FinnCreation creation;
  final VoidCallback onTap;
  final ValueChanged<Rect> onMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Builder(
      builder: (cardContext) => Semantics(
        button: true,
        label: creation.title,
        onLongPress: () => onMenu(finnAnchorOf(cardContext)),
        excludeSemantics: true,
        child: FluxPressScale(
          scale: .97,
          child: Material(
            color: FluxColors.controlOf(context),
            borderRadius: BorderRadius.circular(FluxRadius.card),
            child: InkWell(
              borderRadius: BorderRadius.circular(FluxRadius.card),
              onTap: onTap,
              onLongPress: () {
                HapticFeedback.mediumImpact();
                onMenu(finnAnchorOf(cardContext));
              },
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CreationPreview(creation: creation),
                    const SizedBox(height: 10),
                    Text(
                      creation.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _kindName(l10n, creation.kind),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: FluxColors.actionOf(context),
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

/// The design's kind names: Widget, Mini app, Presentation.
String _kindName(AppLocalizations l10n, CreationKind kind) => switch (kind) {
      CreationKind.app => l10n.plusMiniApp,
      CreationKind.widget => l10n.plusWidget,
      CreationKind.presentation => l10n.plusPresentation,
    };

/// A small picture of the creation: its widget rows, its first slide, or its
/// glyph on the accent colour.
class _CreationPreview extends StatelessWidget {
  const _CreationPreview({required this.creation});

  final FinnCreation creation;

  @override
  Widget build(BuildContext context) {
    final dark = CreationPalette.onPastel;
    switch (creation.artifact) {
      case WidgetArtifact(:final spec):
        final first = spec.rows.isEmpty ? null : spec.rows.first;
        return Container(
          height: 120,
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CreationPalette.pastel(spec.accent),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                spec.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: dark),
              ),
              if (first != null)
                Text(
                  first.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: dark),
                ),
            ],
          ),
        );
      case PresentationArtifact(:final spec):
        final title = spec.slides.isEmpty ? creation.title : spec.title;
        return Container(
          height: 88,
          width: double.infinity,
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8FA6B0), Color(0xFF3F5560)],
            ),
          ),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white),
          ),
        );
      default:
        final emoji = _emojiFor(creation);
        return Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: CreationPalette.tileFor(creation.kind),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: emoji != null
                ? Text(emoji, style: const TextStyle(fontSize: 38))
                : FluxIcon(
                    icon: _iconFor(creation),
                    size: 34,
                    color: dark,
                  ),
          ),
        );
    }
  }
}
