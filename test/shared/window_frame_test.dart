import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/src/platform/window_chrome.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_window_frame.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('finn_ai/window');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late WindowChrome chrome;

  setUp(() {
    calls = [];
    chrome = WindowChrome(channel: channel);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'hasCustomChrome' => true,
        'getState' => {'maximized': true, 'fullscreen': false, 'focused': true},
        _ => null,
      };
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 700);
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
        builder: (context, child) => FinnWindowFrame(
          chrome: chrome,
          forceChrome: true,
          child: child!,
        ),
        home: const Text('body'),
      ),
    );
    await tester.pump();
  }

  List<String> names() => [for (final c in calls) c.method];

  testWidgets('the three buttons drive the window', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('window-minimize')));
    await tester.tap(find.byKey(const ValueKey('window-maximize')));
    await tester.tap(find.byKey(const ValueKey('window-close')));
    expect(names(), ['minimize', 'toggleMaximize', 'close']);
  });

  testWidgets('double-clicking the bar toggles maximise', (tester) async {
    await pump(tester);
    final bar = find.byKey(const ValueKey('title-bar-drag'));
    await tester.tap(bar);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(bar);
    await tester.pump(const Duration(milliseconds: 400));
    expect(names(), contains('toggleMaximize'));
  });

  testWidgets('dragging the bar hands the move to the window manager', (
    tester,
  ) async {
    await pump(tester);
    await tester.drag(
      find.byKey(const ValueKey('title-bar-drag')),
      const Offset(60, 10),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(names(), contains('startDrag'));
  });

  testWidgets('the screen runs under the bar and keeps clear of it', (
    tester,
  ) async {
    late double top;
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            FinnWindowFrame(chrome: chrome, forceChrome: true, child: child!),
        home: Builder(builder: (context) {
          top = MediaQuery.paddingOf(context).top;
          return const SizedBox.expand(key: ValueKey('screen'));
        }),
      ),
    );
    expect(top, FinnWindowFrame.barHeight);
    expect(tester.getSize(find.byKey(const ValueKey('screen'))).height, 700);
  });

  testWidgets('pressing the window edge starts a resize', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(
      const Offset(900 - 2, 350),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    expect(calls.where((c) => c.method == 'startResize').single.arguments, 2);
  });

  testWidgets('maximised, there are no edges to resize from', (tester) async {
    await pump(tester);
    chrome.state.value = const WindowChromeState(maximized: true);
    await tester.pump();
    final gesture = await tester.startGesture(
      const Offset(900 - 2, 350),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    expect(names().where((n) => n == 'startResize'), isEmpty);
    expect(find.byKey(const ValueKey('window-maximize')), findsOneWidget);
  });

  testWidgets('full screen removes the bar and F11 toggles it', (tester) async {
    await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    expect(names(), contains('toggleFullscreen'));
    chrome.state.value = const WindowChromeState(fullscreen: true);
    await tester.pump();
    expect(find.byKey(const ValueKey('window-close')), findsNothing);
  });

  testWidgets('without the runner channel the frame draws nothing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            FinnWindowFrame(chrome: chrome, child: child!),
        home: const Text('plain'),
      ),
    );
    expect(find.byType(FinnTitleBar), findsNothing);
    expect(find.text('plain'), findsOneWidget);
  });

  test('initialize reads the runner and follows its state changes', () async {
    await chrome.initialize();
    expect(chrome.enabled.value, isTrue);
    expect(chrome.state.value.maximized, isTrue);

    await messenger.handlePlatformMessage(
      'finn_ai/window',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('stateChanged', {
          'maximized': false,
          'fullscreen': true,
          'focused': false,
        }),
      ),
      (_) {},
    );
    expect(
      chrome.state.value,
      const WindowChromeState(fullscreen: true, focused: false),
    );
  });

  test('a runner with no window channel leaves the chrome off', () async {
    messenger.setMockMethodCallHandler(channel, null);
    await chrome.initialize();
    expect(chrome.enabled.value, isFalse);
  });
}
