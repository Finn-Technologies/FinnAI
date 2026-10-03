import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/code_shell.dart';
import 'package:finn_ai/src/features/code/providers/code_provider.dart';
import 'package:finn_ai/src/features/code/providers/provider_client.dart';
import 'package:finn_ai/src/features/code/providers/provider_store.dart';
import 'package:finn_ai/src/features/code/providers/secret_store.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/sessions/code_session_store.dart';
import 'package:finn_ai/src/features/code/settings/code_provider_page.dart';
import 'package:finn_ai/src/features/code/settings/code_providers_page.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_page.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';
import 'package:finn_ai/src/features/code/ui/code_action_card.dart';
import 'package:finn_ai/src/features/code/ui/code_models_page.dart';
import 'package:finn_ai/src/shared/config/app_mode.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_brand_switcher.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

import 'code_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late MemoryCodeSecretStore secrets;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('finn_code_ui_');
    secrets = MemoryCodeSecretStore();
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<void> useTallPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  CodeServices services({
    FakeGateway? gateway,
    FakeRunner? runner,
    http.Client? client,
  }) =>
      CodeServices(
        sessions: CodeSessionStore(
          directoryProvider: () async => temp,
          saveDelay: const Duration(milliseconds: 1),
        ),
        providers: CodeProviderStore(
          secrets: secrets,
          client: CodeProviderClient(
            client: client ?? MockClient((_) async => http.Response('', 500)),
          ),
          directoryProvider: () async => temp,
        ),
        settings: CodeSettingsStore(directoryProvider: () async => temp),
        runner: runner ?? FakeRunner(),
        gatewayFactory: () async => gateway ?? FakeGateway(['ok']),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Lets a handler that does file or network work run to the end: real time
  /// for the I/O, then the fake clock so the widget sees the result. Waits for
  /// [until] when given (up to a generous bound), because how long the I/O
  /// takes depends on how busy the machine is; a fixed number of rounds is a
  /// race.
  Future<void> settleIo(WidgetTester tester, {bool Function()? until}) async {
    final rounds = until == null ? 14 : 200;
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (until != null && until()) break;
    }
    // One more pass so a state change made on the last round is drawn.
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('brand switcher', () {
    testWidgets('names the current app and switches to the other',
        (tester) async {
      await useTallPhone(tester);
      final modes = AppModeController(directoryProvider: () async => temp);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FinnBrandSwitcher(
                current: FinnAppMode.chat,
                controller: modes,
              ),
            ),
          ),
        ),
      );
      expect(find.text('FinnAI'), findsOneWidget);
      // The current app's name is the title; the other one is not listed until
      // the row is opened.
      expect(find.text('FinnAI Code'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('brand-switcher')));
      await settle(tester);
      expect(find.text('FinnAI Code'), findsOneWidget);

      await tester.tap(find.text('FinnAI Code'));
      await settle(tester);
      expect(modes.mode, FinnAppMode.code);
    });

    testWidgets('the option is set in the same type as the wordmark',
        (tester) async {
      // The two lines are one heading: the app you are in, and the one you can
      // go to. The option used to be 4dp smaller and a step down the text theme,
      // which read as a lesser label rather than the equal alternative.
      await useTallPhone(tester);
      final modes = AppModeController(directoryProvider: () async => temp);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinnBrandSwitcher(
              current: FinnAppMode.chat,
              controller: modes,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('brand-switcher')));
      await settle(tester);

      final wordmark = tester.widget<Text>(find.text('FinnAI'));
      final option = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('brand-switcher-option')),
          matching: find.text('FinnAI Code'),
        ),
      );

      // Same size, weight, height and colour.
      expect(option.style?.fontSize, wordmark.style?.fontSize);
      expect(option.style?.fontWeight, wordmark.style?.fontWeight);
      expect(option.style?.height, wordmark.style?.height);
      expect(option.style?.color, wordmark.style?.color);
      expect(option.style?.letterSpacing, wordmark.style?.letterSpacing);
      // And both are the app-name size, not the old 20dp option.
      expect(option.style?.fontSize, 24);
    });

    testWidgets('the option is plain text, not a row with a glyph',
        (tester) async {
      // It used to open a popup: a filled card, two rows, an icon each and a
      // check on the current one. The reveal carries no fill and no glyph.
      await useTallPhone(tester);
      final modes = AppModeController(directoryProvider: () async => temp);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FinnBrandSwitcher(
                current: FinnAppMode.chat,
                controller: modes,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('brand-switcher')));
      await settle(tester);

      final option = find.byKey(const ValueKey('brand-switcher-option'));
      expect(option, findsOneWidget);
      // No glyph inside the option row.
      expect(
        find.descendant(of: option, matching: find.byType(FluxIcon)),
        findsNothing,
      );
      // And no filled container behind it: the only decoration in the reveal is
      // the blur, which paints nothing of its own.
      for (final element in find.byType(Stack).evaluate()) {
        final stack = element.widget as Stack;
        for (final child in stack.children) {
          if (child is Container && child.decoration is BoxDecoration) {
            final decoration = child.decoration as BoxDecoration;
            expect(decoration.color,
                isNot(FluxColors.controlOf(tester.element(option))));
          }
        }
      }
    });

    testWidgets('the sidebar makes room and keeps the option legible',
        (tester) async {
      // The reveal pushes the destinations down rather than covering them, and
      // while it is open the brand row stops fading — otherwise it would fade
      // the option the user is reading, and a light history card scrolling
      // underneath would leave the option's text on white with nothing behind
      // it.
      await useTallPhone(tester);
      final modes = AppModeController(directoryProvider: () async => temp);
      await tester.pumpWidget(
        MaterialApp(home: CodeShell(services: services())),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('home-menu-button')));
      await settle(tester);

      // This shell is FinnAI Code, so the wordmark reads "FinnAI Code" and the
      // reveal offers the other app.
      expect(find.text('FinnAI Code'), findsOneWidget);
      expect(find.text('FinnAI'), findsNothing);

      final before = tester.getRect(find.text('Files'));
      await tester.tap(find.byKey(const ValueKey('brand-switcher')));
      await settle(tester);

      // The destination moved down to make room rather than being covered.
      expect(tester.getRect(find.text('Files')).top, greaterThan(before.top));

      // And the option is inside the open reveal, not merely on screen.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('brand-switcher-option')),
          matching: find.text('FinnAI'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('FinnAI'));
      await settle(tester);
      expect(modes.mode, FinnAppMode.chat);
    });

    testWidgets('while open, the option stays legible over a light card',
        (tester) async {
      // A chat/session card is much lighter than the panel in both themes, and
      // it slides up under the wordmark as the history scrolls. Two things have
      // to hold for the option to stay readable then: the brand row must stop
      // fading (it would otherwise fade the option with it), and the panel's
      // pinned backing must extend past the reveal so the text never sits
      // directly on a scrolling card.
      await useTallPhone(tester);
      final s = services();
      await tester.pumpWidget(MaterialApp(home: CodeShell(services: s)));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('home-menu-button')));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('brand-switcher')));
      await settle(tester);
      expect(find.text('FinnAI'), findsOneWidget);

      // Scroll the history up under the wordmark, which is the only moment
      // anything is behind the reveal.
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(160);
      await tester.pump(const Duration(milliseconds: 300));

      // Still there, still opaque enough to read, and no render error.
      expect(tester.takeException(), isNull);
      final option = find.byKey(const ValueKey('brand-switcher-option'));
      expect(option, findsOneWidget);

      // The option's own opacity is 1 — it is not faded with the row.
      final opacity = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: option,
              matching: find.byType(Opacity),
            ),
          )
          .toList();
      if (opacity.isNotEmpty) {
        expect(opacity.last.opacity, 1.0);
      }
    });

    testWidgets('the reveal blurs what scrolls under it, ramping downward',
        (tester) async {
      // The band layout is load-bearing: Flutter cannot mask a backdrop blur, so
      // the ramp is clipped bands that accumulate. Both halves are asserted, and
      // the sigmas are equal on purpose — see FluxProgressiveBlur.
      await useTallPhone(tester);
      final modes = AppModeController(directoryProvider: () async => temp);
      await tester.pumpWidget(
        MaterialApp(
            home: Scaffold(
                body: FinnBrandSwitcher(
          current: FinnAppMode.chat,
          controller: modes,
        ))),
      );
      await tester.tap(find.byKey(const ValueKey('brand-switcher')));
      await settle(tester);

      final bands = tester
          .widgetList<BackdropFilter>(find.byType(BackdropFilter))
          .toList();
      expect(bands.length, greaterThan(1),
          reason: 'a ramp needs more than one');

      // Every band blurs by the same amount and covers everything below its own
      // top edge, so strength accumulates with depth. A per-band sigma that grew
      // with depth would compound instead.
      final sigmas = {
        for (final band in bands) (band.filter as ImageFilter).toString(),
      };
      expect(sigmas.length, 1, reason: 'bands must not each differ: $sigmas');

      // The band count is what makes it a ramp, and the panel is short, so the
      // bands must not be so few that the steps show.
      expect(bands.length, greaterThanOrEqualTo(6));
    });

    testWidgets('reports its reveal height so the panel can make room',
        (tester) async {
      await useTallPhone(tester);
      final expansion = BrandExpansion();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FinnBrandSwitcher(
                current: FinnAppMode.chat,
                controller:
                    AppModeController(directoryProvider: () async => temp),
                expansion: expansion,
              ),
            ),
          ),
        ),
      );
      expect(expansion.height, 0);

      await tester.tap(find.byKey(const ValueKey('brand-switcher')));
      await settle(tester);
      expect(expansion.height, FinnBrandSwitcher.revealHeight);
      expect(expansion.isOpen, isTrue);

      await tester.tap(find.byKey(const ValueKey('brand-switcher')));
      await settle(tester);
      expect(expansion.height, 0);
      expect(expansion.isOpen, isFalse);
    });

    testWidgets('shows FinnAI Code when that is the current app',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: FinnBrandSwitcher(current: FinnAppMode.code)),
          ),
        ),
      );
      expect(find.text('FinnAI Code'), findsOneWidget);
      // In reverse, the reveal offers FinnAI.
      final modes = AppModeController(directoryProvider: () async => temp);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FinnBrandSwitcher(
                current: FinnAppMode.code,
                controller: modes,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('brand-switcher')));
      await settle(tester);
      expect(find.text('FinnAI'), findsOneWidget);
      await tester.tap(find.text('FinnAI'));
      await settle(tester);
      expect(modes.mode, FinnAppMode.chat);
    });

    test('the mode is remembered', () async {
      final first = AppModeController(directoryProvider: () async => temp);
      await first.set(FinnAppMode.code);
      final second = AppModeController(directoryProvider: () async => temp);
      await second.initialize();
      expect(second.mode, FinnAppMode.code);
      await second.deleteStorage();
      final third = AppModeController(directoryProvider: () async => temp);
      await third.initialize();
      expect(third.mode, FinnAppMode.chat);
    });
  });

  group('CodeShell', () {
    testWidgets('starts on the empty slate with the composer and chips',
        (tester) async {
      await useTallPhone(tester);
      await tester.pumpWidget(
        MaterialApp(home: CodeShell(services: services())),
      );
      await settle(tester);

      expect(find.text('What shall we build?'), findsOneWidget);
      expect(find.byKey(const ValueKey('code-composer-field')), findsOneWidget);
      expect(find.text('FinnAI · on device'), findsOneWidget);
      expect(find.text('Auto-edit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the composer is one pill tall, not stretched', (tester) async {
      await useTallPhone(tester);
      await tester.pumpWidget(
        MaterialApp(home: CodeShell(services: services())),
      );
      await settle(tester);

      final field = tester.getRect(
        find.byKey(const ValueKey('code-composer-field')),
      );
      final chip =
          tester.getRect(find.byKey(const ValueKey('code-model-chip')));
      final send =
          tester.getRect(find.byKey(const ValueKey('code-send-button')));
      // The pill is about 50dp, and the chips sit just above it.
      expect(send.height, 50);
      expect(field.height, lessThan(30));
      expect(send.top - chip.bottom, lessThan(24));
    });

    group('dark mode matches FinnAI', () {
      // FinnAI Code's permanent surfaces used to carry their own shadows while
      // the rest of the app had moved to fill + a 1px hairline. Over the
      // near-black canvas a shadow is `elevationOf` (#F5F5F7), so the pill wore
      // a pale halo and the action card had no edge at all.
      Future<void> pumpDark(WidgetTester tester, Widget home) async {
        await useTallPhone(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: FluxTheme.dark,
            home: home,
          ),
        );
        await settle(tester);
      }

      /// The painted decoration of every container under [finder].
      List<BoxDecoration> decorationsOf(WidgetTester tester, Finder finder) {
        final found = <BoxDecoration>[];
        for (final element in finder.evaluate()) {
          final widget = element.widget;
          if (widget is Container && widget.decoration is BoxDecoration) {
            found.add(widget.decoration as BoxDecoration);
          }
        }
        return found;
      }

      void expectFlatWithHairline(List<BoxDecoration> found) {
        expect(found, isNotEmpty);
        for (final decoration in found) {
          expect(
            decoration.boxShadow,
            isNull,
            reason: 'a permanent surface must not cast a drop shadow',
          );
          expect(
            decoration.border,
            isA<Border>(),
            reason: 'it separates with a 1px hairline instead',
          );
          expect((decoration.border! as Border).top.width, 1);
        }
      }

      testWidgets('the composer pill is flat with a hairline', (tester) async {
        await pumpDark(tester, CodeShell(services: services()));

        final pill = decorationsOf(
          tester,
          find.ancestor(
            of: find.byKey(const ValueKey('code-composer-field')),
            matching: find.byType(Container),
          ),
        );
        expectFlatWithHairline(pill);
      });

      testWidgets('an action card is flat with a hairline', (tester) async {
        await useTallPhone(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: FluxTheme.dark,
            home: Scaffold(
              body: CodeActionCard(
                action: CodeAction.shell('ls -la').copyWith(
                  status: CodeActionStatus.done,
                  output: 'Listed.',
                ),
              ),
            ),
          ),
        );
        await settle(tester);

        final card = find.byKey(const ValueKey('code-action-card'));
        expect(card, findsOneWidget);
        expectFlatWithHairline(decorationsOf(tester, card));
      });

      testWidgets('the send glyph matches the chat composer', (tester) async {
        // FinnAI Code drew its arrow in actionInkOf — #414141 on the dark
        // disc — where the shared button draws it in canvasOf, #101014. Same
        // control, two different glyph colours in the same theme.
        await pumpDark(tester, CodeShell(services: services()));

        final send = find.byKey(const ValueKey('code-send-button'));
        final glyph = tester.widget<FluxIcon>(
          find.descendant(of: send, matching: find.byType(FluxIcon)),
        );
        expect(glyph.color, FluxColors.canvasOf(tester.element(send)));
      });
    });

    testWidgets('a message is sent, answered and shown', (tester) async {
      await useTallPhone(tester);
      final s = services(gateway: FakeGateway(['Hello from the agent.']));
      await tester.pumpWidget(MaterialApp(home: CodeShell(services: s)));
      await settle(tester);

      await tester.enterText(
        find.byKey(const ValueKey('code-composer-field')),
        'say hello',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('code-send-button')));
      await settleIo(tester);

      expect(find.text('say hello'), findsWidgets);
      expect(find.textContaining('Hello from the agent.'), findsWidgets);
      expect(find.byKey(const ValueKey('code-session-title')), findsOneWidget);
      expect(s.sessions.active!.messages.length, 2);
    });

    testWidgets('a command waits for Run and shows its result', (tester) async {
      await useTallPhone(tester);
      final runner = FakeRunner();
      final s = services(
        gateway: FakeGateway(['```sh\nls\n```', 'Listed.']),
        runner: runner,
      );
      await tester.pumpWidget(MaterialApp(home: CodeShell(services: s)));
      await settle(tester);

      await tester.enterText(
        find.byKey(const ValueKey('code-composer-field')),
        'list files',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('code-send-button')));
      await settleIo(tester);

      expect(find.byKey(const ValueKey('code-action-card')), findsOneWidget);
      expect(find.text('Run command'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(runner.ran, isEmpty);

      await tester.tap(find.text('Run'));
      await settleIo(tester);

      expect(runner.ran.single.command, 'ls');
      expect(find.text('Done'), findsOneWidget);
      expect(find.textContaining('Listed.'), findsWidgets);
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('the menu opens the sidebar with its three destinations',
        (tester) async {
      await useTallPhone(tester);
      await tester.pumpWidget(
        MaterialApp(home: CodeShell(services: services())),
      );
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('home-menu-button')));
      await settle(tester);

      expect(find.text('FinnAI Code'), findsOneWidget);
      expect(find.text('Files'), findsOneWidget);
      expect(find.text('Terminal'), findsOneWidget);
      expect(find.text('Models'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('No sessions yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the permission chip changes the mode', (tester) async {
      await useTallPhone(tester);
      final s = services();
      await tester.pumpWidget(MaterialApp(home: CodeShell(services: s)));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('code-permission-chip')));
      await settle(tester);
      await tester.tap(find.text('Ask first'));
      await settle(tester);

      expect(
        s.settings.settings.permissionMode,
        CodePermissionMode.askEveryTime,
      );
      expect(find.text('Ask first'), findsOneWidget);
    });

    testWidgets('the sidebar lists sessions', (tester) async {
      await useTallPhone(tester);
      final s = services();
      s.sessions.create(title: 'Fix the parser');
      s.sessions.clearActive();
      await tester.pumpWidget(MaterialApp(home: CodeShell(services: s)));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('home-menu-button')));
      await settle(tester);

      expect(find.text('Fix the parser'), findsOneWidget);
    });
  });

  group('provider pages', () {
    final models = jsonEncode({
      'data': [
        {
          'id': 'free/model:free',
          'name': 'A free model',
          'context_length': 32768,
          'pricing': {'prompt': '0', 'completion': '0'},
        },
        {
          'id': 'big/model',
          'name': 'Big model',
          'context_length': 200000,
          'pricing': {'prompt': '0.000003', 'completion': '0.000015'},
        },
      ],
    });

    http.Client openRouterClient() => MockClient((request) async {
          if (request.url.path.endsWith('/models')) {
            return http.Response(models, 200);
          }
          if (request.url.path.endsWith('/key')) {
            return http.Response(
              jsonEncode({
                'data': {
                  'limit': 20,
                  'limit_remaining': 12.5,
                  'usage': 7.5,
                  'is_free_tier': false,
                },
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/credits')) {
            return http.Response('{}', 403);
          }
          // A one-token test completion.
          return http.Response(
            'data: {"choices":[{"delta":{"content":"Hi"}}]}\n\n',
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        });

    testWidgets('lists every provider with its status', (tester) async {
      await useTallPhone(tester);
      final s = services();
      await tester.runAsync(
          () => s.providers.saveKey(CodeProvider.openRouter, 'sk-abcd1234'));
      await tester.pumpWidget(
        MaterialApp(home: CodeProvidersPage(services: s)),
      );
      await settle(tester);

      for (final name in [
        'OpenRouter',
        'Command Code',
        'OpenCode Zen',
        'OpenCode Go',
        'Custom (OpenAI compatible)',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('Connected · ••••1234'), findsOneWidget);
      expect(find.text('Not set up'), findsWidgets);
    });

    testWidgets('adding a key fetches models and the allowance live',
        (tester) async {
      await useTallPhone(tester);
      final s = services(client: openRouterClient());
      await tester.pumpWidget(
        MaterialApp(
          home: CodeProviderPage(
            services: s,
            provider: CodeProvider.openRouter,
          ),
        ),
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('code-key-field')), findsOneWidget);
      expect(find.byKey(const ValueKey('code-allowance')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('code-key-field')),
        'sk-or-secret-9876',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('code-key-save')));
      await tester.tap(find.byKey(const ValueKey('code-key-save')));
      await settleIo(
        tester,
        until: () =>
            find.text('2 models available').evaluate().isNotEmpty &&
            find.byKey(const ValueKey('code-allowance')).evaluate().isNotEmpty,
      );

      expect(s.providers.hasKey(CodeProvider.openRouter), isTrue);
      expect(await s.providers.keyFor(CodeProvider.openRouter),
          'sk-or-secret-9876');
      // The key is not shown again, only its last four characters.
      expect(find.text('sk-or-secret-9876'), findsNothing);
      expect(find.textContaining('••••9876'), findsOneWidget);
      expect(find.textContaining(r'$12.50 left of $20.00'), findsOneWidget);
      expect(find.text('2 models available'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Command Code warns that the Go plan has no API access',
        (tester) async {
      await useTallPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: CodeProviderPage(
            services: services(),
            provider: CodeProvider.commandCode,
          ),
        ),
      );
      await settle(tester);

      expect(find.textContaining('GOAT plan or higher'), findsWidgets);
      expect(find.textContaining('Go plan has no API access'), findsWidgets);
      expect(find.text('Get a key'), findsOneWidget);
    });

    testWidgets('a custom server asks for an address and refuses plain http',
        (tester) async {
      await useTallPhone(tester);
      final s = services();
      await tester.pumpWidget(
        MaterialApp(
          home: CodeProviderPage(
            services: s,
            provider: CodeProvider.custom,
          ),
        ),
      );
      await settle(tester);

      await tester.enterText(
        find.byKey(const ValueKey('code-address-field')),
        'http://api.example.com/v1',
      );
      await tester.tap(find.byKey(const ValueKey('code-address-save')));
      await settle(tester);
      expect(
        find.textContaining('Use an https address'),
        findsOneWidget,
      );
      expect(s.providers.baseUrlOf(CodeProvider.custom), isNull);

      await tester.enterText(
        find.byKey(const ValueKey('code-address-field')),
        'http://192.168.1.5:11434/v1',
      );
      await tester.tap(find.byKey(const ValueKey('code-address-save')));
      await settleIo(
        tester,
        until: () =>
            s.providers.baseUrlOf(CodeProvider.custom) ==
                'http://192.168.1.5:11434/v1' &&
            find.textContaining('Use an https address').evaluate().isEmpty,
      );
      expect(find.textContaining('Use an https address'), findsNothing);
      expect(s.providers.baseUrlOf(CodeProvider.custom),
          'http://192.168.1.5:11434/v1');
    });

    testWidgets('providers without a usage API say so instead of a number',
        (tester) async {
      await useTallPhone(tester);
      final s = services(
        client: MockClient((request) async => http.Response(
              jsonEncode({
                'data': [
                  {'id': 'glm-5.3'},
                ],
              }),
              200,
            )),
      );
      await tester
          .runAsync(() => s.providers.saveKey(CodeProvider.openCodeGo, 'k'));
      await tester.pumpWidget(
        MaterialApp(
          home: CodeProviderPage(
            services: s,
            provider: CodeProvider.openCodeGo,
          ),
        ),
      );
      await settle(tester);

      expect(find.textContaining('doesn’t offer a usage API'), findsOneWidget);
      expect(find.text('Open dashboard'), findsOneWidget);
      expect(find.byKey(const ValueKey('code-allowance')), findsNothing);
    });

    testWidgets('removing a key asks first and forgets it', (tester) async {
      await useTallPhone(tester);
      final s = services(client: openRouterClient());
      await tester.runAsync(
          () => s.providers.saveKey(CodeProvider.openRouter, 'sk-remove-0001'));
      await tester.pumpWidget(
        MaterialApp(
          home: CodeProviderPage(
            services: s,
            provider: CodeProvider.openRouter,
          ),
        ),
      );
      await settle(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('code-key-remove')));
      await tester.tap(find.byKey(const ValueKey('code-key-remove')));
      await settle(tester);
      expect(find.text('Remove this key?'), findsOneWidget);
      await tester.tap(find.text('Remove key').last);
      await settleIo(tester);

      expect(s.providers.hasKey(CodeProvider.openRouter), isFalse);
      expect(secrets.values, isEmpty);
    });
  });

  group('CodeModelsPage', () {
    testWidgets('offers the on-device model and a way to add providers',
        (tester) async {
      await useTallPhone(tester);
      await tester.pumpWidget(
        MaterialApp(home: CodeModelsPage(services: services())),
      );
      await settle(tester);

      expect(find.text('FinnAI'), findsOneWidget);
      expect(find.text('Add a provider to use more models'), findsOneWidget);
    });

    testWidgets(
        'lists a provider’s models, searches them, and asks before '
        'the first cloud use', (tester) async {
      await useTallPhone(tester);
      final s = services(
        client: MockClient((request) async => http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'a/free:free',
                    'name': 'Free model',
                    'context_length': 8192,
                    'pricing': {'prompt': '0', 'completion': '0'},
                  },
                  {
                    'id': 'b/pro',
                    'name': 'Pro model',
                    'context_length': 128000,
                    'pricing': {'prompt': '0.000002', 'completion': '0.00001'},
                  },
                ],
              }),
              200,
            )),
      );
      await tester.runAsync(
          () => s.providers.saveKey(CodeProvider.openRouter, 'sk-1234'));
      await tester
          .runAsync(() => s.providers.refreshModels(CodeProvider.openRouter));
      await tester.pumpWidget(
        MaterialApp(home: CodeModelsPage(services: s)),
      );
      await settle(tester);

      expect(find.text('Free model'), findsOneWidget);
      expect(find.text('Pro model'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.textContaining('128K context'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('code-models-search')),
        'pro',
      );
      await settle(tester);
      expect(find.text('Free model'), findsNothing);
      expect(find.text('Pro model'), findsOneWidget);

      await tester.tap(find.text('Pro model'));
      await settle(tester);
      expect(find.text('Use OpenRouter?'), findsOneWidget);
      expect(find.textContaining('sent to OpenRouter'), findsOneWidget);
      // Declining changes nothing.
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(s.providers.active, CodeModelRef.local);

      await tester.tap(find.text('Pro model'));
      await settle(tester);
      await tester.tap(find.text('Use OpenRouter'));
      await settleIo(
        tester,
        until: () => s.providers.active.modelId == 'b/pro',
      );
      expect(s.providers.active.modelId, 'b/pro');
      expect(s.providers.settingsOf(CodeProvider.openRouter).acknowledgedCloud,
          isTrue);
    });
  });

  testWidgets('your own server is not described as the cloud', (tester) async {
    await useTallPhone(tester);
    final s = services(
      client: MockClient((request) async => http.Response(
            jsonEncode({
              'data': [
                {'id': 'llama3'},
              ],
            }),
            200,
          )),
    );
    await tester.runAsync(
      () => s.providers.setCustomBaseUrl('http://192.168.1.5:11434/v1'),
    );
    await tester.runAsync(() => s.providers.refreshModels(CodeProvider.custom));
    await tester.pumpWidget(MaterialApp(home: CodeModelsPage(services: s)));
    await settleIo(tester);

    await tester.tap(find.text('llama3'));
    await settle(tester);

    expect(find.text('Use this server?'), findsOneWidget);
    expect(find.textContaining('192.168.1.5:11434'), findsOneWidget);
    expect(find.textContaining('runs in the cloud'), findsNothing);
    expect(find.text('Use this server'), findsOneWidget);
  });

  group('CodeSettingsPage', () {
    testWidgets('lists its destinations with live status', (tester) async {
      await useTallPhone(tester);
      await tester.pumpWidget(
        MaterialApp(home: CodeSettingsPage(services: services())),
      );
      await settle(tester);

      for (final title in [
        'Providers',
        'Model',
        'Agent',
        'Project folders',
        'Privacy and data',
        'About FinnAI Code',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.text('FinnAI on this device'), findsOneWidget);
      expect(find.text('Auto-edit'), findsOneWidget);
    });
  });

  test('a session store used by the shell keeps its sessions apart from chat',
      () {
    // FinnAI Code never touches the conversation store: it has its own file.
    final store = CodeSessionStore(directoryProvider: () async => temp);
    final session = store.create(title: 'x');
    expect(store.byId(session.id), isNotNull);
    expect(const CodeAction.shell('ls').isShell, isTrue);
  });
}
