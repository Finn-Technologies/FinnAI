import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/templates/app_templates.dart';
import 'package:finn_ai/src/features/creations/templates/creation_template.dart';
import 'package:finn_ai/src/features/creations/templates/widget_templates.dart';

/// Every template Finn can build, and the rule for choosing one.
abstract final class CreationTemplates {
  static const List<CreationTemplate> all = [
    CounterTemplate(),
    ChecklistTemplate(),
    ListTemplate(),
    ScoreboardTemplate(),
    CounterWidgetTemplate(),
    ChecklistWidgetTemplate(),
    TrackerWidgetTemplate(),
    StatWidgetTemplate(),
    RowsWidgetTemplate(),
  ];

  static List<CreationTemplate> forKind(CreationKind kind) =>
      all.where((template) => template.kind == kind).toList(growable: false);

  static CreationTemplate? byId(String? id) {
    for (final template in all) {
      if (template.id == id) return template;
    }
    return null;
  }

  /// The template a brief most likely wants.
  ///
  /// Deterministic on purpose: the 1.6B model is not asked to choose, only to
  /// fill in the chosen template, which removes the commonest failure (a wrong
  /// or invented structure). Ties and no-match fall to the kind's first
  /// template. Keywords are matched as whole words so "list" does not fire on
  /// "specialist".
  static CreationTemplate pick(CreationKind kind, String brief) {
    final candidates = forKind(kind);
    assert(candidates.isNotEmpty, 'no templates for $kind');
    final words = brief
        .toLowerCase()
        .split(RegExp(r"[^\p{L}\p{N}\-'’]+", unicode: true))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    final padded = ' ${words.join(' ')} ';
    var best = candidates.first;
    var bestScore = 0;
    for (final template in candidates) {
      var score = 0;
      for (final keyword in template.keywords) {
        if (padded.contains(' $keyword ')) score++;
      }
      if (score > bestScore) {
        best = template;
        bestScore = score;
      }
    }
    return best;
  }
}
