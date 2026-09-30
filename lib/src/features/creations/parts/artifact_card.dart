part of '../creations_page.dart';

/// The finished creation, presented as the assistant's answer.
class _ArtifactCard extends StatelessWidget {
  const _ArtifactCard({
    required this.creation,
    required this.usedFallback,
    required this.onOpen,
    required this.onAddToHomeScreen,
    required this.onExport,
    this.onEdit,
  });

  final FinnCreation creation;
  final bool usedFallback;
  final VoidCallback onOpen;
  final VoidCallback onAddToHomeScreen;
  final VoidCallback onExport;

  /// Edits the creation's slots. Null for a creation with no template.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final kind = creation.kind;
    final accent = CreationPalette.tileFor(kind);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .88,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FluxColors.cardOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.sheet),
          border: Border.all(
            color: FluxColors.lineOf(context).withValues(alpha: .8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: FluxIcon(
                      icon: _iconFor(creation),
                      color: CreationPalette.onPastel,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        creation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _artifactDescriptor(context, creation),
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: FluxColors.mutedOf(context),
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (usedFallback) ...[
              const SizedBox(height: 12),
              Text(
                L10n.of(context).creationsFallbackNote,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: FluxColors.mutedOf(context),
                      height: 1.35,
                    ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Flexible(
                  child: FluxPillButton(
                    label: L10n.of(context).commonOpen,
                    onTap: onOpen,
                  ),
                ),
                if (onEdit != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: FluxPillButton(
                      label: L10n.of(context).creationsEdit,
                      onTap: onEdit,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                FluxIconButton(
                  icon: kind == CreationKind.presentation
                      ? FluxIcons.download
                      : FluxIcons.add,
                  tooltip: kind == CreationKind.presentation
                      ? L10n.of(context).creationsExportDeck
                      : L10n.of(context).creationsAddToHomeScreen,
                  onTap: kind == CreationKind.presentation
                      ? onExport
                      : onAddToHomeScreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
