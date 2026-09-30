import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// WCAG 2.x relative luminance of an opaque sRGB colour.
double _relativeLuminance(Color c) {
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

/// WCAG 2.x contrast ratio between two opaque colours, 1.0 to 21.0.
double _contrast(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// The ratio a piece of text at [fontSize] (and optionally bold) has to reach.
double requiredFor({required double fontSize, bool bold = false}) {
  // WCAG 1.4.3 "large text": >= 18pt (24px) or >= 14pt (18.66px) bold.
  final isLarge = fontSize >= 24 || (bold && fontSize >= 18.66);
  return isLarge ? 3.0 : 4.5;
}

/// A host that applies the theme directly rather than through [MaterialApp],
/// whose [AnimatedTheme] needs an extra frame before `Theme.of` reports the new
/// brightness.
Widget _host(Widget child, Brightness brightness) => Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: brightness == Brightness.dark ? FluxTheme.dark : FluxTheme.light,
        child: child,
      ),
    );

/// Every surface a semantic colour is actually painted on, per brightness.
///
/// Each is asserted, so a token cannot pass on the canvas and fail on a card.
const Map<Brightness, List<Color>> _surfaces = {
  Brightness.light: [
    FluxColors.canvas,
    FluxColors.card,
    FluxColors.surface,
    FluxColors.tileLight,
  ],
  Brightness.dark: [
    FluxColors.darkCanvas,
    FluxColors.darkCard,
    FluxColors.darkSurface,
    FluxColors.tileDark,
  ],
};

Color _resolve(Color light, Color dark, Brightness brightness) =>
    brightness == Brightness.dark ? dark : light;

