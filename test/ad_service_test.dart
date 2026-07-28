import 'dart:async';
import 'dart:io';

import 'package:finn_ai/src/ads/banner_ad_widget.dart';
import 'package:finn_ai/src/creations/creation_generator.dart';
import 'package:finn_ai/src/creations/creation_model.dart';
import 'package:finn_ai/src/creations/creation_store.dart';
import 'package:finn_ai/src/creations/creations_controller.dart';
import 'package:finn_ai/src/creations/creations_page.dart';
import 'package:finn_ai/src/flux_app.dart';
import 'package:finn_ai/src/home/home_shell.dart';
import 'package:finn_ai/src/privacy/ad_consent_service.dart';
import 'package:finn_ai/src/settings/settings_page.dart';
import 'package:finn_ai/src/skills/skills_page.dart';
import 'package:finn_ai/src/you/you_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ─── Fake BannerAd ───────────────────────────────────────────────────────────
// google_mobile_ads does not expose a constructor for testing, so we use a
// minimal fake that satisfies the BannerAd API used by BannerAdWidget.

class _FakeBannerAd extends BannerAd {
  _FakeBannerAd()
    : super(
        adUnitId: 'ca-app-pub-3940256099942544/6300978111',
        size: AdSize.banner,
        request: const AdRequest(),
        listener: const BannerAdListener(),
      );

  bool disposed = false;

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

// ─── Controllable ad loader ───────────────────────────────────────────────────
// Holds the callbacks from the most recent _loadAdIfAllowed call so the test
// can fire them at will.

class _ControlledLoader {
  Completer<void Function()>? _pending;

  // Pending callbacks for the in-flight request (generation, onLoaded, onFailed).
  int? capturedGeneration;
  void Function(BannerAd, int)? capturedOnLoaded;
  void Function(Ad, LoadAdError, int)? capturedOnFailed;

  BannerAdLoader get loader =>
      ({
        required String adUnitId,
        required int generation,
        required void Function(BannerAd, int) onLoaded,
        required void Function(Ad, LoadAdError, int) onFailed,
      }) async {
        capturedGeneration = generation;
        capturedOnLoaded = onLoaded;
        capturedOnFailed = onFailed;
        // Pause here until the test calls [complete].
        _pending = Completer();
        await _pending!.future;
      };

  /// Unblock the loader future (simulates SDK returning).
  void complete() => _pending?.complete(() {});
}

class _SwitchableCreationGenerator implements CreationGenerator {
  Completer<CreationDraft>? pending;

  @override
  Future<CreationDraft> generate(String prompt, CreationKind kind) async {
    final completer = pending;
    if (completer != null) return completer.future;
    return const CreationDraft(
      title: 'Local plan',
      summary: 'A locally generated plan.',
      sections: [],
    );
  }
}

class _MemoryCreationStore extends CreationStore {
  _MemoryCreationStore(this.records)
    : super(directoryProvider: () async => Directory.systemTemp);

  List<FinnCreation> records;

  @override
  Future<List<FinnCreation>> load() async => List.of(records);

  @override
  Future<void> save(List<FinnCreation> creations) async {
    records = List.of(creations);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ad Service & AdMob Layout Tests', () {
    testWidgets(
      'BannerAdWidget collapses cleanly when consent is not granted',
      (tester) async {
        expect(AdConsentService.instance.canRequestAds, isFalse);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: BannerAdWidget())),
        );

        await tester.pump(const Duration(milliseconds: 500));

        final finder = find.byType(BannerAdWidget);
        expect(finder, findsOneWidget);

