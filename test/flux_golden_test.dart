import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/app/bootstrap.dart';
import 'package:finn_ai/src/features/chat/home_shell.dart';
import 'package:finn_ai/src/features/reporting/report_dialog.dart';
import 'package:finn_ai/src/features/reporting/report_service.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The screens the app can already boot into a test without a device, a
/// downloaded model, or a running engine.
class _Screen {
  const _Screen(this.name, this.page);

  /// Matches a golden file under `goldens/`.
  final String name;

  /// The onboarding PageView index, or null for the welcome screen, which is
  /// page 0 and needs no jump.
  final int? page;
}

const List<_Screen> _screens = [
  _Screen('welcome', null),
  _Screen('onboarding_model', 2),
  _Screen('onboarding_consent', 3),
  _Screen('onboarding_finish', 5),
];

/// The four form factors the design has to survive. The audit found a
/// short-viewport squeeze in onboarding and absolute-positioned artwork that
/// broke in landscape; a golden per size is the cheapest way to keep those from
/// coming back silently.
class _Device {
  const _Device(this.name, this.size);

  final String name;
  final Size size;
}

const List<_Device> _devices = [
  _Device('phone', Size(390, 844)),
  _Device('small', Size(360, 740)),
  _Device('tablet', Size(768, 1024)),
  _Device('landscape', Size(844, 390)),
];

