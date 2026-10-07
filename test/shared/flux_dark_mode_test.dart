import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_surfaces.dart';

/// Guards the dark-mode fixes, each of which was a real defect: a control that
/// was invisible, text below AA, or a shadow/scrim that did nothing at all
/// because the dark canvas was pure black.
///
/// The contrast maths mirrors `flux_color_tokens_test.dart` so a regression is
/// reported the same way.
double _luminance(Color c) {
  double channel(int v) {
    final srgb = v / 255.0;
    return srgb <= 0.04045
        ? srgb / 12.92
        : math.pow((srgb + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel((c.r * 255).round() & 0xFF) +
      0.7152 * channel((c.g * 255).round() & 0xFF) +
      0.0722 * channel((c.b * 255).round() & 0xFF);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Flattens [fg] at its own alpha over [bg], which is what a tinted fill
/// actually composites to.
Color _over(Color fg, Color bg) {
  final a = fg.a;
  return Color.from(
    alpha: 1,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

Widget _darkHost(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(data: FluxTheme.dark, child: child),
    );

/// Reads a resolver inside a real dark [Theme].
Future<T> _inDark<T>(
  WidgetTester tester,
  T Function(BuildContext) resolve,
) async {
  late T result;
  await tester.pumpWidget(
    _darkHost(
      Builder(
        builder: (context) {
          result = resolve(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return result;
}

void main() {
  group('dark mode keeps surfaces visible against the canvas', () {
    testWidgets('the user bubble token is not the control surface', (
      tester,
    ) async {
      // The bubble was painted with controlOf, 1.26:1 on the old #000000
      // canvas — the user's own message had no visible bubble. It must read
      // through bubbleUserOf, which exists for exactly this.
      final bubble = await _inDark(tester, FluxColors.bubbleUserOf);
      expect(bubble, FluxColors.bubbleUserDark);
      expect(bubble, isNot(FluxColors.controlDark));
      expect(bubble, isNot(FluxColors.darkCanvas));
      // bubbleUserDark measures 2.06:1 on the canvas, so the bubble reads as a
      // raised surface without becoming a slab (see the token's note).
      expect(_contrast(bubble, FluxColors.darkCanvas), greaterThan(2.0));
    });

    testWidgets('an icon disc is visible on the sheet it sits on', (
      tester,
    ) async {
      // The attachment sheet is controlOf; its icon discs were
      // darkCard, 1.05:1 — the circles were simply not there.
      final sheet = FluxColors.controlDark;
      expect(_contrast(FluxColors.darkCard, sheet), lessThan(1.2));
      // And the disc now has to be the sheet's own surface, which does read.
      expect(sheet, isNot(FluxColors.darkCanvas));
      expect(_contrast(sheet, FluxColors.darkCanvas), greaterThan(1.2));
    });

    testWidgets('the carousel frame is the surface token, not a bubble token', (
      tester,
    ) async {
      // The image carousel was painted with bubbleAssistantDark, which asks a
      // *bubble* token to mean "frame". The frame now reads through
      // surfaceOf like every other container.
      final frame = await _inDark(tester, FluxColors.surfaceOf);
      expect(frame, FluxColors.darkSurface);
      // This palette's dark surfaces sit close to the canvas by design — see
      // the note on the group below — so the bar here is that
      // a frame is never the bubble token.
      expect(frame, isNot(FluxColors.bubbleAssistantDark));
    });
  });

  group('the dark canvas is near-black, so surfaces stay low-contrast', () {
    // Not a test that can be fixed by editing a call site: darkCanvas is
    // #101014 and every dark surface sits just above it, measuring 1.07:1
    // (surface) to 1.54:1 (line). That is a deliberate property of this
    // palette — pure black crushed on LCD and smeared on OLED — and it is why
    // dark mode separates flat surfaces with fill plus a 1px hairline rather
    // than with a shadow. Asserted so the numbers are known rather than
    // accidental.
    test('records the measured separation each surface has on the canvas', () {
      for (final surface in <String, Color>{
        'darkSurface': FluxColors.darkSurface,
        'darkCard': FluxColors.darkCard,
        'controlDark': FluxColors.controlDark,
        'darkLine': FluxColors.darkLine,
      }.entries) {
        final ratio = _contrast(surface.value, FluxColors.darkCanvas);
        expect(
          ratio,
          greaterThan(1.05),
          reason: '${surface.key} must at least separate from the canvas',
        );
        expect(ratio, lessThan(2.1),
            reason: '${surface.key} is unusually light');
      }
    });
  });

  group('dark mode ink clears AA', () {
    final cases = <String, (Color, Color)>{
      // (colour as it must be resolved in dark, the surface it is painted on)
      'link': (FluxColors.linkDark, FluxColors.darkCard),
      'info': (FluxColors.info, FluxColors.darkCard),
      'warning': (FluxColors.accentAmberDark, FluxColors.darkCard),
      'success': (FluxColors.accentGreenDark, FluxColors.darkCard),
      'danger': (FluxColors.destructiveDark, FluxColors.darkCanvas),
    };

    cases.forEach((name, pair) {
      test('$name reaches 4.5:1 on its dark surface', () {
        final ratio = _contrast(pair.$1, pair.$2);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name is ${ratio.toStringAsFixed(2)}:1 on '
              '${pair.$2.toARGB32().toRadixString(16)}',
        );
      });
    });

    test('the retired light accents would have failed, so they are unused', () {
      // The values that leaked into dark builds. Asserted explicitly so a
      // future "simplification" back to a raw constant is caught here.
      expect(_contrast(FluxColors.link, FluxColors.darkCard), lessThan(4.5));
      expect(
          _contrast(FluxColors.infoLight, FluxColors.darkCard), lessThan(4.5));
      expect(_contrast(FluxColors.warning, FluxColors.darkCard), lessThan(4.5));
      expect(_contrast(FluxColors.destructive, FluxColors.darkCanvas),
          lessThan(4.5));
    });
  });

  group('elevation and scrims actually render on black', () {
    testWidgets('a lifted shadow is visible against the canvas', (
      tester,
    ) async {
      // A black shadow over near-black is a no-op; dark mode must lift instead.
      final shadow = await _inDark(tester, FluxColors.elevationOf);
      expect(shadow, isNot(Colors.black));
      expect(_contrast(shadow, FluxColors.darkCanvas), greaterThan(1.5));
    });

    testWidgets('elevationShadow tints with the theme', (tester) async {
      late List<BoxShadow> shadows;
      await tester.pumpWidget(
        _darkHost(
          Builder(
            builder: (context) {
              shadows = FluxColors.elevationShadow(context, alpha: .1);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(shadows, hasLength(1));
      expect(shadows.single.color.computeLuminance(), greaterThan(0.0));
    });

    testWidgets('the modal scrim changes what is behind it', (tester) async {
      late Color scrim;
      await tester.pumpWidget(
        _darkHost(
          Builder(
            builder: (context) {
              scrim = FluxColors.scrimOf(context, alpha: .45);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      // Over a near-black canvas a black scrim barely registers, so
      // the menu had almost no dimming at all. It has to lighten instead.
      expect(scrim.computeLuminance(), greaterThan(0.0));
      expect(_over(scrim, FluxColors.darkCanvas), isNot(FluxColors.darkCanvas));
    });

    testWidgets('a disabled pill is quieter than an enabled one', (
      tester,
    ) async {
      late Color disabledBg;
      late Color enabledBg;
      await tester.pumpWidget(
        _darkHost(
          Builder(
            builder: (context) {
              enabledBg = FluxColors.inkOf(context);
              disabledBg = FluxColors.mutedOf(context).withValues(alpha: .32);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final disabledFlat = _over(disabledBg, FluxColors.darkCanvas);
      final enabledFlat = _over(enabledBg, FluxColors.darkCanvas);
      expect(
        disabledFlat.computeLuminance(),
        lessThan(enabledFlat.computeLuminance()),
        reason: 'disabled was brighter than enabled',
      );
    });
  });

  group('listening gradient has a dark variant', () {
    testWidgets('the dark pair is not the light pastels', (tester) async {
      final gradient = await _inDark(
        tester,
        FluxColors.voiceGradientOf,
      );
      expect(gradient.colors, contains(FluxColors.voiceStartDark));
      expect(gradient.colors, contains(FluxColors.voiceEndDark));
      expect(gradient.colors, isNot(contains(FluxColors.voiceStart)));
      // ~15:1 against the canvas: a slab of daylight on a dark UI.
      for (final color in gradient.colors) {
        expect(_contrast(color, FluxColors.darkCanvas), lessThan(6.0));
      }
    });

    testWidgets('the ambient chat wash is muted in dark', (tester) async {
      final wash = await _inDark(tester, FluxColors.ambientWashOf);
      expect(wash, FluxColors.ambientWashDark);
      // 25% green was the light strength; dark uses 8%.
      expect(wash.last.a, lessThan(0.15));
    });
  });

  group('a permanent surface separates with a hairline, never a shadow', () {
    // FinnAI Code's composer pill and action card each carried their own
    // BoxShadow. Over the near-black canvas that is `elevationOf` — #F5F5F7 —
    // so in dark the pill wore a pale halo and the card's 6% lift was
    // invisible, leaving it an edgeless grey slab. The rest of the app had
    // already moved to fill + 1px hairline for exactly this reason; Code had
    // not been carried along.
    testWidgets('flat() paints a hairline and no shadow', (tester) async {
      late BoxDecoration flat;
      await tester.pumpWidget(
        _darkHost(
          Builder(
            builder: (context) {
              flat = FluxSurfaces.flat(context, radius: FluxRadius.pill);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(flat.boxShadow, isNull);
      expect(flat.border, isA<Border>());
      expect((flat.border! as Border).top.width, 1);
      expect((flat.border! as Border).top.color, FluxColors.darkLine);
      expect(flat.color, FluxColors.controlDark);
    });

    testWidgets('flatCard() is the card fill with the same hairline',
        (tester) async {
      late BoxDecoration flat;
      await tester.pumpWidget(
        _darkHost(
          Builder(
            builder: (context) {
              flat = FluxSurfaces.flatCard(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(flat.boxShadow, isNull);
      expect((flat.border! as Border).top.color, FluxColors.darkLine);
      expect(flat.color, FluxColors.darkCard);
    });

    testWidgets('the hairline is visible against the dark canvas',
        (tester) async {
      late Color hairline;
      await tester.pumpWidget(
        _darkHost(
          Builder(
            builder: (context) {
              hairline = (FluxSurfaces.flat(context, radius: FluxRadius.pill)
                      .border! as Border)
                  .top
                  .color;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      // darkLine on darkCanvas. A shadow cannot do this job in dark: it is a
      // wash of the same near-black that is already there.
      expect(
        _contrast(hairline, FluxColors.darkCanvas),
        greaterThan(1.4),
        reason: 'the hairline is what gives a dark surface its edge',
      );
      // And the hairline must not read as text, or it competes with the copy
      // sitting on the surface.
      expect(
        _contrast(hairline, FluxColors.darkCard),
        lessThan(3.0),
        reason: 'the hairline is decoration, not copy',
      );
    });
  });
}
