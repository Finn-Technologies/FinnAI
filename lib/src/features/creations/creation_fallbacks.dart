import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/spec/deck_spec.dart';

/// The deterministic starter used when a presentation could not be generated.
///
/// Apps and widgets have no fallback of this kind: a failed fill still builds
/// the requested template from the brief. A deck has no template, so it gets a
/// small outline the user can open and adapt rather than an error.
abstract final class CreationFallbacks {
  static CreationArtifact starterDeck() => const PresentationArtifact(
        DeckSpec(
          title: 'New Presentation',
          slides: [
            DeckSlide(
              title: 'New Presentation',
              bullets: ['What this is about', 'What you will take away'],
            ),
            DeckSlide(
              title: 'Key Points',
              bullets: ['First point', 'Second point', 'Third point'],
            ),
            DeckSlide(
              title: 'Next Steps',
              bullets: ['Decide the next action', 'Share with the team'],
            ),
          ],
        ),
      );
}
