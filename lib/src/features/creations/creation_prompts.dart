import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/spec/spec_limits.dart';

/// Builds the JSON-only prompts that drive creation generation.
///
/// The node vocabulary is spelled out exhaustively rather than described in
/// prose. A 1.6B model will otherwise invent node types such as `webview` or
/// `chart`, which the validator then rejects and the repair round has to undo —
/// enumerating the closed set up front is measurably cheaper than repairing.
abstract final class CreationPrompts {
  /// The generation prompt for [kind].
  static String build({
    required CreationKind kind,
    required String brief,
    String? repairIssues,
  }) {
    final instruction = switch (kind) {
      CreationKind.app => _appInstruction,
      CreationKind.widget => _widgetInstruction,
      CreationKind.presentation => _deckInstruction,
    };
    final buffer = StringBuffer()
      ..writeln(
        'You design small ${kind.label.toLowerCase()}s that run inside Finn. '
        'Reply with one JSON object and nothing else.',
      )
      ..writeln()
      ..writeln('Brief: "$brief"')
      ..writeln()
      ..write(instruction)
      ..writeln();
    if (repairIssues != null && repairIssues.trim().isNotEmpty) {
      buffer
        ..writeln('That JSON was rejected for these reasons:')
        ..writeln(repairIssues.trim())
        ..writeln()
        ..writeln('Return the corrected JSON object only.');
    } else {
      buffer.writeln('Return only the JSON object.');
    }
    return buffer.toString();
  }

  static String get _appInstruction => '''
JSON shape:
{"title":"short name","summary":"one sentence","accent":"$_accents","nodes":[ … ]}

Each node needs a "type". The only allowed nodes are:
{"type":"text","value":"Taps: {count}","style":"title"}   // {key} shows a stored value
{"type":"button","label":"Tap","action":{"kind":"set","key":"count","expr":"count + 1"}}
{"type":"button","label":"Clear","action":{"kind":"reset"}}
{"type":"field","key":"note","hint":"Type here"}
{"type":"toggle","key":"done","label":"Done"}
{"type":"slider","key":"level","min":0,"max":10}
{"type":"list","bind":"items","empty":"Nothing yet"}
{"type":"progress","bind":"count","max":10}
{"type":"choice","key":"size","options":["Small","Large"]}
{"type":"image","emoji":"🌱"}
{"type":"row","children":[ … ]}
{"type":"column","children":[ … ]}
{"type":"spacer","size":12}

Actions are exactly one of:
{"kind":"set","key":"K","expr":"K + 1"}  {"kind":"toggle","key":"K"}
{"kind":"increment","key":"K","by":1}    {"kind":"append","key":"K","value":"text"}
{"kind":"reset"}

Rules:
- At most ${SpecLimits.maxNodes} nodes and at most ${SpecLimits.maxNodeDepth} levels of nesting.
- Expressions use only + - * / % ( ) and whole numbers. No words, no functions.
- Every {key} you display must also be set by a field, toggle, slider, choice or action.
- These node types are the complete set. Do not invent others.

Example:
{"title":"Tap Counter","summary":"Counts taps.","accent":"mint","nodes":[{"type":"text","value":"Taps: {count}","style":"title"},{"type":"progress","bind":"count","max":10},{"type":"button","label":"Tap","action":{"kind":"set","key":"count","expr":"count + 1"}},{"type":"button","label":"Clear","action":{"kind":"reset"}}]}''';

  static String get _widgetInstruction => '''
A widget sits on the phone's home screen. It cannot be interactive, so it shows
information only and opens the app when tapped.

JSON shape:
{"title":"short name","summary":"one sentence","accent":"$_accents","rows":[{"label":"Glasses","value":"3"}],"footer":"Tap to open"}

Rules:
- At most ${SpecLimits.maxWidgetRows} rows.
- Keep labels to a few words and each value at most ${SpecLimits.maxWidgetValueChars} characters.
- No buttons and no actions. The whole widget opens the app when tapped.

Example:
{"title":"Hydration","summary":"Tracks glasses of water.","accent":"sky","rows":[{"label":"Glasses","value":"3"},{"label":"Goal","value":"8"}],"footer":"Tap to open"}''';

  static String get _deckInstruction => '''
JSON shape:
{"title":"short name","summary":"one sentence","slides":[{"title":"Slide title","bullets":["point one","point two"],"notes":"speaker note"}]}

Rules:
- Between 4 and ${SpecLimits.maxSlides} slides.
- At most ${SpecLimits.maxBulletsPerSlide} bullets per slide, each at most ${SpecLimits.maxBulletChars} characters.
- The first slide introduces the topic. The last slide closes it.
- Bullets are short phrases, not sentences.

Example:
{"title":"Quarterly Review","summary":"A short review deck.","slides":[{"title":"Quarterly Review","bullets":["Revenue and churn","What changed"],"notes":"Welcome everyone."},{"title":"What Changed","bullets":["Revenue up 12%","Churn down to 3%"],"notes":"Lead with growth."}]}''';

  static const String _accents = 'mint|blue|lime|amber|rose|violet|sky';
}
