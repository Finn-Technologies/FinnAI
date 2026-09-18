import 'package:finn_ai/src/features/creations/deck/deck_viewer.dart';
import 'package:finn_ai/src/features/creations/spec/deck_spec.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The deck viewer pages horizontally, so its header has no vertical scroll to
/// follow. It must still lay out and page without a scroll source behind it.
void main() {
  const deck = DeckSpec(
    title: 'Quarterly Review',
    slides: [
      DeckSlide(title: 'Quarterly Review', bullets: ['Opens the deck']),
      DeckSlide(
        title: 'Numbers',
        bullets: ['Revenue up', 'Churn down'],
        notes: 'Keep this brief.',
      ),
    ],
  );

  testWidgets('a paged deck renders and pages without a scroll source', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: FluxTheme.light,
        home: DeckViewer(
          title: deck.title,
          deck: deck,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Quarterly Review'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(PageView), const Offset(-320, 0));
    await tester.pumpAndSettle();

    expect(find.text('Numbers'), findsWidgets);
    expect(find.text('Keep this brief.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('previous-slide control is mirrored and clears the export FAB', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: FluxTheme.light,
        home: DeckViewer(
          title: deck.title,
          deck: deck,
          onBack: () {},
          onExport: () {},
        ),
      ),
    );
    await tester.pump();

    // A right-pointing arrow on "previous" read as "next": it must be rotated.
    final transforms = tester.widgetList<Transform>(
      find.ancestor(
        of: find.byTooltip('Previous slide'),
        matching: find.byType(Transform),
      ),
    );
    expect(
      transforms.any((t) => (t.transform.entry(0, 0) + 1).abs() < 0.001),
      isTrue,
      reason: 'the previous-slide glyph should be rotated 180°',
    );

    // The export FAB floats over the bottom-right corner where the footer's
    // next control lives, so the two must not overlap.
    expect(find.byType(FloatingActionButton), findsOneWidget);
    final fab = tester.getRect(find.byType(FloatingActionButton));
    final next = tester.getRect(find.byTooltip('Next slide'));
    expect(fab.overlaps(next), isFalse);
    expect(tester.takeException(), isNull);
  });
}
