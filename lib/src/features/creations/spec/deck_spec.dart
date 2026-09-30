import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/creations/spec/deck_theme.dart';
import 'package:finn_ai/src/features/creations/spec/spec_json.dart';

/// One slide of a generated presentation.
@immutable
class DeckSlide {
  const DeckSlide({
    required this.title,
    required this.bullets,
    this.notes = '',
    this.layout,
  });

  final String title;
  final List<String> bullets;
  final String notes;

  /// How the slide is laid out. Null means "by position": the first slide is a
  /// title slide, the rest are bullet slides.
  final DeckLayout? layout;

  /// The layout actually used for the slide at [index].
  DeckLayout layoutAt(int index) =>
      layout ?? (index == 0 ? DeckLayout.title : DeckLayout.bullets);

  factory DeckSlide.fromJson(Map<String, Object?> json) => DeckSlide(
        title: SpecJson.string(json, 'title'),
        bullets: SpecJson.stringList(json, 'bullets'),
        notes: SpecJson.stringOr(json, 'notes', ''),
        layout: DeckLayout.tryParse(json['layout']),
      );

  Map<String, Object?> toJson() => {
        'title': title,
        'bullets': bullets,
        'notes': notes,
        if (layout != null) 'layout': layout!.name,
      };
}

/// A generated presentation, viewable in-app and exportable as `.pptx`.
@immutable
class DeckSpec {
  const DeckSpec({
    required this.title,
    required this.slides,
    this.theme = DeckTheme.paper,
  });

  final String title;
  final List<DeckSlide> slides;
  final DeckTheme theme;

  factory DeckSpec.fromJson(Map<String, Object?> json) => DeckSpec(
        title: SpecJson.string(json, 'title'),
        theme: DeckTheme.parse(json['theme']),
        slides: SpecJson.objectList(json, 'slides')
            .map(DeckSlide.fromJson)
            .toList(growable: false),
      );

  Map<String, Object?> toJson() => {
        'title': title,
        'theme': theme.name,
        'slides': slides.map((slide) => slide.toJson()).toList(),
      };
}
