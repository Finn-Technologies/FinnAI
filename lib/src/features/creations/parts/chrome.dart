part of '../creations_page.dart';

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onSelected});

  final CreationKind? selected;
  final ValueChanged<CreationKind?> onSelected;

  @override
  Widget build(BuildContext context) {
    final values = <CreationKind?>[
      null,
      for (final kind in CreationKind.values)
        // Widgets are a phone's home-screen feature.
        if (!(isDesktop && kind == CreationKind.widget)) kind,
    ];
    // The row scrolls, and in longer locales it runs past the page margin.
    // The last 28dp fade out rather than cut a label in half, so the edge
    // reads as "more this way" in either theme.
    return SizedBox(
      height: 48,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => LinearGradient(
          colors: const [Colors.black, Colors.black, Colors.transparent],
          stops: [0, 1 - 28 / bounds.width.clamp(28, double.infinity), 1],
        ).createShader(bounds),
        child: ListView.separated(
          padding: const EdgeInsets.only(right: 28),
          scrollDirection: Axis.horizontal,
          itemCount: values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final value = values[index];
            final label = value == null
                ? L10n.of(context).creationsAll
                : _filterLabel(context, value);
            return FluxChip(
              label: label,
              semanticLabel: L10n.of(context).creationsFilterSemantic(label),
              selected: selected == value,
              onTap: () => onSelected(value),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) => !filtered
      ? FinnReveal(
          child: Column(
            children: [
              const _FanArt(),
              const SizedBox(height: 24),
              Text(
                L10n.of(context).creationsNoneTitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Text(
                L10n.of(context).creationsNoneBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: FluxColors.mutedOf(context),
                      height: 1.35,
                    ),
              ),
            ],
          ),
        )
      : Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 42),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: FluxColors.surfaceOf(context),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: FluxIcon(icon: FluxIcons.canvas, size: 27),
                  ),
                ),
                const SizedBox(height: 17),
                Text(
                  filtered
                      ? L10n.of(context).creationsEmptyFilteredTitle
                      : L10n.of(context).creationsEmptyTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  filtered
                      ? L10n.of(context).creationsEmptyFilteredBody
                      : L10n.of(context).creationsEmptyBody,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: FluxColors.mutedOf(context),
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        );
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
        decoration: BoxDecoration(
          // Tinted harder in dark: #FF9E96 at .09 over #18181C measures about
          // 1.15:1, so the notice was visible only by its icon.
          color: FluxColors.destructiveOf(context).withValues(
            alpha: FluxColors.isDark(context) ? .16 : .09,
          ),
          borderRadius: BorderRadius.circular(FluxRadius.sm),
        ),
        child: Row(
          children: [
            FluxIcon(
              icon: FluxIcons.sad,
              size: 18,
              color: FluxColors.destructiveOf(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child:
                  Text(message, style: Theme.of(context).textTheme.labelMedium),
            ),
            if (onDismiss != null)
              FluxIconButton(
                icon: FluxIcons.close,
                size: 30,
                tooltip: L10n.of(context).commonDismiss,
                onTap: onDismiss,
              ),
          ],
        ),
      );
}

class _QuietLoader extends StatelessWidget {
  const _QuietLoader({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Spinner(),
          if (label != null) ...[
            const SizedBox(width: 10),
            Text(
              label!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FluxColors.mutedOf(context),
                  ),
            ),
          ],
        ],
      );
}

/// The centred 50dp plus that starts a new creation.
class _NewCreationButton extends StatelessWidget {
  const _NewCreationButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: L10n.of(context).creationsNewCreation,
        excludeSemantics: true,
        child: Material(
          color: FluxColors.controlOf(context),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: 50,
              child: Center(
                child: FluxIcon(
                  icon: FluxIcons.add,
                  size: 24,
                  color: FluxColors.inkOf(context),
                ),
              ),
            ),
          ),
        ),
      );
}

/// A fan of frosted pastel pills: the design's "nothing yet" artwork.
class _FanArt extends StatelessWidget {
  const _FanArt();

  static const _colors = [
    Color(0xFFE3F7C8),
    Color(0xFFCFF3E4),
    Color(0xFFCFE4F7),
    Color(0xFFDCD3F7),
    Color(0xFFF0D0F0),
    Color(0xFFF7D6DC),
  ];

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          width: double.infinity,
          height: 200,
          child: CustomPaint(painter: _FanPainter(_colors)),
        ),
      );
}

class _FanPainter extends CustomPainter {
  const _FanPainter(this.colors);

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width / 2, size.height - 20);
    const pillWidth = 74.0;
    const pillHeight = 150.0;
    final count = colors.length;
    for (var i = 0; i < count; i++) {
      final t = count == 1 ? 0.0 : i / (count - 1) * 2 - 1;
      canvas
        ..save()
        ..translate(pivot.dx, pivot.dy)
        ..rotate(t * 0.9)
        ..translate(0, -pillHeight / 2 + 10);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: pillWidth,
          height: pillHeight,
        ),
        const Radius.circular(pillWidth / 2),
      );
      canvas
        ..drawShadow(Path()..addRRect(rect), const Color(0x22000000), 8, true)
        ..drawRRect(rect, Paint()..color = colors[i].withValues(alpha: .9))
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_FanPainter old) => false;
}
