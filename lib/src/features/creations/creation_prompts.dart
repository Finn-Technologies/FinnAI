import 'package:finn_ai/src/features/creations/spec/deck_theme.dart';
import 'package:finn_ai/src/features/creations/spec/spec_limits.dart';

/// Builds the JSON-only prompt that drives presentation generation.
///
/// Apps and widgets do not use this: the model fills a template's slots
/// instead (`templates/slot_prompt.dart`). A deck is prose, so it stays a
/// free-form spec the validator checks.
abstract final class CreationPrompts {
  /// Generates an original app/widget spec without selecting a preset.
  static String buildFreeform({
    required String brief,
    required String kind,
    required String variation,
    String? repairIssues,
  }) {
    final buffer = StringBuffer()
      ..writeln(
        'You are designing an original $kind for Finn. '
        'Reply with exactly one JSON object and nothing else.',
      )
      ..writeln()
      ..writeln(_freeformSchema(kind))
      ..writeln()
      ..writeln(
        'Originality rules: design this from the Brief itself. '
        'Do not copy a remembered preset, tutorial example, or previous '
        'creation. Do not automatically make a counter, checklist, shopping '
        'list, or generic dashboard unless the Brief actually calls for it. '
        'Choose a useful structure and interaction pattern that fits the '
        'specific request. Variation key: $variation.',
      );
    if (repairIssues != null && repairIssues.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('The previous JSON was rejected. Fix these issues:')
        ..writeln(repairIssues.trim());
    }
    buffer
      ..writeln()
      ..writeln('Brief: "$brief"')
      ..writeln()
      ..writeln('Return a fresh JSON object for this Brief only.');
    return buffer.toString();
  }

  static String _freeformSchema(String kind) {
    if (kind == 'widget') {
      return '''
Widget JSON:
{"title":"...","accent":"mint|blue|lime|amber|rose|violet|sky","rows":[{"label":"...","value":"..."}],"footer":"...","kind":"display|counter|checklist|tracker","step":1,"goal":0}

Rules:
- title: short and specific.
- 1 to 4 rows; every row has a useful label and value.
- footer is optional short supporting text.
- display is read-only; counter has one number and +/- behaviour; checklist has rows that can be ticked; tracker has rows whose numbers increase.
- Use counter/checklist/tracker only when they fit the Brief.
- step is 1..1000 for counter/tracker. goal is 0 or a positive counter goal.
- accent must be one of the listed words.''';
    }
    return '''
Mini-app JSON:
{"title":"...","accent":"mint|blue|lime|amber|rose|violet|sky","nodes":[...]}

Node types:
- text, button, field, toggle, slider, list, progress, choice, image, row, column, spacer
- text: {"type":"text","value":"...","style":"title|body|caption"}
- button: {"type":"button","label":"...","action":ACTION}
- field/toggle/slider/choice use a state "key"; list/progress use a "bind" key.
- image uses either an emoji or an https URL.
- row/column use "children".

Actions:
- set {"kind":"set","key":"name","expr":"amount + 1"}
- toggle {"kind":"toggle","key":"name"}
- increment {"kind":"increment","key":"name","by":1}
- append {"kind":"append","key":"items","value":"{draft}","clear":"draft"}
- reset {"kind":"reset"}

Rules:
- 1 to ${SpecLimits.maxNodes} nodes, maximum depth ${SpecLimits.maxNodeDepth}.
- Anything displayed must have a state key that is written by a field, toggle, slider, choice, or action.
- Use several node types when useful; do not fill the screen with repeated text.
- Solve the Brief specifically instead of imitating a generic productivity app.
- accent must be one of the listed words.''';
  }

  /// The generation prompt for a presentation about [brief].
  static String build({required String brief, String? repairIssues}) {
    final buffer = StringBuffer()
      ..writeln(
        'You design small presentations that run inside Finn. '
        'Reply with one JSON object and nothing else.',
      )
      ..writeln()
      ..write(_deckInstruction)
      ..writeln();
    if (repairIssues != null && repairIssues.trim().isNotEmpty) {
      buffer
        ..writeln('That JSON was rejected for these reasons:')
        ..writeln(repairIssues.trim())
        ..writeln();
    }
    // The Brief comes last, after the Example. A 1.6B model continues from
    // whatever it read most recently, so ending on the shape reference made it
    // emit the reference's own content. Closing on the Brief, with the ban on
    // reusing the Example made explicit, keeps the output about the request.
    buffer
      ..writeln(
        'Now design the presentation described by this Brief. '
        'Do not reuse anything from the Example above — not its title, '
        'wording or slides. The Example only shows the JSON structure.',
      )
      ..writeln()
      ..writeln('Brief: "$brief"')
      ..writeln()
      ..writeln(
        repairIssues != null && repairIssues.trim().isNotEmpty
            ? 'Return the corrected JSON object for this Brief only, '
                'and nothing else.'
            : 'Return the JSON object for this Brief only, and nothing else.',
      );
    return buffer.toString();
  }

  static String get _deckInstruction => '''
JSON shape:
{"title":"short name","summary":"one sentence","theme":"midnight","slides":[{"title":"Slide title","layout":"bullets","bullets":["point one","point two"],"notes":"speaker note"}]}

Rules:
- "theme" is exactly one of these words, on its own: ${DeckTheme.names}. Pick the one that suits the topic.
- "layout" is exactly one of these words, on its own: ${DeckLayout.names}. Use "title" for the first slide, "section" to start a new part, "quote" for one memorable sentence (put it as the only bullet) and "bullets" for everything else.
- Between 4 and ${SpecLimits.maxSlides} slides.
- At most ${SpecLimits.maxBulletsPerSlide} bullets per slide, each at most ${SpecLimits.maxBulletChars} characters.
- The first slide introduces the topic. The last slide closes it.
- Bullets are short phrases, not sentences.

Example (structure only — never reuse its content):
{"title":"Quarterly Review","summary":"A short review deck.","theme":"paper","slides":[{"title":"Quarterly Review","layout":"title","bullets":["Revenue and churn","What changed"],"notes":"Welcome everyone."},{"title":"What Changed","layout":"bullets","bullets":["Revenue up 12%","Churn down to 3%"],"notes":"Lead with growth."}]}''';
}
