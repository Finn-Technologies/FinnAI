part of '../creations_page.dart';

/// The finished creation, presented as the assistant's answer.
class _ArtifactCard extends StatelessWidget {
  const _ArtifactCard({
    required this.creation,
    required this.onOpen,
    required this.onAddToHomeScreen,
    required this.onExport,
  });

  final FinnCreation creation;
  final VoidCallback onOpen;
  final VoidCallback onAddToHomeScreen;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.creationsBuilderReady,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Material(
              color: FluxColors.controlOf(context),
              borderRadius: BorderRadius.circular(FluxRadius.card),
              child: InkWell(
                borderRadius: BorderRadius.circular(FluxRadius.card),
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CreationPreview(creation: creation),
                      const SizedBox(height: 10),
                      Text(
                        creation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        _artifactDescriptor(context, creation),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: FluxColors.actionOf(context),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            FinnButton(label: l10n.commonOpen, onTap: onOpen),
            const SizedBox(height: 10),
            FinnButton(
              label: creation.kind == CreationKind.presentation
                  ? l10n.creationsExportDeck
                  : l10n.creationsAddToHomeScreen,
              secondary: true,
              onTap: creation.kind == CreationKind.presentation
                  ? onExport
                  : onAddToHomeScreen,
            ),
          ],
        ),
      ),
    );
  }
}
