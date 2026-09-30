part of '../creations_page.dart';

class _WidgetPreviewSheet extends StatelessWidget {
  const _WidgetPreviewSheet({
    required this.creation,
    required this.spec,
    required this.onAddToHomeScreen,
  });

  final FinnCreation creation;
  final HomeWidgetSpec spec;
  final VoidCallback onAddToHomeScreen;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: FluxColors.canvasOf(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(FluxRadius.sheet),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.paddingOf(context).bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              child: Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: FluxColors.lineOf(context),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              creation.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              L10n.of(context).creationsWidgetPreview,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FluxColors.mutedOf(context),
                  ),
            ),
            const SizedBox(height: 18),
            _WidgetSurface(spec: spec),
            const SizedBox(height: 18),
            FluxPillButton(
              label: L10n.of(context).creationsAddToHomeScreen,
              icon: FluxIcons.add,
              onTap: onAddToHomeScreen,
            ),
          ],
        ),
      );
}

/// Approximates what the launcher widget will render.
///
/// The real widget is built by Kotlin from the same spec through `RemoteViews`,
/// so this is a preview of the same data and accent, not a separate design.
class _WidgetSurface extends StatelessWidget {
  const _WidgetSurface({required this.spec});

  final HomeWidgetSpec spec;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CreationPalette.pastel(spec.accent),
          borderRadius: BorderRadius.circular(FluxRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              spec.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: CreationPalette.onPastel,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 10),
            for (final row in spec.rows.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: CreationPalette.onPastelMuted,
                            ),
                      ),
                    ),
                    Text(
                      row.value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: CreationPalette.onPastel,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            if (spec.footer.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                spec.footer,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: CreationPalette.onPastelMuted,
                    ),
              ),
            ],
          ],
        ),
      );
}

class _DocumentSheet extends StatelessWidget {
  const _DocumentSheet({required this.creation, required this.onDelete});

  final FinnCreation creation;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final artifact = creation.artifact;
    final sections = artifact is LegacyDocumentArtifact
        ? artifact.sections
        : const <CreationSection>[];
    return Container(
      height: MediaQuery.sizeOf(context).height * .88,
      decoration: BoxDecoration(
        color: FluxColors.canvasOf(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(FluxRadius.sheet),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    creation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: onDelete,
                  child: Text(
                    L10n.of(context).commonDelete,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: FluxColors.destructiveOf(context),
                        ),
                  ),
                ),
                FluxIconButton(
                  icon: FluxIcons.close,
                  tooltip: L10n.of(context).commonClose,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (creation.summary.isNotEmpty)
                  Text(
                    creation.summary,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: FluxColors.mutedOf(context),
                        ),
                  ),
                const SizedBox(height: 20),
                for (final section in sections)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        color: FluxColors.cardOf(context),
                        borderRadius: BorderRadius.circular(FluxRadius.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.heading,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            section.body,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: FluxColors.mutedOf(context),
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  L10n.of(context).creationsOriginalBrief,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: FluxColors.mutedOf(context),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  creation.prompt,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
