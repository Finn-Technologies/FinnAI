import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/templates/template_slots.dart';

/// A curated, valid-by-construction creation with named slots (ADR 0003).
///
/// The template owns layout, wiring and style; the model (or the user) only
/// supplies [slots]. A template can therefore never produce a spec the
/// validator rejects, and its output looks the same every time.
abstract class CreationTemplate {
  const CreationTemplate();

  /// Stable id, persisted with a creation so it can be edited later.
  String get id;

  CreationKind get kind;

  /// English name and purpose: used inside model prompts only. The UI resolves
  /// its own localised label from [id].
  String get englishName;
  String get purpose;

  List<TemplateSlot> get slots;

  /// Lower-case words, across the shipped locales, that suggest this template
  /// for a brief.
  List<String> get keywords;

  /// Builds the artifact. [values] are already sanitised.
  CreationArtifact build(SlotValues values);

  /// The tile title for a built creation.
  String titleFor(SlotValues values) => values.text('title');

  /// A one-line description for the tile.
  String summaryFor(SlotValues values) => '';
}
