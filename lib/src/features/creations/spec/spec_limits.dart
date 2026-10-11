/// Caps shared by the spec validator and the generation prompts.
///
/// The prompt builder tells the model these limits and the validator enforces
/// exactly the same numbers, so a spec that satisfies the instructions can
/// never be rejected for a limit it was not told about. **Every limit added
/// here must also be stated in `creation_prompts.dart`** — `creation_prompts`
/// tests assert that, because a rule the model was never given is a rule it can
/// only fail by accident.
abstract final class SpecLimits {
  /// Most nodes allowed in one mini app, counted across all containers.
  static const int maxNodes = 40;

  /// Deepest container nesting (a node inside a `row` inside a `column` is 3).
  static const int maxNodeDepth = 3;

  /// Longest allowed label, hint, or caption string.
  static const int maxLabelChars = 60;

  /// Longest allowed free-text body (list placeholders, image emoji).
  static const int maxTextChars = 200;

  /// Most options allowed on a `choice` node.
  static const int maxChoices = 4;

  /// Most rows allowed in a home-screen widget spec.
  static const int maxWidgetRows = 4;

  /// Longest allowed widget row value, in characters.
  static const int maxWidgetValueChars = 18;

  /// Most slides allowed in one presentation.
  static const int maxSlides = 12;

  /// Most bullets allowed on one slide.
  static const int maxBulletsPerSlide = 6;

  /// Longest allowed bullet text, in characters.
  static const int maxBulletChars = 140;

  /// Longest allowed presentation title, in characters.
  static const int maxTitleChars = 80;

  /// Longest allowed summary shown on a creation tile.
  static const int maxSummaryChars = 160;

  /// Longest allowed expression source, in characters.
  static const int maxExpressionChars = 120;

  /// Largest allowed value on a `spacer` node.
  static const int maxSpacerSize = 200;

  /// Accent choices, spelled as the model must emit them.
  ///
  /// The prompt shows one concrete value and lists these in prose. Printing the
  /// joined list inside the JSON shape made small models copy the whole pipe
  /// string as the value, which the parser then rejected.
  static const String accentNames =
      'mint, blue, lime, amber, rose, violet, sky';
}
