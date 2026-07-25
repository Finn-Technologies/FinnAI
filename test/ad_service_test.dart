import 'package:finn_ai/src/ads/banner_ad_widget.dart';
import 'package:finn_ai/src/home/home_shell.dart';
import 'package:finn_ai/src/privacy/ad_consent_service.dart';
import 'package:finn_ai/src/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

        final bannerFinder = find.byType(BannerAdWidget);
        if (bannerFinder.evaluate().isNotEmpty) {
          final bannerBox = tester.renderObject(bannerFinder) as RenderBox;
          expect(bannerBox.size.height, 0);
        }
      },
    );
  });
}
