import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/spec/deck_theme.dart';
import 'package:finn_ai/src/features/creations/spec/spec_limits.dart';

/// Builds the prompts that make the model design a creation itself.
///
/// The model is the author: it decides what a mini app contains, how its
/// buttons behave, what a widget shows and what each slide says. The prompt
/// only describes the closed vocabulary it must write in, so the result can
/// be validated and run. Nothing here picks a layout or a set of fields for it.
abstract final class CreationPrompts {
  /// The prompt asking for one complete creation of [kind] about [brief].
  static String build({
    required CreationKind kind,
    required String brief,
    String? repairIssues,
  }) {
    final buffer = StringBuffer()
      ..writeln(
        'You design small, working ${_noun(kind)}s that run inside Finn. '
        'Reply with one JSON object and nothing else.',
      )
      ..writeln()
      ..writeln(_instruction(kind))
      ..writeln();
    if (repairIssues != null && repairIssues.trim().isNotEmpty) {
      buffer
        ..writeln('Your previous JSON was rejected for these reasons:')
        ..writeln(repairIssues.trim())
        ..writeln('Fix every one of them and return the whole object again.')
        ..writeln();
    }
    buffer
      ..writeln(
        'Design the ${_noun(kind)} described by this brief. Decide its '
        'content, its behaviour and its wording yourself, so it fits the '
        'brief exactly. Do not copy the example; it only shows the format.',
      )
      ..writeln()
      ..writeln('Brief: "$brief"')
      ..writeln()
      ..writeln(
        'Return the JSON object for this brief only, and nothing else.',
      );
    return buffer.toString();
  }

  static String _noun(CreationKind kind) => switch (kind) {
        CreationKind.app => 'mini app',
        CreationKind.widget => 'home-screen widget',
        CreationKind.presentation => 'presentation',
      };

  static String _instruction(CreationKind kind) => switch (kind) {
        CreationKind.app => _appInstruction,
        CreationKind.widget => _widgetInstruction,
        CreationKind.presentation => _deckInstruction,
      };

  static String get _appInstruction => '''
A mini app is a small screen made of nodes. You write every node yourself.

JSON shape:
{"title":"short name","accent":"mint","nodes":[{"type":"text","value":"Hello","style":"title"}]}

Node types (use only these, with exactly these fields):
- text: {"type":"text","value":"words, may use {key}","style":"title|body|caption"}
- button: {"type":"button","label":"text","action":ACTION}
- field: {"type":"field","key":"name","hint":"placeholder"}
- toggle: {"type":"toggle","key":"name","label":"text"}
- slider: {"type":"slider","key":"name","min":0,"max":10}
- choice: {"type":"choice","key":"name","options":["one","two"]}
- list: {"type":"list","bind":"name","empty":"text shown when empty"}
- progress: {"type":"progress","bind":"name","max":10}
- image: {"type":"image","emoji":"one emoji"}
- row: {"type":"row","children":[NODES]}
- column: {"type":"column","children":[NODES]}
- spacer: {"type":"spacer","size":12}

Actions (what a button does to the app's state):
- set: {"kind":"set","key":"name","expr":"count + 1"}
- toggle: {"kind":"toggle","key":"name"}
- increment: {"kind":"increment","key":"name","by":1}
- append: {"kind":"append","key":"items","value":"{draft}","clear":"draft"}
- reset: {"kind":"reset"}

Rules:
- State lives in named keys. A key is letters, digits or _, starting with a letter.
- A text node shows a key with {key}. An expr may use only integers, + - * / % and parentheses, plus key names.
- Every key that a text, list, progress or expr reads must be written by a field, toggle, slider, choice, button or append.
- Make the app do the job the brief describes. Use keys and buttons that really model it, so pressing buttons changes what is shown.
- At most ${SpecLimits.maxNodes} nodes in total, nested at most ${SpecLimits.maxNodeDepth} levels.
- The "title" is at most ${SpecLimits.maxTitleChars} characters. Text is at most ${SpecLimits.maxTextChars} characters, labels at most ${SpecLimits.maxLabelChars}.
- "accent" is exactly one of: ${SpecLimits.accentNames}.
- Never use "{" or "}" in a value except to show a key, e.g. "{count}".
- Put the words, numbers and options the brief needs; do not leave placeholders like "Item 1".
''';

  static String get _widgetInstruction => '''
A home-screen widget shows a few lines and may be tapped. You write its content.

JSON shape:
{"title":"short name","accent":"blue","kind":"display","rows":[{"label":"Goal","value":"8"}],"footer":"short line"}

"kind" is exactly one of:
- display: shows its rows only.
- counter: one number with minus and plus. Use exactly one row whose value is a whole number. Add "goal":N for a target and "step":N for how much a tap adds.
- checklist: rows that tick on and off when tapped. Each row is one thing to do.
- tracker: rows that each count up when tapped. Every row's value is a whole number. Add "step":N for how much a tap adds.

Rules:
- At most ${SpecLimits.maxWidgetRows} rows.
- The "title" is at most ${SpecLimits.maxTitleChars} characters. A label is at most ${SpecLimits.maxLabelChars} characters, a value at most ${SpecLimits.maxWidgetValueChars}.
- "accent" is exactly one of: ${SpecLimits.accentNames}.
- Write the actual items, numbers and words the brief needs.
''';

  static String get _deckInstruction => '''
A presentation is a short slide deck. You write every slide.

JSON shape:
{"title":"short name","summary":"one sentence","theme":"midnight","slides":[{"title":"Slide title","layout":"bullets","bullets":["point one","point two"],"notes":"speaker note"}]}

Rules:
- "theme" is exactly one of: ${DeckTheme.names}. Pick the one that suits the topic.
- "layout" is exactly one of: ${DeckLayout.names}. Use "title" for the first slide, "section" to start a new part, "quote" for one memorable sentence (as the only bullet), and "bullets" for everything else.
- Between 4 and ${SpecLimits.maxSlides} slides.
- The "title" is at most ${SpecLimits.maxTitleChars} characters. At most ${SpecLimits.maxBulletsPerSlide} bullets per slide, each at most ${SpecLimits.maxBulletChars} characters.
- The first slide introduces the topic. The last slide closes it.
- Bullets are short phrases, not sentences. Write real content for the brief.
''';
}
