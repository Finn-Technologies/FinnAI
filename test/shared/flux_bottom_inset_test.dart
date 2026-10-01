import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finn_ai/src/features/chat/home_shell.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// The app runs edge-to-edge, so each screen measures the navigation bar itself.
/// These pin the behaviour that regressed: hiding the navigation bar zeroed
/// `padding`, which left the composer and every other bottom-anchored row
/// touching the screen edge.
void main() {
  group('FluxBottomInset.bottomOf', () {
    testWidgets('keeps the physical bar inset', (tester) async {
      final inset = await _measure(
        tester,
        viewPadding: 48,
        padding: 48,
      );
      expect(inset, 48);
    });

    testWidgets('still reserves room when the navigation bar is hidden', (
      tester,
    ) async {
      // A hidden bar reports no padding but keeps the gesture inset. The old
      // `paddingOf` read returned 0 here and parked the composer on the glass.
      final inset = await _measure(
        tester,
        viewPadding: 24,
        padding: 0,
      );
      expect(inset, greaterThanOrEqualTo(FluxBottomInset.minBar));
    });

    testWidgets('floors the inset when the device reports nothing', (
      tester,
    ) async {
      final inset = await _measure(tester);
      expect(inset, FluxBottomInset.minBar);
    });

    testWidgets('never shrinks when a keyboard covers the bar', (tester) async {
      // With the keyboard up, padding collapses to zero. The composer has to
      // clear the keyboard, which is taller than the bar it hid.
      final inset = await _measure(
        tester,
        viewPadding: 48,
        padding: 0,
        viewInsets: 320,
      );
      expect(inset, 320);
    });
  });

  group('the chat composer clears the screen edge', () {
    testWidgets('when the navigation bar hides, the composer still has room', (
      tester,
    ) async {
      final conversations = ConversationStore();
      addTearDown(conversations.dispose);
      conversations.startNew();

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // The reported case: a gesture-nav device with the bar hidden reports no
      // inset at all, so a `viewPadding` read puts the composer on the glass.
      tester.view.viewPadding = FakeViewPadding.zero;
      tester.view.padding = FakeViewPadding.zero;
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);

      await tester.pumpWidget(
        MaterialApp(
          theme: FluxTheme.light,
          home: HomeShell(
            conversationStore: conversations,
            initializeServices: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final composer = tester.getRect(find.byType(ChatComposer));
      expect(
        tester.view.physicalSize.height / tester.view.devicePixelRatio -
            composer.bottom,
        greaterThanOrEqualTo(FluxBottomInset.minBar),
        reason: 'the composer must not sit on the screen edge',
      );
      expect(tester.takeException(), isNull);
      // Let the store's debounced save fire so no timer outlives the tree.
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}

/// Pumps [FluxBottomInset.bottomOf] under the given insets and returns it.
Future<double> _measure(
  WidgetTester tester, {
  double viewPadding = 0,
  double padding = 0,
  double viewInsets = 0,
}) async {
  // View insets arrive in physical pixels; at the default 3.0 ratio they would
  // be divided down to thirds of the logical values the helper must report.
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.viewPadding = FakeViewPadding(bottom: viewPadding);
  tester.view.padding = FakeViewPadding(bottom: padding);
  tester.view.viewInsets = FakeViewPadding(bottom: viewInsets);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetViewInsets);

  late double inset;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          inset = FluxBottomInset.bottomOf(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return inset;
}
