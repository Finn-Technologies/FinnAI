import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/creations/spec/deck_spec.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/features/creations/spec/spec_json.dart';
import 'package:finn_ai/src/features/creations/spec/widget_spec.dart';

/// What a creation is, which decides what it can be opened as.
enum CreationKind {
  app('App'),
  widget('Widget'),
  presentation('Presentation');

  const CreationKind(this.label);

  /// English data used inside generation prompts and persisted records.
  ///
  /// Never rendered directly — see `_kindLabel` in the page, which resolves the
  /// localized label.
  final String label;

  /// Parses a persisted kind name, falling back to [CreationKind.app].
  static CreationKind parse(Object? raw) {
    if (raw is! String) return CreationKind.app;
    for (final kind in CreationKind.values) {
      if (kind.name == raw) return kind;
    }
    return CreationKind.app;
  }
}

/// A heading/body pair carried by creations made before artifacts existed.
///
/// Retained only so upgraded installs keep rendering their old creations.
/// Nothing generates new sections.
@immutable
class CreationSection {
  const CreationSection({required this.heading, required this.body});

  final String heading;
  final String body;

  Map<String, Object?> toJson() => {'heading': heading, 'body': body};

  factory CreationSection.fromJson(Map<String, Object?> json) =>
      CreationSection(
        heading: SpecJson.stringOr(json, 'heading', ''),
        body: SpecJson.stringOr(json, 'body', ''),
      );
}

/// The runnable payload of a creation.
sealed class CreationArtifact {
  const CreationArtifact();

  /// Rebuilds the right variant from a persisted `{type, …}` record.
  factory CreationArtifact.fromJson(Map<String, Object?> json) {
    final type = SpecJson.string(json, 'type').toLowerCase();
    return switch (type) {
      'app' => MiniAppArtifact(
          MiniAppSpec.fromJson(SpecJson.object(json, 'spec')),
        ),
      'widget' => WidgetArtifact(
          HomeWidgetSpec.fromJson(SpecJson.object(json, 'spec')),
        ),
      'presentation' => PresentationArtifact(
          DeckSpec.fromJson(SpecJson.object(json, 'spec')),
        ),
      'document' => LegacyDocumentArtifact(
          summary: SpecJson.stringOr(json, 'summary', ''),
          sections: SpecJson.objectList(
            json,
            'sections',
          ).map(CreationSection.fromJson).toList(growable: false),
          kind: CreationKind.parse(json['kind']),
        ),
      _ => throw FormatException('"$type" is not a known artifact type'),
    };
  }

  Map<String, Object?> toJson();

  /// The kind this artifact belongs to.
  CreationKind get kind;
}

/// A runnable, sandboxed mini application.
final class MiniAppArtifact extends CreationArtifact {
  const MiniAppArtifact(this.spec);

  final MiniAppSpec spec;

  @override
  CreationKind get kind => CreationKind.app;

  @override
  Map<String, Object?> toJson() => {'type': 'app', 'spec': spec.toJson()};
}

/// A layout for the Android launcher widget.
final class WidgetArtifact extends CreationArtifact {
  const WidgetArtifact(this.spec);

  final HomeWidgetSpec spec;

  @override
  CreationKind get kind => CreationKind.widget;

  @override
  Map<String, Object?> toJson() => {'type': 'widget', 'spec': spec.toJson()};
}

/// A slide deck, viewable in-app and exportable to `.pptx`.
final class PresentationArtifact extends CreationArtifact {
  const PresentationArtifact(this.spec);

  final DeckSpec spec;

  @override
  CreationKind get kind => CreationKind.presentation;

  @override
  Map<String, Object?> toJson() => {
        'type': 'presentation',
        'spec': spec.toJson(),
      };
}

/// A pre-artifact creation, preserved through the storage upgrade.
///
/// [kind] is carried through from the original record so an upgraded install
/// keeps old creations in the filter category the user last saw them in, even
/// though the body can only be rendered as a document.
final class LegacyDocumentArtifact extends CreationArtifact {
  const LegacyDocumentArtifact({
    required this.summary,
    required this.sections,
    this.kind = CreationKind.app,
  });

  final String summary;
  final List<CreationSection> sections;

  @override
  final CreationKind kind;

  @override
  Map<String, Object?> toJson() => {
        'type': 'document',
        'kind': kind.name,
        'summary': summary,
        'sections': sections.map((section) => section.toJson()).toList(),
      };
}

/// One saved creation.
@immutable
class FinnCreation {
  const FinnCreation({
    required this.id,
    required this.prompt,
    required this.title,
    required this.summary,
    required this.artifact,
    required this.createdAt,
  });

  final String id;
  final String prompt;
  final String title;
  final String summary;
  final CreationArtifact artifact;
  final DateTime createdAt;

  CreationKind get kind => artifact.kind;

  Map<String, Object?> toJson() => {
        'id': id,
        'prompt': prompt,
        'title': title,
        'summary': summary,
        'artifact': artifact.toJson(),
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  /// Records saved with the old template system carry an extra `template`
  /// key. It is ignored: their artifact is already the finished creation.
  factory FinnCreation.fromJson(Map<String, Object?> json) => FinnCreation(
        id: SpecJson.string(json, 'id'),
        prompt: SpecJson.stringOr(json, 'prompt', ''),
        title: SpecJson.string(json, 'title'),
        summary: SpecJson.stringOr(json, 'summary', ''),
        artifact: CreationArtifact.fromJson(SpecJson.object(json, 'artifact')),
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}
