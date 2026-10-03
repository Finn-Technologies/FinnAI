part of '../creations_page.dart';

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
