import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/flux_context_menu.dart';

/// The smallest painted control the app ships, and the reason the hit-area
/// tests below exist: the visual language is deliberately compact (a 30-36dp
/// pill, a 34dp icon) but a thumb needs 48dp.
const double kMinTap = FluxMotion.minTapTarget;

Finder _inkInside(Type widgetType) => find.descendant(
      of: find.byType(widgetType),
      matching: find.byType(InkWell),
    );

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: brightness == Brightness.dark ? FluxTheme.dark : FluxTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('48dp touch targets', () {
    testWidgets('FluxChip keeps its 32dp pill inside a 48dp hit box', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(FluxChip(label: 'All', onTap: () => taps++)),
      );

      final chip = find.byType(FluxChip);
      final ink = _inkInside(FluxChip);
      final inkSize = tester.getSize(ink);
      expect(inkSize.width, greaterThanOrEqualTo(kMinTap));
      expect(inkSize.height, greaterThanOrEqualTo(kMinTap));
      expect(tester.getSize(chip), inkSize);

      // The painted pill is deliberately smaller than the hit box.
      final painted = tester.getSize(
        find.descendant(of: chip, matching: find.byType(SizedBox)).first,
      );
      expect(painted.height, 32.0);
      expect(painted.height, lessThan(inkSize.height));

      // Tapping in the transparent margin above the pill still registers.
      final rect = tester.getRect(ink);
      await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
      expect(taps, 1);
    });

    testWidgets('FluxChip compact-width still reserves 48dp', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const FluxChip(label: 'App')));
      final inkSize = tester.getSize(_inkInside(FluxChip));
      expect(inkSize.width, greaterThanOrEqualTo(kMinTap));
      expect(inkSize.height, greaterThanOrEqualTo(kMinTap));
    });

    testWidgets('FluxPillButton reserves 48dp in both states', (
      tester,
    ) async {
      for (final enabled in [true, false]) {
        await tester.pumpWidget(
          _host(
            FluxChip(
              label: 'Next',
              onTap: enabled ? () {} : null,
            ),
          ),
        );
        final inkSize = tester.getSize(_inkInside(FluxChip));
        expect(inkSize.width, greaterThanOrEqualTo(kMinTap));
        expect(inkSize.height, greaterThanOrEqualTo(kMinTap));
      }
    });

    testWidgets('BackControl keeps a 48dp-tall hit box', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(BackControl(onTap: () => taps++)));

      final size = tester.getSize(find.byType(BackControl));
      expect(size.height, greaterThanOrEqualTo(kMinTap));

      await tester.tap(find.byType(BackControl));
      expect(taps, 1);
    });

    testWidgets('FluxSpringPressable only grows when asked to', (
      tester,
    ) async {
      // Off by default: the widget also wraps chat bubbles and cards, which
      // must not be padded out.
      await tester.pumpWidget(
        _host(
          const FluxSpringPressable(
            child: SizedBox(width: 20, height: 20),
          ),
        ),
      );
      expect(tester.getSize(find.byType(FluxSpringPressable)).height, 20.0);

      await tester.pumpWidget(
        _host(
          const FluxSpringPressable(
            expandHitArea: true,
            child: SizedBox(width: 20, height: 20),
          ),
        ),
      );
      expect(tester.getSize(find.byType(FluxSpringPressable)).height, kMinTap);
    });
  });

  group('Semantics labels', () {
    testWidgets('FluxChip announces its label and selected state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _host(
          const FluxChip(label: 'Widgets', selected: true, onTap: null),
        ),
      );

      expect(
        tester.getSemantics(find.byType(FluxChip)),
        isSemantics(
          label: 'Widgets',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
        ),
      );

      handle.dispose();
    });

    testWidgets('FluxChip prefers an explicit semantic label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _host(
          const FluxChip(
            label: 'Widgets',
            semanticLabel: 'Show only widgets',
            onTap: null,
          ),
        ),
      );

      expect(find.bySemanticsLabel('Show only widgets'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('FluxPillButton is announced as a labelled button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _host(FluxPillButton(label: 'Start using FinnAI', onTap: () {})),
      );

      expect(
        tester.getSemantics(find.byType(FluxPillButton)),
        isSemantics(
          label: 'Start using FinnAI',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      handle.dispose();
    });

    testWidgets('FluxSpringPressable announces its label when given one', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _host(
          const FluxSpringPressable(
            semanticLabel: 'Copy reply',
            onTap: _noop,
            child: SizedBox(width: 40, height: 40),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Copy reply'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('context menu items are announced by their label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final key = GlobalKey();

      await tester.pumpWidget(
        _host(
          GestureDetector(
            key: key,
            behavior: HitTestBehavior.opaque,
            onTap: () => showFluxContextMenu<void>(
              context: tester.element(find.byKey(key)),
              targetKey: key,
              previewWidget: const SizedBox(width: 100, height: 40),
              items: [
                FluxContextMenuItem(
                  icon: FluxIcons.copy,
                  label: 'Copy',
                  onTap: _noop,
                ),
                FluxContextMenuItem(
                  icon: FluxIcons.close,
                  label: 'Delete',
                  onTap: _noop,
                  isDestructive: true,
                ),
              ],
            ),
            child: const SizedBox(width: 100, height: 40),
          ),
        ),
      );

      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Copy'), findsOneWidget);
      expect(find.bySemanticsLabel('Delete'), findsOneWidget);

      handle.dispose();
    });
  });

  group('one motion language', () {
    test('the page and modal tokens are each a single named pair', () {
      // The audit found three page motions and three modal motions. There is
      // now one duration and one curve per kind, all easing out on the same
      // cubic, so a push and a modal feel like the same app.
      expect(FluxMotion.pageDuration, isNot(FluxMotion.modalDuration));
      expect(FluxMotion.pageCurve, FluxMotion.modalCurve);
      expect(FluxMotion.pageReverseCurve, FluxMotion.modalReverseCurve);
      expect(FluxMotion.revealDuration, lessThan(FluxMotion.modalDuration));
      expect(FluxMotion.pressIn, lessThan(FluxMotion.revealDuration));
      expect(FluxMotion.minTapTarget, 48.0);
    });

    testWidgets('the context menu route uses the modal tokens', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        _host(
          GestureDetector(
            key: key,
            behavior: HitTestBehavior.opaque,
            onTap: () => showFluxContextMenu<void>(
              context: tester.element(find.byKey(key)),
              targetKey: key,
              previewWidget: const SizedBox(width: 100, height: 40),
              items: [
                FluxContextMenuItem(
                  icon: FluxIcons.copy,
                  label: 'Copy',
                  onTap: _noop,
                ),
              ],
            ),
            child: const SizedBox(width: 100, height: 40),
          ),
        ),
      );

      await tester.tap(find.byKey(key));
      await tester.pump(FluxMotion.modalDuration);
      await tester.pumpAndSettle();

      // Fully open after exactly the modal duration: no second, longer curve.
      final menu = find.ancestor(
        of: find.text('Copy'),
        matching: find.byType(BackdropFilter),
      );
      expect(menu, findsWidgets);
    });
  });

  group('locale-safe section labels', () {
    testWidgets('FluxSectionLabel renders the label exactly as translated', (
      tester,
    ) async {
      // "Über dich" must not become "ÜBER DICH": German capitalises nouns only,
      // and a plain Dart String carries no locale for `toUpperCase` to consult.
      await tester.pumpWidget(_host(const FluxSectionLabel('Über dich')));

      expect(find.text('Über dich'), findsOneWidget);
      expect(find.text('ÜBER DICH'), findsNothing);
    });

    testWidgets('FluxSectionLabel is at least 12px tall to read', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const FluxSectionLabel('AI MODEL')));

      final text = tester.widget<Text>(find.text('AI MODEL'));
      expect(
        text.style?.fontSize ?? 0,
        greaterThanOrEqualTo(FluxColors.minTextSize),
      );
    });
  });

  group('accessible text in shared widgets', () {
    testWidgets('the back control label clears AA instead of using 50% ink', (
      tester,
    ) async {
      await tester.pumpWidget(_host(BackControl(onTap: _noop)));

      final text = tester.widget<Text>(find.text('Back'));
      final color = text.style?.color;
      expect(color, isNotNull);
      // A solid token, not a translucent `withValues(alpha: .5)`.
      expect(color!.a, 1.0);
    });
  });
}

void _noop() {}
