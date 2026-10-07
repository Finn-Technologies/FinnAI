import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/theme/flux_vivid.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// The vivid hues sit under white glyphs (icon wells, the send button) and
/// the brand sweep paints the greeting; each has to stay legible.
void main() {
  test('a white glyph keeps 3:1 on every stop of every hue', () {
    for (final hue in FluxHue.values) {
      for (final stop in FluxVivid.of(hue)) {
        expect(
          _contrast(Colors.white, stop),
          greaterThanOrEqualTo(3),
          reason: '$hue $stop',
        );
      }
    }
  });

  test('a white arrow keeps 3:1 on the send sweep', () {
    for (final stop in FluxVivid.brandDeep) {
      expect(_contrast(Colors.white, stop), greaterThanOrEqualTo(3));
    }
  });

  test('the greeting sweep is large-text legible on both canvases', () {
    for (final stop in FluxVivid.brand) {
      expect(
        _contrast(stop, FluxColors.darkCanvas),
        greaterThanOrEqualTo(3),
        reason: 'dark $stop',
      );
    }
    for (final stop in FluxVivid.brandDeep) {
      expect(
        _contrast(stop, FluxColors.canvas),
        greaterThanOrEqualTo(3),
        reason: 'light $stop',
      );
    }
  });

  test('hues are told apart: no two share a solid colour', () {
    final solids = FluxHue.values.map(FluxVivid.solid).toSet();
    expect(solids.length, FluxHue.values.length);
  });
}