        final renderBox = tester.renderObject(finder) as RenderBox;
        expect(renderBox.size.height, 0);
        expect(renderBox.size.width, 0);
      },
    );

    testWidgets('SettingsPage reserves zero height for unconsented ad banner', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(home: SettingsPage(onBack: () {})));

      await tester.pump(const Duration(milliseconds: 500));

      final bannerFinder = find.byType(BannerAdWidget, skipOffstage: false);
      expect(bannerFinder, findsOneWidget);
      final bannerBox = tester.renderObject(bannerFinder) as RenderBox;
      expect(bannerBox.size.height, 0);

      final sectionHeader = find.text('AI MODELS');
      expect(sectionHeader, findsOneWidget);
    });

    testWidgets(
      'HomeShell sidebar reserves zero height for unconsented ad banner',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: HomeShell()));

        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.byType(BannerAdWidget),
          findsNothing,
          reason: 'native ads must not ride the sidebar transition',
        );
      },
    );

    testWidgets('onboarding and personalization editors are ad-free', (
      tester,
    ) async {
      await tester.pumpWidget(const FluxApp(enableModelDownload: false));
      await tester.pump();
      expect(find.byType(BannerAdWidget), findsNothing);

      await tester.pumpWidget(MaterialApp(home: YouPage(onBack: () {})));
      await tester.pump();
      expect(find.byType(BannerAdWidget), findsNothing);

      await tester.pumpWidget(MaterialApp(home: SkillsPage(onBack: () {})));
      await tester.pump();
      expect(find.byType(BannerAdWidget), findsNothing);
    });

    testWidgets(
      'placement gate prevents requests and invalidates an in-flight ad',
      (tester) async {
        final loader = _ControlledLoader();
        final staleAd = _FakeBannerAd();
        addTearDown(AdConsentService.instance.testRevokeConsent);
        AdConsentService.instance.testGrantConsent();

        Widget app({required bool enabled}) => MaterialApp(
          home: Scaffold(
            body: BannerAdWidget(
              key: const ValueKey('gated-banner'),
              enabled: enabled,
              adLoader: loader.loader,
              isSupportedPlatformOverride: true,
            ),
          ),
        );

        await tester.pumpWidget(app(enabled: false));
        await tester.pump();
        expect(loader.capturedGeneration, isNull);
        expect(
          (tester.renderObject(find.byType(BannerAdWidget)) as RenderBox)
              .size
              .height,
          0,
        );

        await tester.pumpWidget(app(enabled: true));
        await tester.pump();
        expect(loader.capturedGeneration, 0);
        final onLoaded = loader.capturedOnLoaded!;

        await tester.pumpWidget(app(enabled: false));
        await tester.pump();
        onLoaded(staleAd, 0);
        loader.complete();
        await tester.pump();

        expect(staleAd.disposed, isTrue);
        expect(
          (tester.renderObject(find.byType(BannerAdWidget)) as RenderBox)
              .size
              .height,
          0,
        );
      },
    );

    testWidgets('Creations placement is enabled only while idle', (
      tester,
    ) async {
      final generator = _SwitchableCreationGenerator();
      final controller = CreationsController(
        _MemoryCreationStore([
          FinnCreation(
            id: 'existing',
            kind: CreationKind.app,
            prompt: 'First local plan',
            title: 'Local plan',
            summary: 'Already generated locally.',
            sections: const [],
            createdAt: DateTime(2026, 7, 27),
          ),
        ]),
        generator,
      );
      addTearDown(controller.dispose);
      await controller.load();

      await tester.pumpWidget(
        MaterialApp(home: CreationsPage(controller: controller)),
      );
      await tester.pump();
      await tester.pump();

      BannerAdWidget placement() =>
          tester.widget(find.byKey(const Key('creations-idle-ad')));
      expect(placement().enabled, isTrue);

      generator.pending = Completer<CreationDraft>();
      final generation = controller.create(
        'Another local plan',
        CreationKind.presentation,
      );
      await tester.pump();
      expect(controller.generating, isTrue);
      expect(placement().enabled, isFalse);
      expect(
        (tester.renderObject(find.byKey(const Key('creations-idle-ad')))
                as RenderBox)
            .size
            .height,
        0,
      );

      generator.pending!.complete(
        const CreationDraft(
          title: 'Finished plan',
          summary: 'Finished locally.',
          sections: [],
        ),
      );
      await generation;
      await tester.pump();
      expect(controller.generating, isFalse);
      expect(placement().enabled, isTrue);
    });

    testWidgets(
      'BannerAdWidget stays collapsed when consent is denied throughout',
      (tester) async {
        expect(AdConsentService.instance.canRequestAds, isFalse);

        bool? reportedState;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BannerAdWidget(
                onAdLoadedStateChanged: (loaded) => reportedState = loaded,
              ),
            ),
          ),
        );

        await tester.pump();

        final finder = find.byType(BannerAdWidget);
        expect(finder, findsOneWidget);
        expect((tester.renderObject(finder) as RenderBox).size.height, 0);

        await tester.pump(const Duration(milliseconds: 500));

        expect((tester.renderObject(finder) as RenderBox).size.height, 0);
        expect(reportedState, isNot(true));
      },
    );

    // ── Generation-ID race-condition test ─────────────────────────────────────
    //
    // Sequence:
    //   1. Consent is allowed  → request #1 starts (gen 0).
    //   2. Consent is revoked  → gen counter advances to 1; layout collapses.
    //   3. Consent is re-granted → request #2 starts (gen 1).
    //   4. Request #1 callback arrives → generation mismatch (0 ≠ 1), ad
    //      is disposed, layout stays collapsed.
    //   5. Request #2 callback arrives while consent is denied → the live-
    //      consent guard also rejects it; ad is disposed, layout stays collapsed.
    testWidgets(
      'Injectable loader: stale generation-0 callback is disposed after consent revoke; generation-1 callback respects current consent state',
      (tester) async {
        // Start with consent denied so _loadAdIfAllowed is skipped on init.
        expect(AdConsentService.instance.canRequestAds, isFalse);
        addTearDown(AdConsentService.instance.testRevokeConsent);

        final loader = _ControlledLoader();
        final fakeAd0 = _FakeBannerAd();
        final fakeAd1 = _FakeBannerAd();

        bool? lastReportedState;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BannerAdWidget(
                adLoader: loader.loader,
                // Bypass the Android/iOS platform gate in the test runner.
                isSupportedPlatformOverride: true,
                onAdLoadedStateChanged: (v) => lastReportedState = v,
              ),
            ),
          ),
        );
        await tester.pump();

        // ── Step 1: Grant consent → request #1 begins (gen 0) ──────────────
        AdConsentService.instance.testGrantConsent();
        await tester.pump();

        expect(loader.capturedGeneration, 0, reason: 'first request is gen 0');
        final gen0OnLoaded = loader.capturedOnLoaded!;

        // ── Step 2: Revoke consent while request #1 is in flight ───────────
        AdConsentService.instance.testRevokeConsent();
        await tester.pump();

        // layout must be collapsed and no ad reported
        final finder = find.byType(BannerAdWidget);
        expect((tester.renderObject(finder) as RenderBox).size.height, 0);

        // ── Step 3: Re-grant consent → request #2 begins (gen 1) ──────────
        AdConsentService.instance.testGrantConsent();
        await tester.pump();

        expect(loader.capturedGeneration, 1, reason: 'second request is gen 1');

        // ── Step 4: Fire the stale gen-0 callback ─────────────────────────
        gen0OnLoaded(fakeAd0, 0 /* stale generation */);
        await tester.pump();

        // The stale ad must be disposed and the layout must stay collapsed.
        expect(
          fakeAd0.disposed,
          isTrue,
          reason: 'stale generation-0 ad must be disposed immediately',
        );
        expect((tester.renderObject(finder) as RenderBox).size.height, 0);
        expect(lastReportedState, isNot(true));

        // ── Step 5: Fire gen-1 callback while consent is denied ───────────
        // Revoke consent again so the live-consent check rejects even the
        // generation-matching callback.
        AdConsentService.instance.testRevokeConsent();
        await tester.pump();

        final gen1OnLoaded = loader.capturedOnLoaded!;
        gen1OnLoaded(fakeAd1, 1 /* current generation before re-revoke */);
        await tester.pump();

        // Consent was denied at callback time so the ad must be disposed and
        // the layout must remain collapsed.
        expect(
          fakeAd1.disposed,
          isTrue,
          reason:
              'gen-1 ad must be disposed when consent is denied on callback',
        );
        expect((tester.renderObject(finder) as RenderBox).size.height, 0);
        expect(lastReportedState, isNot(true));
      },
    );
  });
}