void _applyDevice(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _applyBrightness(WidgetTester tester, Brightness brightness) {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

String _suffix(_Device device, Brightness brightness) =>
    '${device.name}_${brightness == Brightness.dark ? 'dark' : 'light'}';

/// The app's own typeface.
///
/// Without this the test engine falls back to its box-drawing font and every
/// string rasterises as a row of solid blocks — which is exactly what the
/// goldens committed before this suite looked like: unreadable black frames
/// that no one could review. Loading the real font is what makes a golden
/// worth looking at.
Future<void> _loadAppFont() async {
  await _loadFont('InstrumentSans', 'assets/fonts/InstrumentSans-Variable.ttf');
  // Material's icon font is not registered in the test engine either, so a
  // dropdown arrow would capture as a box. Best-effort: the path depends on
  // where the SDK lives, and a missing icon font is not worth failing over.
  final dart = File(Platform.resolvedExecutable).absolute.path;
  final sdkRoot = File(dart).parent.parent.parent.parent.path;
  final iconFont = File(
    '$sdkRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (iconFont.existsSync()) {
    await _loadFont('MaterialIcons', iconFont.path);
  }
}

Future<void> _loadFont(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
}

void main() {
  setUpAll(_loadAppFont);

  group('onboarding goldens', () {
    for (final device in _devices) {
      for (final brightness in Brightness.values) {
        final label = _suffix(device, brightness);

        for (final screen in _screens) {
          testWidgets('${screen.name} on ${device.name} (${brightness.name})', (
            tester,
          ) async {
            _applyDevice(tester, device.size);
            _applyBrightness(tester, brightness);

            await tester.pumpWidget(
              const FluxApp(enableModelDownload: false),
            );
            final page = screen.page;
            if (page != null) {
              tester
                  .widget<PageView>(find.byType(PageView))
                  .controller!
                  .jumpToPage(page);
            }
            await tester.pump();
            // The welcome glow and the download ring both animate; two frames
            // past the longest one keeps the capture stable.
            await tester.pump(const Duration(milliseconds: 900));
            await tester.pump(const Duration(milliseconds: 400));

            expect(tester.takeException(), isNull, reason: 'render error');
            await expectLater(
              find.byType(FluxApp),
              matchesGoldenFile('goldens/${screen.name}_$label.png'),
            );
          });
        }
      }
    }
  });

  group('shared widget goldens', () {
    Future<void> captureSheet(
      WidgetTester tester, {
      required Brightness brightness,
      required String name,
      required Widget sheet,
    }) async {
      _applyDevice(tester, const Size(390, 640));
      _applyBrightness(tester, brightness);

      await tester.pumpWidget(
        MaterialApp(
          theme:
              brightness == Brightness.dark ? FluxTheme.dark : FluxTheme.light,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: RepaintBoundary(key: ValueKey('sheet'), child: sheet),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'render error');
      await expectLater(
        find.byKey(const ValueKey('sheet')),
        matchesGoldenFile('goldens/$name.png'),
      );
    }

    /// Chips, section labels, a pill, icon buttons and a collapsed disclosure —
    /// the compact controls the a11y pass gave a 48dp hit area without making
    /// them 48dp tall.
    Widget controlSheet(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FluxSectionLabel('AI MODEL'),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FluxChip(label: 'All', selected: true),
                FluxChip(label: 'Apps'),
                FluxChip(label: 'Widgets'),
                FluxChip(label: 'Presentations'),
              ],
            ),
            const SizedBox(height: 20),
            const FluxSectionLabel('Spoken responses'),
            const SizedBox(height: 8),
            Text(
              L10n.of(context).settingsSpokenResponsesBody,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            const FluxDisclosure(
              leading: FluxIcon(icon: FluxIcons.search, size: 14),
              label: 'Searched the web',
              trailing: '3 steps',
              child: FluxDisclosureRow(
                leading: FluxIcon(icon: FluxIcons.internet, size: 14),
                title: 'Read “capital of France”',
              ),
            ),
            const SizedBox(height: 16),
            const Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FluxIconButton(icon: FluxIcons.copy, tooltip: 'Copy'),
                FluxIconButton(icon: FluxIcons.refresh, tooltip: 'Regenerate'),
                FluxIconButton(icon: FluxIcons.moreHorizontal, tooltip: 'More'),
                FluxPillButton(label: 'Start using FinnAI', onTap: null),
              ],
            ),
          ],
        );

    /// The banner the chat shows when another conversation is still generating.
    Widget noticeSheet() => const OtherChatGenerationNotice(
          title: 'Bicycle repair',
          onOpen: _noop,
          onStop: _noop,
        );

    for (final brightness in Brightness.values) {
      final label = brightness == Brightness.dark ? 'dark' : 'light';

      testWidgets('controls sheet (${brightness.name})', (tester) async {
        await captureSheet(
          tester,
          brightness: brightness,
          name: 'widgets_controls_$label',
          sheet: Builder(builder: controlSheet),
        );
      });

      testWidgets('chat notice banner (${brightness.name})', (tester) async {
        await captureSheet(
          tester,
          brightness: brightness,
          name: 'widgets_notice_$label',
          sheet: noticeSheet(),
        );
      });

      testWidgets('report dialog body (${brightness.name})', (tester) async {
        _applyDevice(tester, const Size(390, 844));
        _applyBrightness(tester, brightness);

        // Shown through a real dialog route: an `AlertDialog` dropped straight
        // into a Scaffold sizes itself to its intrinsic width and its title row
        // overflows, which is a property of the harness, not of the screen.
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.dark
                ? FluxTheme.dark
                : FluxTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => ReportDialog.show(
                      context,
                      assistantResponse: _flaggedResponse,
                      userPrompt: 'how do I fix a flat tyre',
                      modelTier: 'on-device',
                      appVersion: '1.0.0',
                      reportService: _unusedService,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(ReportDialog), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'render error');
        await expectLater(
          find.byType(ReportDialog),
          matchesGoldenFile('goldens/report_dialog_$label.png'),
        );
      });
    }
  });
}

void _noop() {}

/// Long enough that the preview box hits its `maxHeight: 90` and scrolls, which
/// is the part of the dialog the a11y pass actually changed.
const String _flaggedResponse =
    'You can replace the inner tube once the wheel is off the bike. The valve '
    'keeps the tube from pulling back into the tyre, so hold it while you '
    'lever the tyre edge over the rim.';

/// The dialog only touches the service on submit, so nothing here goes out.
final ReportService _unusedService = ReportService(
  endpoint: 'https://reports.example.invalid/v1/reports',
  reportEmail: 'support@example.invalid',
);
