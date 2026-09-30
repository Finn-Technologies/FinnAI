import 'dart:io';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/onboarding/context_consent_store.dart';
import 'package:finn_ai/src/features/onboarding/onboarding_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The consent step is the one place in the app where a tap decides whether
/// FinnAI reads the user's calendar, notes and photos. The device run on
/// 2026-09-29 reproduced the bug exactly: tapping Next with neither answer
/// selected advanced to the final step, no `context_consent.json` was written,
/// and Settings then showed "On-device context" switched on — an opt-in nobody
/// had agreed to.
void main() {
  // The widget tests drive the consent step, which initializes the store from
  // `initState`. A widget test body runs in a fake-async zone where real file
  // I/O never completes, so an unawaited `initialize()` on a real file hangs
  // the test instead of failing it. These use an in-memory store; the
  // persistence contract is the plain-host test at the bottom, where real I/O
  // is available.
  late _MemoryConsentStore store;

  setUp(() => store = _MemoryConsentStore());

  Future<void> openConsentStep(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(store));
    await tester.pump();
    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('the consent step cannot be skipped', () {
    testWidgets('Next is disabled until an answer is given', (tester) async {
      await openConsentStep(tester);

      final next = find.byKey(const ValueKey('onboarding-next'));
      expect(next, findsOneWidget);
      expect(
        _isEnabled(tester, next),
        isFalse,
        reason: 'a control that still advances while greyed out is the bug',
      );
    });

    testWidgets('the blocked step says why', (tester) async {
      await openConsentStep(tester);

      // Without this a disabled circle reads as "skip this", not "answer this
      // first", and the step is a trap for exactly the user it is for.
      expect(
        find.text(
          L10n.of(tester.element(find.byType(PageView)))
              .onboardingConsentRequiredHint,
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping Next with no answer does not advance', (
      tester,
    ) async {
      await openConsentStep(tester);

      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Still on the consent step: the question is on screen, unanswered.
      expect(
        find.text(
          L10n.of(tester.element(find.byType(PageView))).onboardingConsentTitle,
        ),
        findsOneWidget,
      );
      // And nothing was recorded, so the app has not silently opted anyone in.
      expect(store.writes, isEmpty);
    });

    testWidgets('answering No records the choice and unblocks Next', (
      tester,
    ) async {
      await openConsentStep(tester);

      final l10n = L10n.of(tester.element(find.byType(PageView)));
      await tester.tap(find.text(l10n.commonNo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final next = find.byKey(const ValueKey('onboarding-next'));
      expect(_isEnabled(tester, next), isTrue);
      expect(
        find.text(
          L10n.of(tester.element(next)).onboardingConsentRequiredHint,
        ),
        findsNothing,
        reason: 'the hint is only there while the step is blocked',
      );
      expect(store.granted, isFalse);
      expect(store.writes, [false]);
    });

    testWidgets('answering Yes records the choice', (tester) async {
      await openConsentStep(tester);

      final l10n = L10n.of(tester.element(find.byType(PageView)));
      await tester.tap(find.text(l10n.commonYes));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(store.granted, isTrue);
      expect(store.writes, [true]);
    });

    testWidgets('both answers are reachable without scrolling', (
      tester,
    ) async {
      // Adding the explanation to the body is exactly what pushed the answer
      // cards off the screen: `_StepPage` sizes the artwork card from the
      // height it reserves for the body, so an understated reservation
      // silently pushes the only two tappable things below the fold. A step
      // whose answer cannot be tapped is a step that cannot be answered.
      //
      // Checked on all four form factors, because the failure is both width-
      // and height-dependent: the same reservation is plenty on a tablet and
      // not on a 360x740 phone, where the padding leaves only 320px for copy
      // and the sentence wraps to five lines.
      for (final size in const [
        Size(390, 844),
        Size(360, 740),
        Size(768, 1024),
        Size(844, 390),
      ]) {
        await openConsentStep(tester, size: size);

        final viewport =
            tester.view.physicalSize / tester.view.devicePixelRatio;
        final l10n = L10n.of(tester.element(find.byType(PageView)));
        for (final label in [l10n.commonYes, l10n.commonNo]) {
          final finder = find.text(label);
          expect(finder, findsOneWidget, reason: 'at $size');
          final rect = tester.getRect(finder);
          expect(
            rect.bottom,
            lessThanOrEqualTo(viewport.height),
            reason: '"$label" is below the fold at $size and cannot be tapped',
          );
          expect(rect.top, greaterThanOrEqualTo(0), reason: 'at $size');
        }
        expect(tester.takeException(), isNull, reason: 'overflow at $size');
      }
    });

    testWidgets('the step explains what "context" means', (tester) async {
      await openConsentStep(tester);
      // The audit flagged the question as unanswerable because "context" was
      // never defined. The body has to say what would be read, and that it
      // stays on the device.
      final body =
          L10n.of(tester.element(find.byType(PageView))).onboardingConsentBody;
      expect(find.text(body), findsOneWidget);
      expect(body.toLowerCase(), contains('this device'));
    });
  });

  group('persistence', () {
    // Real file I/O, so this runs on the host where the fake clock is not in
    // the way. A recorded opt-out that does not survive a restart is cosmetic.
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('finn-consent');
    });

    tearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    ContextConsentStore open() =>
        ContextConsentStore(directoryProvider: () async => directory);

    test('a fresh install is opted in, which is why the step must be answered',
        () async {
      // Documented behaviour. The consent step is the only thing that changes
      // it, which is exactly why the step cannot be skipped.
      final store = open();
      await store.initialize();
      expect(store.granted, isTrue);
    });

    test('a recorded "no" survives a restart', () async {
      await open().setGranted(false);
      final reopened = open();
      await reopened.initialize();
      expect(reopened.granted, isFalse);
      expect(
        File('${directory.path}${Platform.pathSeparator}context_consent.json')
            .readAsStringSync(),
        contains('"granted":false'),
      );
    });

    test('a recorded "yes" survives a restart', () async {
      await open().setGranted(true);
      final reopened = open();
      await reopened.initialize();
      expect(reopened.granted, isTrue);
    });

    test('an unreadable file keeps the default instead of throwing', () async {
      // A corrupted or half-written consent file must not block onboarding.
      File('${directory.path}${Platform.pathSeparator}context_consent.json')
          .writeAsStringSync('{not json');
      final store = open();
      await store.initialize();
      expect(store.initialized, isTrue);
    });
  });
}

/// Whether the step's Next control is actually wired to a callback.
///
/// Read from the tree rather than the pixels, because a disabled control is
/// drawn at 38% opacity and still looks like the enabled one — which is why
/// this needed a test at all.
bool _isEnabled(WidgetTester tester, Finder finder) {
  final opacity = tester.widgetList<Opacity>(
    find.descendant(of: finder, matching: find.byType(Opacity)),
  );
  expect(opacity, isNotEmpty, reason: 'the control has no disabled styling');
  return opacity.every((o) => o.opacity > .5);
}

/// A consent store with no file behind it, so a widget test can drive the step
/// without real I/O. [writes] records every recorded answer in order.
class _MemoryConsentStore extends ContextConsentStore {
  final List<bool> writes = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> setGranted(bool value) async {
    writes.add(value);
    return super.setGranted(value);
  }
}

Widget _host(ContextConsentStore store) => MaterialApp(
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
    );
