import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/chat/widgets/voice_glow.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// The voice light at fixed moments, in both themes: what a reviewer looks at
/// when the glow is changed. The painter is deterministic for a frame.
void main() {
  Future<void> shoot(
    WidgetTester tester, {
    required bool dark,
    required VoiceGlowFrame frame,
    required String name,
  }) async {
    await tester.runAsync(VoiceGlowShader.load);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ColoredBox(
          color: dark ? FluxColors.tileDark : FluxColors.tileLight,
          child: CustomPaint(
            size: const Size(390, 844),
            painter: VoiceGlowPainter(
              frame: frame,
              dark: dark,
              program: VoiceGlowShader.program,
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('shot')),
      matchesGoldenFile('goldens/voice_glow_$name.png'),
    );
  }

  const quiet = VoiceGlowFrame(presence: 1, level: .05, phase: .3);
  const loud = VoiceGlowFrame(presence: 1, level: .85, phase: .55);
  const opening = VoiceGlowFrame(presence: .45, level: 0, phase: .1);

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';
    testWidgets('quiet ($theme)', (tester) async {
      await shoot(tester, dark: dark, frame: quiet, name: 'quiet_$theme');
    });
    testWidgets('loud ($theme)', (tester) async {
      await shoot(tester, dark: dark, frame: loud, name: 'loud_$theme');
    });
    testWidgets('opening ($theme)', (tester) async {
      await shoot(tester, dark: dark, frame: opening, name: 'opening_$theme');
    });
  }

  testWidgets('the shader compiles and loads', (tester) async {
    await tester.runAsync(VoiceGlowShader.load);
    expect(VoiceGlowShader.program, isNotNull);
  });

  testWidgets('a closed frame paints nothing', (tester) async {
    final painter = VoiceGlowPainter(
      frame: const VoiceGlowFrame(),
      dark: true,
    );
    final recorder = PictureRecorder();
    painter.paint(Canvas(recorder), const Size(100, 100));
    expect(recorder.endRecording(), isNotNull);
    expect(
      painter.shouldRepaint(
        VoiceGlowPainter(frame: const VoiceGlowFrame(), dark: true),
      ),
      isFalse,
    );
  });
}
