import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/src/app/bootstrap.dart';
import 'package:finn_ai/src/features/onboarding/wide_step.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only a window with room gets the two-pane layout', () {
    bool fits(double w, double h) =>
        wideStepFits(BoxConstraints.tight(Size(w, h)));
    expect(fits(1280, 760), isTrue);
    expect(fits(820, 1180), isTrue);
    expect(fits(390, 844), isFalse, reason: 'a phone keeps the card');
    expect(fits(844, 390), isFalse, reason: 'so does a phone on its side');
  });

  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onBack,
    VoidCallback? onNext,
    Widget? footer,
  }) async {
    tester.view.physicalSize = const Size(1280, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: FluxTheme.light,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WideStepLayout(
            artwork: 'assets/runtime/artwork_privacy.png',
            title: 'A title',
            body: const Text('The words'),
            progress: 2,
            onBack: onBack,
            onNext: onNext,
            footer: footer,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('title and copy sit right of the artwork, controls below', (
    tester,
  ) async {
    await pump(tester, onBack: () {}, onNext: () {});
    final art = tester.getRect(find.byType(Image));
    // The title stays on the artwork, as on a phone; the copy is beside it.
    expect(art.contains(tester.getCenter(find.text('A title'))), isTrue);
    expect(
        tester.getTopLeft(find.text('The words')).dx, greaterThan(art.right));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('onboarding-next'))).dy,
      greaterThan(tester.getBottomLeft(find.text('The words')).dy),
    );
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('the buttons and the keyboard walk the steps', (tester) async {
    var next = 0, back = 0;
    await pump(tester, onBack: () => back++, onNext: () => next++);
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.tap(find.byKey(const ValueKey('onboarding-back')));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    // A key just acted on cools down briefly: the step is about to go.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect((next, back), (2, 2));
  });

  testWidgets('a step that cannot advance yet ignores Next and Enter', (
    tester,
  ) async {
    var back = 0;
    await pump(tester, onBack: () => back++);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    expect(back, 0);
  });

  testWidgets('the last step shows its single action instead of Back/Next', (
    tester,
  ) async {
    await pump(tester, footer: const Text('Start now'));
    expect(find.text('Start now'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('the welcome screen offers a button, not a swipe, when wide', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const FluxApp(enableModelDownload: false));
    await tester.pump();
    expect(find.text('Swipe to start'), findsNothing);
    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.text('FinnAI values your privacy'), findsOneWidget);
  });

  testWidgets('Enter walks from the welcome screen through the next step', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const FluxApp(enableModelDownload: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    Future<void> enter() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 100));
    }

    await enter();
    expect(find.text('FinnAI values your privacy'), findsOneWidget);
    // The new step must have taken focus from the one it replaced.
    await enter();
    expect(find.text('Downloading FinnAI Foundation'), findsOneWidget);
  });

  testWidgets(
      'a step left behind in the page view does not answer for the one '
      'on screen', (tester) async {
    tester.view.physicalSize = const Size(1280, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const FluxApp(enableModelDownload: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    Future<void> enter() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Welcome -> privacy -> model. Privacy has a live Next, and is left mounted
    // beside the page view's viewport.
    await enter();
    await enter();
    expect(find.text('Downloading FinnAI Foundation'), findsOneWidget);
    // The model step cannot advance yet. If the stale privacy step answered,
    // Enter would "advance" to the model step again and swallow the key; here
    // it must be ignored, and then Back (Escape) must reach the model step.
    await enter();
    expect(find.text('Downloading FinnAI Foundation'), findsOneWidget);
  });

  testWidgets('Enter on the "choose what FinnAI can see" step moves on', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const FluxApp(enableModelDownload: false));
    await tester.pump();
    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(4);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Choose what FinnAI can see'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('FinnAI is ready!'), findsOneWidget);
  });

  testWidgets('Enter presses the last step\'s single button', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StepEnterKey(
          onEnter: () => pressed++,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(pressed, 1);
  });
}