void main() {
  group('semantic colour tokens clear WCAG AA', () {
    /// [label] names the pair; [light]/[dark] are the token values and [on] is
    /// the surface family it is painted on.
    final cases = <String, (Color, Color)>{
      'link': (FluxColors.link, FluxColors.linkDark),
      'info': (FluxColors.infoLight, FluxColors.info),
      'warning': (FluxColors.warning, FluxColors.accentAmberDark),
      'success': (FluxColors.success, FluxColors.accentGreenDark),
      'accent': (FluxColors.accentLink, FluxColors.linkDark),
      'danger': (FluxColors.destructive, FluxColors.destructiveDark),
    };

    cases.forEach((name, pair) {
      test('$name reaches 4.5:1 on every surface, in both themes', () {
        for (final brightness in Brightness.values) {
          final color = _resolve(pair.$1, pair.$2, brightness);
          for (final surface in _surfaces[brightness]!) {
            final ratio = _contrast(color, surface);
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason: '$name ${color.toARGB32().toRadixString(16)} on '
                  '${surface.toARGB32().toRadixString(16)} in $brightness is '
                  '${ratio.toStringAsFixed(2)}:1',
            );
          }
        }
      });
    });

    test('muted secondary copy reaches 4.5:1 on every surface', () {
      for (final brightness in Brightness.values) {
        final color = _resolve(
          FluxColors.muted,
          FluxColors.darkMuted,
          brightness,
        );
        for (final surface in _surfaces[brightness]!) {
          expect(
            _contrast(color, surface),
            greaterThanOrEqualTo(4.5),
            reason: 'muted in $brightness on '
                '${surface.toARGB32().toRadixString(16)} is '
                '${_contrast(color, surface).toStringAsFixed(2)}:1',
          );
        }
      }
    });

    test('de-emphasised body copy reaches 4.5:1 on every surface', () {
      // Replaces the 50%-alpha body text the audit measured at 2.3-3.2:1.
      for (final brightness in Brightness.values) {
        final color = _resolve(
          FluxColors.secondaryInk,
          FluxColors.secondaryInkDark,
          brightness,
        );
        for (final surface in _surfaces[brightness]!) {
          expect(
            _contrast(color, surface),
            greaterThanOrEqualTo(4.5),
            reason: 'secondaryInk in $brightness on '
                '${surface.toARGB32().toRadixString(16)} is '
                '${_contrast(color, surface).toStringAsFixed(2)}:1',
          );
        }
      }
    });

    test('the tile timestamp reaches 4.5:1 on the tile it sits on', () {
      // Measured 3.43:1 before the fix; the audit flagged it as unreadable.
      expect(
        _contrast(FluxColors.timestampLight, FluxColors.tileLight),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('body text on raised surfaces clears AA', () {
    test('ink on canvas, card, surface and tile', () {
      for (final surface in const [
        FluxColors.canvas,
        FluxColors.card,
        FluxColors.surface,
        FluxColors.tileLight,
      ]) {
        expect(_contrast(FluxColors.ink, surface), greaterThanOrEqualTo(4.5));
      }
    });

    test('darkInk on dark canvas, card, surface and tile', () {
      for (final surface in const [
        FluxColors.darkCanvas,
        FluxColors.darkCard,
        FluxColors.darkSurface,
        FluxColors.tileDark,
      ]) {
        expect(
          _contrast(FluxColors.darkInk, surface),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });

  group('chat bubbles', () {
    test('body text on the user bubble clears AA in both themes', () {
      expect(
        _contrast(FluxColors.ink, FluxColors.bubbleUserLight),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(FluxColors.darkInk, FluxColors.bubbleUserDark),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('body text on the assistant bubble clears AA in both themes', () {
      expect(
        _contrast(FluxColors.ink, FluxColors.bubbleAssistantLight),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(FluxColors.darkInk, FluxColors.bubbleAssistantDark),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('the dark user bubble is distinguishable from the black canvas', () {
      // WCAG 1.4.11 non-text contrast. #2C2C2E measured 1.51:1 here, which is
      // why the bubble read as "very dark grey on black" on the device.
      expect(
        _contrast(FluxColors.bubbleUserDark, FluxColors.darkCanvas),
        greaterThanOrEqualTo(3.0),
      );
    });
  });

  group('resolvers return the active theme value', () {
    testWidgets('linkOf, infoOf, warningOf, accentOf and bubble resolvers', (
      tester,
    ) async {
      /// Reads every resolver from inside the tree, so the values are the ones
      /// a widget would actually see under the active theme.
      Future<Map<String, Color>> read(Brightness brightness) async {
        late Map<String, Color> seen;
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (context) {
                seen = {
                  'link': FluxColors.linkOf(context),
                  'info': FluxColors.infoOf(context),
                  'warning': FluxColors.warningOf(context),
                  'success': FluxColors.successOf(context),
                  'accent': FluxColors.accentOf(context),
                  'bubbleUser': FluxColors.bubbleUserOf(context),
                  'bubbleAssistant': FluxColors.bubbleAssistantOf(context),
                  'onBubble': FluxColors.onBubbleOf(context),
                };
                return const SizedBox.shrink();
              },
            ),
            brightness,
          ),
        );
        return seen;
      }

      expect(await read(Brightness.light), {
        'link': FluxColors.link,
        'info': FluxColors.infoLight,
        'warning': FluxColors.warning,
        'success': FluxColors.success,
        'accent': FluxColors.link,
        'bubbleUser': FluxColors.bubbleUserLight,
        'bubbleAssistant': FluxColors.bubbleAssistantLight,
        'onBubble': FluxColors.ink,
      });

      expect(await read(Brightness.dark), {
        'link': FluxColors.linkDark,
        'info': FluxColors.info,
        'warning': FluxColors.accentAmberDark,
        'success': FluxColors.accentGreenDark,
        'accent': FluxColors.linkDark,
        'bubbleUser': FluxColors.bubbleUserDark,
        'bubbleAssistant': FluxColors.bubbleAssistantDark,
        'onBubble': FluxColors.darkInk,
      });
    });
  });

  group('no readable text is smaller than the 12px floor', () {
    test('every text theme role is at least FluxColors.minTextSize', () {
      for (final theme in [FluxTheme.light, FluxTheme.dark]) {
        final roles = <String, TextStyle?>{
          'displayLarge': theme.textTheme.displayLarge,
          'displayMedium': theme.textTheme.displayMedium,
          'displaySmall': theme.textTheme.displaySmall,
          'headlineLarge': theme.textTheme.headlineLarge,
          'headlineMedium': theme.textTheme.headlineMedium,
          'headlineSmall': theme.textTheme.headlineSmall,
          'titleLarge': theme.textTheme.titleLarge,
          'titleMedium': theme.textTheme.titleMedium,
          'titleSmall': theme.textTheme.titleSmall,
          'bodyLarge': theme.textTheme.bodyLarge,
          'bodyMedium': theme.textTheme.bodyMedium,
          'bodySmall': theme.textTheme.bodySmall,
          'labelLarge': theme.textTheme.labelLarge,
          'labelMedium': theme.textTheme.labelMedium,
          'labelSmall': theme.textTheme.labelSmall,
        };
        roles.forEach((name, style) {
          final size = style?.fontSize;
          if (size == null) return;
          expect(
            size,
            greaterThanOrEqualTo(FluxColors.minTextSize),
            reason: '$name renders at ${size}px',
          );
        });
      }
    });
  });

  group('large-text threshold helper', () {
    test('24px and 18.66px bold need 3.0, everything else 4.5', () {
      expect(requiredFor(fontSize: 24), 3.0);
      expect(requiredFor(fontSize: 20, bold: true), 3.0);
      expect(requiredFor(fontSize: 19), 4.5);
      expect(requiredFor(fontSize: 20, bold: false), 4.5);
      expect(requiredFor(fontSize: 15), 4.5);
    });
  });
}
