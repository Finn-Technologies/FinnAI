import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/spec/deck_spec.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/features/creations/spec/safe_expression.dart';
import 'package:finn_ai/src/features/creations/spec/widget_spec.dart';

/// Deterministic starter creations used when generation and one repair round
/// both fail to produce a valid spec.
///
/// The point is that the user always gets something they can open rather than
/// an error, so these are deliberately real and usable: the app fallback is a
/// working counter, not a placeholder message. They are built through the same
/// model types as a generated spec, so nothing downstream needs a special case.
abstract final class CreationFallbacks {
  static CreationArtifact forKind(CreationKind kind) => switch (kind) {
        CreationKind.app => MiniAppArtifact(_counterApp()),
        CreationKind.widget => WidgetArtifact(_simpleWidget()),
        CreationKind.presentation => PresentationArtifact(_starterDeck()),
      };

  /// A working counter, exercising `text`, `progress`, a `set` action and
  /// `reset` — the smallest app that proves the runtime works.
  static MiniAppSpec _counterApp() => MiniAppSpec(
        title: 'Counter',
        accent: MiniAppAccent.mint,
        nodes: [
          const TextNode(
            value: 'Count: {count}',
            role: MiniAppTextRole.title,
          ),
          const ProgressNode(bind: 'count', max: 10),
          ButtonNode(
            label: 'Add one',
            action: SetAction(
              key: 'count',
              source: 'count + 1',
              expression: SafeExpression.parse('count + 1'),
            ),
          ),
          const ButtonNode(label: 'Clear', action: ResetAction()),
        ],
      );

  static HomeWidgetSpec _simpleWidget() => const HomeWidgetSpec(
        title: 'Finn AI',
        accent: MiniAppAccent.mint,
        rows: [
          HomeWidgetRow(label: 'Today', value: '0'),
          HomeWidgetRow(label: 'Goal', value: '1'),
        ],
        footer: 'Tap to open',
      );

  static DeckSpec _starterDeck() => const DeckSpec(
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
      );
}
