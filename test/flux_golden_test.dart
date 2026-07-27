import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finn_ai/src/flux_app.dart';

void main() {
  testWidgets('welcome screen matches the mobile baseline', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FluxApp());
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byType(FluxApp),
      matchesGoldenFile('goldens/welcome.png'),
    );
  });

  testWidgets('automatic model installer matches onboarding baseline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FluxApp(enableModelDownload: false));
    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    await expectLater(
      find.byType(FluxApp),
      matchesGoldenFile('goldens/onboarding_model.png'),
    );
  });
}
