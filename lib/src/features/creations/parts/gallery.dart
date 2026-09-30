part of '../creations_page.dart';

/// Round, staggered tiles matching the creations design.
class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.creations,
    required this.onOpen,
    required this.onBadgeTap,
    required this.badgeLabel,
    required this.onNew,
  });

  final List<FinnCreation> creations;
  final ValueChanged<FinnCreation> onOpen;
  final ValueChanged<FinnCreation> onBadgeTap;
  final String Function(FinnCreation) badgeLabel;
  final VoidCallback onNew;

  /// Space between the two tile columns. Wide enough that the circles read as
  /// separate objects rather than a solid block, as in the reference grid.
  static const double _gap = 40;
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(20, 6, 20, 14);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileSize =
            (constraints.maxWidth - _padding.horizontal - _gap) / 2;
        // The right column rides lower so the grid staggers like the design.
        final stagger = tileSize * 0.42;
        final left = <FinnCreation>[];
        final right = <FinnCreation>[];
        for (var index = 0; index < creations.length; index++) {
          (index.isEven ? left : right).add(creations[index]);
        }
        Widget column(List<FinnCreation> items) => Column(
              children: [
                for (final creation in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _CreationTile(
                      creation: creation,
                      size: tileSize,
                      badgeLabel: badgeLabel(creation),
                      onTap: () => onOpen(creation),
                      onBadgeTap: () => onBadgeTap(creation),
                    ),
                  ),
              ],
            );
        return SingleChildScrollView(
          physics: const FluxBouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: _padding,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: column(left)),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: stagger),
                      child: column(right),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FluxPillButton(
                label: L10n.of(context).creationsNewCreation,
                icon: FluxIcons.add,
                onTap: onNew,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CreationTile extends StatelessWidget {
  const _CreationTile({
    required this.creation,
    required this.size,
    required this.badgeLabel,
    required this.onTap,
    required this.onBadgeTap,
  });

  final FinnCreation creation;
  final double size;
  final String badgeLabel;
  final VoidCallback onTap;
  final VoidCallback onBadgeTap;

  @override
  Widget build(BuildContext context) {
    final accent = CreationPalette.tileFor(creation.kind);
    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Material(
                  color: accent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap,
                    child: Center(child: _TileGlyph(creation: creation)),
                  ),
                ),
              ),
              Positioned(
                // The 48dp hit box is centred on the 30dp badge, so the
                // visible circle stays put while the tap target meets the 48dp
                // minimum. The offsets are the original ones shifted by the
                // extra half-box (9dp) in each direction.
                right: -11,
                bottom: -7,
                child: Semantics(
                  button: true,
                  label: badgeLabel,
                  child: SizedBox.square(
                    dimension: 48,
                    child: Center(
                      child: Material(
                        color: FluxColors.cardOf(context),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: onBadgeTap,
                          customBorder: const CircleBorder(),
                          child: SizedBox.square(
                            dimension: 30,
                            child: Center(
                              child: FluxIcon(
                                icon: creation.kind == CreationKind.presentation
                                    ? FluxIcons.download
                                    : FluxIcons.add,
                                size: 15,
                                color: CreationPalette.onPastel,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          creation.title,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// A creation's tile glyph: its own emoji when it has one, else its kind icon.
class _TileGlyph extends StatelessWidget {
  const _TileGlyph({required this.creation});

  final FinnCreation creation;

  @override
  Widget build(BuildContext context) {
    final emoji = _emojiFor(creation);
    if (emoji != null) {
      return Text(emoji, style: const TextStyle(fontSize: 42));
    }
    return FluxIcon(
      icon: _iconFor(creation),
      color: CreationPalette.onPastel,
      size: creation.kind == CreationKind.presentation ? 34 : 38,
      strokeWidth: 1.5,
    );
  }
}
