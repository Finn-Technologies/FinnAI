import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/creations/spec/spec_json.dart';

/// One slide of a generated presentation.
@immutable
class DeckSlide {
  const DeckSlide({
    required this.title,
    required this.bullets,
    this.notes = '',
  });

  final String title;
  final List<String> bullets;
  final String notes;

  factory DeckSlide.fromJson(Map<String, Object?> json) => DeckSlide(
        title: SpecJson.string(json, 'title'),
        bullets: SpecJson.stringList(json, 'bullets'),
        notes: SpecJson.stringOr(json, 'notes', ''),
      );

  Map<String, Object?> toJson() => {
        'title': title,
        'bullets': bullets,
        'notes': notes,
      };
}

/// A generated presentation, viewable in-app and exportable as `.pptx`.
@immutable
class DeckSpec {
  const DeckSpec({required this.title, required this.slides});

  final String title;
  final List<DeckSlide> slides;

  factory DeckSpec.fromJson(Map<String, Object?> json) => DeckSpec(
        title: SpecJson.string(json, 'title'),
        slides: SpecJson.objectList(json, 'slides')
            .map(DeckSlide.fromJson)
            .toList(growable: false),
      );

  Map<String, Object?> toJson() => {
        'title': title,
        'slides': slides.map((slide) => slide.toJson()).toList(),
      };
}
