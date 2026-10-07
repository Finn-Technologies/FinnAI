import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/code/ui/code_conversation.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_composer_frame.dart';
import 'package:finn_ai/src/shared/widgets/finn_greeting.dart';
import 'package:finn_ai/src/shared/widgets/finn_sidebar_surface.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      theme: FluxTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('FinnGreeting', () {
    testWidgets('settles, then does not redraw while idle', (tester) async {
      await tester.pumpWidget(_host(const FinnGreeting(text: 'Hello')));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettle();
      // Settled: the mask and blur are gone and nothing ticks.
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byType(ImageFiltered), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('reduced motion shows it at once', (tester) async {
      await tester.pumpWidget(
        _host(const FinnGreeting(text: 'Hello'), reduceMotion: true),
      );
      await tester.pump();
      expect(find.byType(ShaderMask), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('FinnComposerFrame', () {
    Widget frame(double t) => SizedBox(
          width: 360,
          child: FinnComposerFrame(
            t: t,
            frameKey: const ValueKey('frame'),
            field: const SizedBox(height: 48, width: double.infinity),
            leading: const SizedBox.square(dimension: 50),
            trailing: const SizedBox.square(dimension: 50),
          ),
        );

    testWidgets('at rest the pill is the circles\' height, 20dp from each',
        (tester) async {
      await tester.pumpWidget(_host(frame(0)));
      final pill = tester.getRect(find.byKey(const ValueKey('frame')));
      expect(pill.height, FinnCircleButton.dimension);
      expect(pill.width, 360 - 2 * (50 + 20));
      // A static frame: nothing ticks once the first frames are in.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('fused, the pill takes the whole row and the control bar',
        (tester) async {
      await tester.pumpWidget(_host(frame(1)));
      final pill = tester.getRect(find.byKey(const ValueKey('frame')));
      expect(pill.width, 360);
      expect(pill.height, 48 + 8 + FinnComposerFrame.fusedBar + 2);
    });
  });

  group('CodeThinking', () {
    testWidgets('pulses while shown, and stops under reduced motion',
        (tester) async {
      await tester.pumpWidget(_host(const CodeThinking(), reduceMotion: true));
      await tester.pump();
      // Only the one-second clock remains, no per-frame pulse.
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('removing it stops every ticker', (tester) async {
      await tester.pumpWidget(_host(const CodeThinking()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('FinnSidebarSurface', () {
    Widget surface({required bool open}) => MaterialApp(
          home: FinnSidebarSurface(
            home: const ColoredBox(color: Color(0xFFFFFFFF)),
            // Something that animates forever while it is allowed to: a
            // working session's pulse, a skeleton's sweep.
            sidebar: const SizedBox(
              width: 300,
              child: Center(child: CircularProgressIndicator()),
            ),
            sidebarWidth: 300,
            progress: open ? 1 : 0,
            sidebarOpen: open,
            toggleLeft: 16,
            toggleTop: 60,
            onToggle: () {},
            onDragStart: (_) {},
            onDragUpdate: (_) {},
            onDragEnd: (_) {},
          ),
        );

    testWidgets('a closed panel stops its tickers', (tester) async {
      await tester.pumpWidget(surface(open: false));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('an open panel runs them', (tester) async {
      await tester.pumpWidget(surface(open: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
