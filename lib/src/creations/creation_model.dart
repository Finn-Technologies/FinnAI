import 'package:flutter/foundation.dart';

enum CreationKind {
  app('App'),
  widget('Widget'),
  presentation('Presentation');

  const CreationKind(this.label);
  final String label;
}

@immutable
class CreationSection {
  const CreationSection({required this.heading, required this.body});

  final String heading;
  final String body;

  Map<String, Object?> toJson() => {'heading': heading, 'body': body};

  factory CreationSection.fromJson(Map<String, Object?> json) =>
      CreationSection(
        heading: (json['heading'] as String?)?.trim() ?? '',
        body: (json['body'] as String?)?.trim() ?? '',
      );
}

@immutable
class CreationDraft {
  const CreationDraft({
    required this.title,
    required this.summary,
    required this.sections,
  });

  final String title;
  final String summary;
  final List<CreationSection> sections;
}

@immutable
class FinnCreation {
  const FinnCreation({
    required this.id,
    required this.kind,
    required this.prompt,
    required this.title,
    required this.summary,
    required this.sections,
    required this.createdAt,
  });

  final String id;
  final CreationKind kind;
  final String prompt;
  final String title;
  final String summary;
  final List<CreationSection> sections;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'prompt': prompt,
    'title': title,
    'summary': summary,
    'sections': sections.map((section) => section.toJson()).toList(),
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory FinnCreation.fromJson(Map<String, Object?> json) {
    final rawSections = json['sections'];
    return FinnCreation(
      id: json['id'] as String,
      kind: CreationKind.values.byName(json['kind'] as String),
      prompt: json['prompt'] as String? ?? '',
      title: json['title'] as String,
      summary: json['summary'] as String? ?? '',
      sections: rawSections is List
          ? rawSections
                .whereType<Map>()
                .map(
                  (section) => CreationSection.fromJson(
                    Map<String, Object?>.from(section),
                  ),
                )
                .where(
                  (section) =>
                      section.heading.isNotEmpty || section.body.isNotEmpty,
                )
                .toList(growable: false)
          : const [],
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }
}
