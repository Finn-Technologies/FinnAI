part of '../creations_page.dart';

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onSelected});

  final CreationKind? selected;
  final ValueChanged<CreationKind?> onSelected;

  @override
  Widget build(BuildContext context) {
    final values = <CreationKind?>[null, ...CreationKind.values];
    return SizedBox(
      // 48dp keeps every filter chip at the minimum tap target.
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = values[index];
          final active = selected == value;
          final radius = BorderRadius.circular(FluxRadius.pill);
          return Semantics(
            button: true,
            selected: active,
            label: L10n.of(context).creationsFilterSemantic(
              value == null
                  ? L10n.of(context).creationsAll
                  : _filterLabel(context, value),
            ),
            child: Material(
              color: active
                  ? FluxColors.inkOf(context)
                  : FluxColors.surfaceOf(context),
              borderRadius: radius,
              child: InkWell(
                onTap: () => onSelected(value),
                borderRadius: radius,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Center(
                    child: Text(
                      value == null
                          ? L10n.of(context).creationsAll
                          : _filterLabel(context, value),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: active
                                ? FluxColors.canvasOf(context)
                                : FluxColors.inkOf(context),
                            fontWeight:
                                active ? FontWeight.w500 : FontWeight.w400,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) => Center(
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
          color: FluxColors.destructiveOf(context).withValues(alpha: .09),
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
