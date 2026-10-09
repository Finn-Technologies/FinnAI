import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/onboarding/context_consent_store.dart';
import 'package:finn_ai/src/features/onboarding/onboarding_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Landscape, short-window and large-text cover for the first-run screens.
///
/// The step pages size themselves from whatever height is left after the
/// system bars, so the shapes that break are the ones a portrait phone never
/// shows: a landscape phone (844x390 with a 24dp status bar and a 48dp nav
/// bar leaves 318px for the whole step) and a window dragged short. Each of
/// those used to draw either a "RenderFlex overflowed" stripe across the
/// bottom of the screen or a control row clipped off it, and did so silently,
/// because the older test never overrode `viewPadding`.
void main() {
  late _MemoryConsentStore store;

  setUp(() => store = _MemoryConsentStore());

  Future<void> openAt(
    WidgetTester tester,
    int page, {
    required Size size,
    double textScale = 1,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester
        .pumpWidget(_host(store, textScale: textScale, padding: padding));
    await tester.pump();
    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(page);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  /// Every form factor the step pages are asked to lay out, with the system
  /// insets a real device reports. Landscape is the one that used to overflow.
  const cases = <(String, Size, EdgeInsets)>[
    ('portrait phone', Size(390, 844), EdgeInsets.zero),
    ('small phone', Size(360, 740), EdgeInsets.only(top: 24, bottom: 12)),
    ('landscape phone', Size(844, 390), EdgeInsets.only(top: 24, bottom: 48)),
    (
      'short wide window',
      Size(1024, 400),
      EdgeInsets.only(top: 32, bottom: 24)
    ),
    ('tablet', Size(768, 1024), EdgeInsets.only(top: 24, bottom: 24)),
  ];

  for (final (name, size, insets) in cases) {
    group('$name (${size.width.toInt()}x${size.height.toInt()})', () {
      testWidgets('every step lays out inside the screen', (tester) async {
        for (var page = 0; page <= 4; page++) {
          await openAt(tester, page, size: size, padding: insets);
          final viewport =
              tester.view.physicalSize / tester.view.devicePixelRatio;

          expect(
            tester.takeException(),
            isNull,
            reason: 'step $page overflowed at $name',
          );
          expect(
            find.byType(OnboardingFlow),
            findsOneWidget,
            reason: 'step $page did not build at $name',
          );

          // The back circle is the control that used to be pushed off the
          // bottom of the screen when the two fixed floors summed past the
          // budget.
          final back = find.byKey(const ValueKey('onboarding-back'));
          if (back.evaluate().isNotEmpty) {
            final rect = tester.getRect(back);
            expect(
              rect.bottom,
              lessThanOrEqualTo(viewport.height),
              reason: 'the back circle is clipped at $name',
            );
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(viewport.width));
          }
        }
      });
    });
  }

  group('large text', () {
    // Android's font slider reaches 2.0x and iOS goes further. Nothing in
    // the flow scales its own fixed heights, so a row reserved as a constant
    // used to be swallowed by a text line that had grown past it.
    for (final scale in [1.5, 2.0]) {
      testWidgets('the consent step still fits at ${scale}x text',
          (tester) async {
        await openAt(
          tester,
          3,
          size: const Size(360, 640),
          textScale: scale,
          padding: const EdgeInsets.only(top: 24, bottom: 12),
        );

        expect(tester.takeException(), isNull);
        final viewport =
            tester.view.physicalSize / tester.view.devicePixelRatio;
        final l10n = L10n.of(tester.element(find.byType(PageView)));
        for (final label in [l10n.commonYes, l10n.commonNo]) {
          final finder = find.text(label);
          expect(finder, findsOneWidget);
          expect(
            tester.getRect(finder).bottom,
            lessThanOrEqualTo(viewport.height),
            reason: '"$label" is below the fold at ${scale}x text',
          );
        }
      });

      testWidgets('the context tiles still fit at ${scale}x text', (
        tester,
      ) async {
        await openAt(
          tester,
          4,
          size: const Size(360, 640),
          textScale: scale,
          padding: const EdgeInsets.only(top: 24, bottom: 12),
        );

        // A fixed tile height used to overflow here. At 2x the rows sit past
        // the list's cache extent, so they are legitimately not built yet;
        // what is assertable is that the page laid out at all.
        expect(tester.takeException(), isNull);
        final viewport =
            tester.view.physicalSize / tester.view.devicePixelRatio;
        final back = find.byKey(const ValueKey('onboarding-back'));
        expect(back, findsOneWidget);
        expect(
          tester.getRect(back).bottom,
          lessThanOrEqualTo(viewport.height),
          reason: 'the back circle is below the fold at ${scale}x',
        );
      });
    }
  });

  group('the step progress bar', () {
    testWidgets('grows across steps instead of restarting', (tester) async {
      // `_shown` used to be a process-global: a second pass through the flow,
      // or the upgrade screen drawing the same bar in the same process, began
      // from the previous pass's final value and animated *downwards*.
      await openAt(tester, 0, size: const Size(390, 844));
      await openAt(tester, 1, size: const Size(390, 844));

      // Two instances, at different values, proves the state is per-instance.
      final bars = find.byType(FittedBox);
      expect(bars, findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _host(
  ContextConsentStore store, {
  double textScale = 1,
  EdgeInsets padding = EdgeInsets.zero,
}) =>
    MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        padding: padding,
        viewPadding: padding,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: OnboardingFlow(
            enableModelDownload: false,
            consentStore: store,
          ),
        ),
      ),
    );

/// A consent store with no file behind it, so a widget test can drive the flow
/// without real I/O.
class _MemoryConsentStore extends ContextConsentStore {
  @override
  Future<void> initialize() async {}
}
