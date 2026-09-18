import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/flux_context_menu.dart';

Finder _inkInside(Type widgetType) => find.descendant(
    of: find.byType(widgetType), matching: find.byType(InkWell));

Future<void> _tapAbovePainted(WidgetTester tester, Finder interactive) async {
  final rect = tester.getRect(interactive);
  await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
}

void main() {
  group('FluxIconButton', () {
    testWidgets('exposes a labelled, enabled button and forwards taps', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FluxIconButton(
              icon: FluxIcons.add,
              tooltip: 'Add item',
              onTap: () => taps++,
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(FluxIconButton)),
        isSemantics(
          label: 'Add item',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.byType(FluxIconButton));
      expect(taps, 1);

      handle.dispose();
    });

    testWidgets('marks a disabled control as disabled and dims it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FluxIconButton(icon: FluxIcons.add, tooltip: 'Add item'),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(FluxIconButton)),
        isSemantics(
          label: 'Add item',
          isButton: true,
          isEnabled: false,
        ),
      );

      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(FluxIconButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, .4);

      handle.dispose();
    });
  });

  testWidgets('BackControl is a single labelled back button', (tester) async {
    final handle = tester.ensureSemantics();

    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BackControl(onTap: () => taps++)),
      ),
    );

    expect(find.text('Back'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(BackControl)),
      isSemantics(label: 'Back', isButton: true, hasTapAction: true),
    );

    await tester.tap(find.byType(BackControl));
    expect(taps, 1);

    handle.dispose();
  });

  testWidgets('FluxDisclosure announces its expanded and collapsed states', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FluxDisclosure(
            leading: SizedBox.shrink(),
            label: 'Sources',
            expandLabel: 'Show sources',
            collapseLabel: 'Hide sources',
            child: Text('row'),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Show sources'), findsOneWidget);

    await tester.tap(find.text('Sources'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Hide sources'), findsOneWidget);

    handle.dispose();
  });

  group('48dp touch targets', () {
    testWidgets('FluxPillButton keeps its 36dp pill inside a 48dp hit box', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FluxPillButton(label: 'Next', onTap: () => taps++),
            ),
          ),
        ),
      );

      final box = find.byType(FluxPillButton);
      final ink = _inkInside(FluxPillButton);
      final inkSize = tester.getSize(ink);
      expect(inkSize.width, greaterThanOrEqualTo(48.0));
      expect(inkSize.height, greaterThanOrEqualTo(48.0));
      expect(tester.getSize(box), inkSize);

      final painted = tester.getSize(
        find.descendant(of: box, matching: find.byType(SizedBox)),
      );
      expect(painted.height, 36.0);
      expect(painted.height, lessThan(inkSize.height));

      await _tapAbovePainted(tester, ink);
      expect(taps, 1);
    });

    testWidgets('FluxPillButton compact keeps its 30dp pill inside a 48dp box',
        (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FluxPillButton(label: 'OK', onTap: () {}, compact: true),
            ),
          ),
        ),
      );

      final ink = _inkInside(FluxPillButton);
      final inkSize = tester.getSize(ink);
      expect(inkSize.width, greaterThanOrEqualTo(48.0));
      expect(inkSize.height, greaterThanOrEqualTo(48.0));

      final painted = tester.getSize(
        find.descendant(
          of: find.byType(FluxPillButton),
          matching: find.byType(SizedBox),
        ),
      );
      expect(painted.height, 30.0);
    });

    testWidgets('FluxDisclosure keeps its pill inside a 48dp hit box', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: FluxDisclosure(
                leading: SizedBox.shrink(),
                label: 'Sources',
                expandLabel: 'Show sources',
                collapseLabel: 'Hide sources',
                child: Text('row'),
              ),
            ),
          ),
        ),
      );

      final ink = _inkInside(FluxDisclosure);
      final inkSize = tester.getSize(ink);
      expect(inkSize.width, greaterThanOrEqualTo(48.0));
      expect(inkSize.height, greaterThanOrEqualTo(48.0));

      final painted = tester.getSize(
        find
            .descendant(
              of: find.byType(FluxDisclosure),
              matching: find.byType(Container),
            )
            .last,
      );
      expect(painted.height, 27.0);
      expect(painted.height, lessThan(inkSize.height));

      await _tapAbovePainted(tester, ink);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Hide sources'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('FluxDisclosureRow keeps its row inside a 48dp hit box', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 300,
                    child: FluxDisclosureRow(
                      leading: const Icon(Icons.circle, size: 16),
                      title: 'Title',
                      onTap: () => taps++,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final ink = _inkInside(FluxDisclosureRow);
      final inkSize = tester.getSize(ink);
      expect(inkSize.width, greaterThanOrEqualTo(48.0));
      expect(inkSize.height, greaterThanOrEqualTo(48.0));

      final painted = tester.getSize(
        find
            .descendant(
              of: find.byType(FluxDisclosureRow),
              matching: find.byType(Container),
            )
            .last,
      );
      expect(painted.height, 34.0);
      expect(painted.height, lessThan(inkSize.height));

      await _tapAbovePainted(tester, ink);
      expect(taps, 1);
    });

    testWidgets('FluxIconButton keeps its 34dp icon inside a 48dp hit box', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FluxIconButton(icon: FluxIcons.add, onTap: () => taps++),
            ),
          ),
        ),
      );

      final ink = _inkInside(FluxIconButton);
      final inkSize = tester.getSize(ink);
      expect(inkSize.width, greaterThanOrEqualTo(48.0));
      expect(inkSize.height, greaterThanOrEqualTo(48.0));
      expect(tester.getSize(find.byType(FluxIconButton)), inkSize);

      final painted = tester.getSize(
        find
            .descendant(
              of: find.byType(FluxIconButton),
              matching: find.byType(Material),
            )
            .last,
      );
      expect(painted, const Size(34, 34));

      await _tapAbovePainted(tester, ink);
      expect(taps, 1);
    });

    testWidgets('FluxContextMenu items keep a 48dp hit box in the card', (
      tester,
    ) async {
      final key = GlobalKey();
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: GestureDetector(
                  key: key,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showFluxContextMenu<void>(
                    context: context,
                    targetKey: key,
                    previewWidget: const SizedBox(width: 100, height: 40),
                    items: [
                      FluxContextMenuItem(
                        icon: FluxIcons.copy,
                        label: 'Copy',
                        onTap: () => taps++,
                      ),
                    ],
                  ),
                  child: const SizedBox(width: 100, height: 40),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();

      final ink = find.ancestor(
        of: find.text('Copy'),
        matching: find.byType(InkWell),
      );
      final inkSize = tester.getSize(ink);
      expect(inkSize.width, greaterThanOrEqualTo(48.0));
      expect(inkSize.height, greaterThanOrEqualTo(48.0));

      final painted = tester.getSize(
        find.descendant(of: ink, matching: find.byType(Padding)).first,
      );
      expect(painted.height, lessThan(inkSize.height));

      await _tapAbovePainted(tester, ink);
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(find.text('Copy'), findsNothing);
    });
  });
}
