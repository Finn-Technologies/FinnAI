part of '../creations_page.dart';

/// Resolves a controller failure code to the sentence the user reads.
String _failureMessage(BuildContext context, CreationFailure failure) {
  final l10n = L10n.of(context);
  return switch (failure) {
    CreationFailure.load => l10n.creationsLoadFailed,
    CreationFailure.create => l10n.creationsFailed,
    CreationFailure.delete => l10n.creationsDeleteFailed,
  };
}

/// A one-line, localized description of what the creation contains.
String _artifactDescriptor(BuildContext context, FinnCreation creation) {
  final l10n = L10n.of(context);
  return switch (creation.artifact) {
    MiniAppArtifact(:final spec) =>
      l10n.creationsElementCount(spec.nodes.length),
    WidgetArtifact(:final spec) => l10n.creationsRowCount(spec.rows.length),
    PresentationArtifact(:final spec) =>
      l10n.creationsSlideCount(spec.slides.length),
    LegacyDocumentArtifact() => _kindLabel(context, creation.kind),
  };
}

/// Localized label for a creation kind (the enum's own label stays English data
/// used for prompts and persistence).
String _kindLabel(BuildContext context, CreationKind kind) => switch (kind) {
      CreationKind.app => L10n.of(context).creationsKindApp,
      CreationKind.widget => L10n.of(context).creationsKindWidget,
      CreationKind.presentation => L10n.of(context).creationsKindPresentation,
    };

/// Plural label used by the gallery filters, matching the design.
String _filterLabel(BuildContext context, CreationKind kind) => switch (kind) {
      CreationKind.app => L10n.of(context).creationsFilterApps,
      CreationKind.widget => L10n.of(context).creationsFilterWidgets,
      CreationKind.presentation =>
        L10n.of(context).creationsFilterPresentations,
    };

/// Which surface the page is showing.
enum _Mode { gallery, builder }

List<List<dynamic>> _iconFor(FinnCreation creation) =>
    creation.artifact is LegacyDocumentArtifact
        ? FluxIcons.note
        : _kindIcon(creation.kind);

List<List<dynamic>> _kindIcon(CreationKind kind) => switch (kind) {
      CreationKind.app => FluxIcons.canvas,
      CreationKind.widget => FluxIcons.chip,
      CreationKind.presentation => FluxIcons.flows,
    };

String? _emojiFor(FinnCreation creation) {
  final artifact = creation.artifact;
  if (artifact is! MiniAppArtifact) return null;
  for (final node in artifact.spec.nodes) {
    if (node is ImageNode && node.emoji.trim().isNotEmpty) {
      return node.emoji.trim();
    }
  }
  return null;
}
