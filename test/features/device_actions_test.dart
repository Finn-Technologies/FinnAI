import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/src/features/actions/action_catalog.dart';
import 'package:finn_ai/src/features/actions/action_directive.dart';
import 'package:finn_ai/src/features/actions/action_matcher.dart';
import 'package:finn_ai/src/features/actions/action_parser.dart';
import 'package:finn_ai/src/features/actions/chat_device_actions.dart';
import 'package:finn_ai/src/features/actions/device_action.dart';
import 'package:finn_ai/src/features/actions/device_action_descriptions.dart';
import 'package:finn_ai/src/features/actions/device_action_executor.dart';
import 'package:finn_ai/src/features/actions/device_action_resolver.dart';
import 'package:finn_ai/src/features/actions/device_actions_controller.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';

class _RecordingExecutor implements DeviceActionExecutor {
  _RecordingExecutor({this.result = const DeviceActionResult.performed()});

  final DeviceActionResult result;
  final List<DeviceActionInvocation> calls = [];

  @override
  Future<DeviceActionResult> execute(DeviceActionInvocation invocation) async {
    calls.add(invocation);
    return result;
  }
}

class _GatedExecutor implements DeviceActionExecutor {
  _GatedExecutor(this.result);

  final Future<DeviceActionResult> result;

  @override
  Future<DeviceActionResult> execute(DeviceActionInvocation invocation) =>
      result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('DeviceActionCatalog', () {
    test('action names are unique', () {
      final names = DeviceActionCatalog.all.map((a) => a.name).toList();
      expect(names.toSet().length, names.length);
    });

    test('every action carries a prompt summary and a phrase', () {
      for (final action in DeviceActionCatalog.all) {
        expect(action.summary, isNotEmpty, reason: action.name);
        expect(action.phrases, isNotEmpty, reason: action.name);
      }
    });

    test('the open_settings summary lists every screen id', () {
      for (final screen in DeviceSettingsScreens.all) {
        expect(
          DeviceActionCatalog.openSettings.summary,
          contains(screen),
          reason: 'the prompt must offer $screen',
        );
      }
    });

    test('byName is case-insensitive and rejects unknown names', () {
      expect(DeviceActionCatalog.byName('SET_ALARM')?.name, 'set_alarm');
      expect(DeviceActionCatalog.byName('not_an_action'), isNull);
    });

    test('the language screen is its own id, separate from the keyboard', () {
      expect(
        DeviceSettingsScreens.all,
        contains(DeviceSettingsScreens.language),
      );
      expect(
        DeviceSettingsScreens.language,
        isNot(DeviceSettingsScreens.keyboard),
      );
      expect(
        DeviceActionCatalog.openSettings.summary,
        contains(DeviceSettingsScreens.language),
      );
    });
  });

  group('DeviceActionMatcher alarms', () {
    const matcher = DeviceActionMatcher();

    DeviceActionInvocation? match(String request) => matcher.match(request);

    test('reads a meridiem', () {
      final call = match('Set an alarm for 7am')!;
      expect(call.action.name, 'set_alarm');
      expect(call.intArgument('hour'), 7);
      expect(call.intArgument('minute'), 0);
    });

    test('reads an evening meridiem', () {
      final call = match('set an alarm for 7:30pm')!;
      expect(call.intArgument('hour'), 19);
      expect(call.intArgument('minute'), 30);
    });

    test('reads 24-hour time', () {
      final call = match('alarm at 19:45')!;
      expect(call.intArgument('hour'), 19);
      expect(call.intArgument('minute'), 45);
    });

    test('midnight and noon are not swapped', () {
      expect(match('set an alarm for 12am')!.intArgument('hour'), 0);
      expect(match('set an alarm for 12pm')!.intArgument('hour'), 12);
    });

    test('"wake me up" implies morning', () {
      final call = match('wake me up at 6')!;
      expect(call.intArgument('hour'), 6);
    });

    test('an alarm with no time is left to the model', () {
      expect(match('set an alarm'), isNull);
    });

    test('captures a quoted label', () {
      final call = match('set an alarm for 7am "standup"')!;
      expect(call.argument('label'), 'standup');
    });
  });

  group('DeviceActionMatcher timers', () {
    const matcher = DeviceActionMatcher();

    test('reads minutes', () {
      final call = matcher.match('start a 10 minute timer')!;
      expect(call.action.name, 'set_timer');
      expect(call.intArgument('seconds'), 600);
    });

    test('reads hours', () {
      expect(matcher.match('timer for 1 hour')!.intArgument('seconds'), 3600);
    });

    test('reads seconds', () {
      expect(
        matcher.match('set a timer for 90 seconds')!.intArgument('seconds'),
        90,
      );
    });

    test('adds compound durations', () {
      expect(
        matcher.match('timer for 1 hour 30 minutes')!.intArgument('seconds'),
        5400,
      );
    });

    test('a timer with no duration is left to the model', () {
      expect(matcher.match('set a timer'), isNull);
    });
  });

  group('DeviceActionMatcher settings screens', () {
    const matcher = DeviceActionMatcher();

    String? screen(String request) =>
        matcher.match(request)?.argument('screen');

    test('resolves the common radio settings', () {
      expect(screen('turn on wifi'), DeviceSettingsScreens.wifi);
      expect(
        screen('open bluetooth settings'),
        DeviceSettingsScreens.bluetooth,
      );
      expect(screen('airplane mode'), DeviceSettingsScreens.airplane);
      expect(screen('hotspot'), DeviceSettingsScreens.hotspot);
    });

    test('prefers the specific screen over the settings home', () {
      expect(screen('open wifi settings'), DeviceSettingsScreens.wifi);
      expect(screen('bluetooth settings'), DeviceSettingsScreens.bluetooth);
    });

    test('falls back to the settings home when nothing specific is named', () {
      expect(screen('open settings'), DeviceSettingsScreens.system);
    });

    test('prefers the longest alias', () {
      expect(screen('battery usage'), DeviceSettingsScreens.batteryUsage);
      expect(screen('battery saver'), DeviceSettingsScreens.batterySaver);
      expect(screen('mobile data'), DeviceSettingsScreens.mobileData);
    });

    test('a language request opens the locale screen, not the keyboard', () {
      final call = matcher.match('open the language settings')!;
      expect(call.action.name, 'open_settings');
      expect(call.argument('screen'), DeviceSettingsScreens.language);
      expect(call.argument('screen'), isNot(DeviceSettingsScreens.keyboard));

      expect(screen('change the language'), DeviceSettingsScreens.language);
    });

    test('every catalog screen id is reachable from the prompt contract', () {
      for (final id in DeviceSettingsScreens.all) {
        expect(
          DeviceActionCatalog.isValidSettingsScreen(id),
          isTrue,
          reason: id,
        );
      }
    });
  });

  group('DeviceActionMatcher other actions', () {
    const matcher = DeviceActionMatcher();

    test('torch on and off', () {
      final on = matcher.match('turn on the flashlight')!;
      expect(on.action.name, 'torch');
      expect(on.boolArgument('on'), isTrue);

      final off = matcher.match('turn off the flashlight')!;
      expect(off.boolArgument('on'), isFalse);
    });

    test('volume direction', () {
      expect(matcher.match('volume up')!.argument('direction'), 'up');
      expect(
        matcher.match('turn the volume down')!.argument('direction'),
        'down',
      );
    });

    test('media transport needs a media noun', () {
      expect(matcher.match('pause the music')!.argument('action'), 'pause');
      expect(matcher.match('next track')!.argument('action'), 'next');
      expect(matcher.match('pause'), isNull);
    });

    test('dials only a real number', () {
      final call = matcher.match('call 555 123 4567')!;
      expect(call.action.name, 'dial');
      expect(call.argument('number'), '5551234567');
      expect(matcher.match('call mom'), isNull);
    });

    test('navigation captures the destination', () {
      final call = matcher.match('navigate to the train station')!;
      expect(call.action.name, 'navigate');
      expect(call.argument('query'), 'the train station');
    });

    test('leaves unknown requests to the model', () {
      expect(matcher.match('what is the weather'), isNull);
      expect(matcher.match(''), isNull);
    });
  });

  group('DeviceActionMatcher regressions', () {
    const matcher = DeviceActionMatcher();

    test('compound number words collapse to one value', () {
      expect(
        matcher
            .match('start a forty five minute timer')!
            .intArgument('seconds'),
        2700,
      );
    });

    test('teens are not read as their prefix', () {
      expect(
        matcher.match('timer for sixteen minutes')!.intArgument('seconds'),
        960,
      );
      expect(
        matcher.match('timer for eighteen minutes')!.intArgument('seconds'),
        1080,
      );
    });

    test('an absurd digit run declines instead of overflowing', () {
      expect(
        matcher.match('set a timer for 99999999999999999999 minutes'),
        isNull,
      );
    });

    test('midnight is not rolled forward to noon', () {
      final matcher = DeviceActionMatcher(now: DateTime(2026, 1, 1, 23));
      final call = matcher.match('set an alarm for 0:30')!;
      expect(call.intArgument('hour'), 0);
      expect(call.intArgument('minute'), 30);
    });

    test('an unrelated "off" does not flip a torch-on request', () {
      expect(
        matcher
            .match('turn on the flashlight, the power is off')!
            .boolArgument('on'),
        isTrue,
      );
      expect(
        matcher.match('turn the flashlight off')!.boolArgument('on'),
        isFalse,
      );
    });

    test('the declared alarm-list phrases are matched without a model', () {
      expect(matcher.match('show my alarms')!.action.name, 'show_alarms');
      expect(matcher.match('list alarms')!.action.name, 'show_alarms');
    });

    test('a website address opens the browser, not an app', () {
      final call = matcher.match('open website example.com')!;
      expect(call.action.name, 'open_url');
      expect(call.argument('url'), 'example.com');
    });

    test('a plain app launch is still an app', () {
      expect(matcher.match('open spotify')!.action.name, 'open_app');
    });
  });

  group('DeviceActionDescriptions', () {
    Future<String> describeWith(WidgetTester tester, Locale locale) async {
      late String described;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              described = DeviceActionDescriptions.describe(
                context,
                const DeviceActionInvocation(
                  action: DeviceActionCatalog.openSettings,
                  arguments: {'screen': DeviceSettingsScreens.language},
                ),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return described;
    }

    testWidgets('names the language screen and not the keyboard', (
      tester,
    ) async {
      final english = await describeWith(tester, const Locale('en'));
      expect(english, contains('Language'));
      expect(english, isNot(contains('Keyboard')));

      final german = await describeWith(tester, const Locale('de'));
      expect(german, contains('Sprache'));
      expect(german, isNot(contains('Tastatur')));
    });
  });

  group('DeviceActionParser', () {
    const parser = DeviceActionParser();

    test('reads a tool call', () {
      final call = parser.parse(
        '<tool_call>{"name": "set_alarm", "arguments": {"hour": 7, '
        '"minute": 15}}</tool_call>',
      )!;
      expect(call.action.name, 'set_alarm');
      expect(call.intArgument('hour'), 7);
      expect(call.intArgument('minute'), 15);
    });

    test('reads a bare JSON object', () {
      final call = parser.parse(
        '{"name": "set_timer", "arguments": {"seconds": 300}}',
      )!;
      expect(call.intArgument('seconds'), 300);
    });

    test('requires the required arguments', () {
      expect(parser.parse('{"name": "set_alarm", "arguments": {}}'), isNull);
    });

    test('rejects an out-of-range hour', () {
      expect(
        parser.parse('{"name": "set_alarm", "arguments": {"hour": 25}}'),
        isNull,
      );
    });

    test('rejects an unknown action name', () {
      expect(
        parser.parse('{"name": "launch_missiles", "arguments": {}}'),
        isNull,
      );
    });

    test('normalizes a loosely named settings screen', () {
      final call = parser.parse(
        '{"name": "open_settings", "arguments": {"screen": "Wi-Fi"}}',
      )!;
      expect(call.argument('screen'), DeviceSettingsScreens.wifi);
    });

    test('rejects an unmappable settings screen', () {
      expect(
        parser.parse(
          '{"name": "open_settings", "arguments": {"screen": "nonsense"}}',
        ),
        isNull,
      );
    });

    test('accepts a boolean written as a word', () {
      final call = parser.parse(
        '{"name": "torch", "arguments": {"on": "off"}}',
      )!;
      expect(call.boolArgument('on'), isFalse);
    });

    test('returns null on unparseable output', () {
      expect(parser.parse('NONE'), isNull);
      expect(parser.parse(''), isNull);
      expect(parser.parse('{not json'), isNull);
    });

    test('degrades instead of throwing on non-finite numbers', () {
      for (final raw in [
        '{"name": "set_timer", "arguments": {"seconds": "NaN"}}',
        '{"name": "set_timer", "arguments": {"seconds": "Infinity"}}',
        '{"name": "set_timer", "arguments": {"seconds": "1e999"}}',
        '{"name": "set_alarm", "arguments": {"hour": "Infinity", "minute": 0}}',
      ]) {
        expect(parser.parse(raw), isNull, reason: raw);
      }
    });

    test('never throws on hostile or malformed output', () {
      for (final raw in [
        '<tool_call>{"name": "set_alarm"</tool_call>',
        '<tool_call></tool_call>',
        '{"name": "torch", "arguments": {"on": {}}}',
        '{"name": ["set_alarm"], "arguments": {}}',
        '{"name": "set_alarm", "arguments": "hour=7"}',
        'null',
        '{}',
      ]) {
        expect(parser.parse(raw), isNull, reason: raw);
      }
    });

    test('accepts every canonical screen id the directive advertises', () {
      for (final id in DeviceSettingsScreens.all) {
        final call = parser.parse(
          '{"name": "open_settings", "arguments": {"screen": "$id"}}',
        );
        expect(call?.argument('screen'), id, reason: id);
      }
    });

    test('a decimal hour is still truncated, not rejected', () {
      final call = parser.parse(
        '{"name": "set_alarm", "arguments": {"hour": 7.0, "minute": 15}}',
      )!;
      expect(call.intArgument('hour'), 7);
    });
  });

  group('DeviceActionResolver', () {
    test('resolves without a model when the matcher is confident', () async {
      var asked = false;
      final resolver = DeviceActionResolver(
        modelQuery: (_) async {
          asked = true;
          return 'NONE';
        },
      );
      final call = await resolver.resolve('set an alarm for 7am');
      expect(call?.action.name, 'set_alarm');
      expect(
        asked,
        isFalse,
        reason: 'the model must not run for a settled request',
      );
    });

    test('falls back to the model for an unusual phrasing', () async {
      final resolver = DeviceActionResolver(
        modelQuery: (_) async =>
            '<tool_call>{"name": "set_alarm", "arguments": {"hour": 6, '
            '"minute": 45}}</tool_call>',
      );
      final call = await resolver.resolve('I would like to be up before seven');
      expect(call?.intArgument('hour'), 6);
    });

    test(
      'returns null when there is no model and the matcher declines',
      () async {
        const resolver = DeviceActionResolver();
        expect(await resolver.resolve('what is the weather'), isNull);
      },
    );

    test(
      'a model failure degrades to unresolved instead of escaping',
      () async {
        final resolver = DeviceActionResolver(
          modelQuery: (_) async => throw StateError('model blew up'),
        );
        expect(await resolver.resolve('what is the weather'), isNull);
      },
    );

    test('unparseable model output degrades to unresolved', () async {
      final resolver = DeviceActionResolver(
        modelQuery: (_) async => 'I think you should use the alarm app.',
      );
      expect(await resolver.resolve('what is the weather'), isNull);
    });

    test('sends the catalog contract with the request', () async {
      String? seen;
      final resolver = DeviceActionResolver(
        modelQuery: (prompt) async {
          seen = prompt;
          return 'NONE';
        },
      );
      await resolver.resolve('do the thing');
      expect(seen, contains('set_alarm'));
      expect(seen, contains('do the thing'));
    });
  });

  group('DeviceActionsController', () {
    test('resolving a known request waits for confirmation', () async {
      final executor = _RecordingExecutor();
      final controller = DeviceActionsController(executor: executor);

      await controller.submit('set an alarm for 7am');
      expect(controller.flow, DeviceActionFlow.confirming);
      expect(executor.calls, isEmpty, reason: 'nothing runs before confirm');

      await controller.confirm();
      expect(controller.flow, DeviceActionFlow.done);
      expect(executor.calls.single.action.name, 'set_alarm');
    });

    test('cancelling never reaches the executor', () async {
      final executor = _RecordingExecutor();
      final controller = DeviceActionsController(executor: executor);

      await controller.submit('set an alarm for 7am');
      controller.cancel();

      expect(controller.invocation, isNull);
      expect(controller.flow, DeviceActionFlow.idle);
      expect(executor.calls, isEmpty);
    });

    test('opening a screen also waits for an explicit confirmation', () async {
      final executor = _RecordingExecutor(
        result: const DeviceActionResult.opened(detail: 'wifi'),
      );
      final controller = DeviceActionsController(executor: executor);

      await controller.submit('turn on wifi');

      expect(controller.flow, DeviceActionFlow.confirming);
      expect(
        executor.calls,
        isEmpty,
        reason: 'leaving the app is not free of consequences',
      );

      await controller.confirm();
      expect(controller.flow, DeviceActionFlow.done);
      expect(executor.calls.single.argument('screen'), 'wifi');
    });

    test('no catalog action is exempt from confirmation', () {
      for (final action in DeviceActionCatalog.all) {
        expect(
          ChatDeviceActions.runsWithoutAsking(
            DeviceActionInvocation(action: action),
          ),
          isFalse,
          reason: action.name,
        );
      }
    });

    test('a second request cannot discard a pending confirmation', () async {
      final executor = _RecordingExecutor();
      final controller = DeviceActionsController(executor: executor);

      await controller.submit('set an alarm for 7am');
      await controller.submit('start a 10 minute timer');

      expect(controller.flow, DeviceActionFlow.confirming);
      expect(controller.invocation!.action.name, 'set_alarm');
      expect(executor.calls, isEmpty);
    });

    test('state changes always wait for confirmation', () async {
      for (final request in [
        'set an alarm for 7am',
        'start a 10 minute timer',
        'turn the flashlight off',
      ]) {
        final executor = _RecordingExecutor();
        final controller = DeviceActionsController(executor: executor);
        await controller.submit(request);
        expect(
          controller.flow,
          DeviceActionFlow.confirming,
          reason: '$request must not run unattended',
        );
        expect(executor.calls, isEmpty, reason: request);
      }
    });

    test('an unresolved request reports rather than guessing', () async {
      final executor = _RecordingExecutor();
      final controller = DeviceActionsController(executor: executor);

      await controller.submit('what is the weather');

      expect(controller.error, 'unresolved');
      expect(controller.invocation, isNull);
      expect(executor.calls, isEmpty);
    });

    test('a platform failure surfaces as a failed result', () async {
      final controller = DeviceActionsController(
        executor: _RecordingExecutor(
          result: const DeviceActionResult.failed(error: 'nope'),
        ),
      );

      await controller.submit('set an alarm for 7am');
      await controller.confirm();

      expect(controller.result?.outcome, DeviceActionOutcome.failed);
      expect(controller.result?.error, 'nope');
    });

    test('confirm is inert when nothing is pending', () async {
      final executor = _RecordingExecutor();
      final controller = DeviceActionsController(executor: executor);
      await controller.confirm();
      expect(executor.calls, isEmpty);
    });

    test('does not notify after dispose while resolving', () async {
      final gate = Completer<String>();
      final controller = DeviceActionsController(
        resolver: DeviceActionResolver(modelQuery: (_) => gate.future),
      );

      final pending = controller.submit('what is the weather');
      controller.dispose();
      gate.complete('NONE');

      await expectLater(pending, completes);
    });

    test('does not notify after dispose while running', () async {
      final gate = Completer<DeviceActionResult>();
      final controller = DeviceActionsController(
        executor: _GatedExecutor(gate.future),
      );

      await controller.submit('set an alarm for 7am');
      final running = controller.confirm();
      controller.dispose();
      gate.complete(const DeviceActionResult.performed());

      await expectLater(running, completes);
    });
  });

  group('ChatDeviceActions', () {
    const chat = ChatDeviceActions();

    test('recognises a device command from a chat message', () async {
      final call = await chat.resolve('set an alarm for 7am please');
      expect(call?.action.name, 'set_alarm');
    });

    test('leaves an ordinary question to the model', () async {
      expect(await chat.resolve('what is the capital of Portugal'), isNull);
    });

    test('never runs anything unattended, navigation included', () {
      expect(
        ChatDeviceActions.runsWithoutAsking(
          DeviceActionInvocation(
            action: DeviceActionCatalog.openSettings,
            arguments: const {'screen': 'wifi'},
          ),
        ),
        isFalse,
      );
      expect(
        ChatDeviceActions.runsWithoutAsking(
          const DeviceActionInvocation(action: DeviceActionCatalog.torch),
        ),
        isFalse,
      );
    });
  });

  group('PlatformDeviceActionExecutor', () {
    const channel = MethodChannel('finn_ai/device_actions');
    const executor = PlatformDeviceActionExecutor();
    const invocation = DeviceActionInvocation(
      action: DeviceActionCatalog.torch,
      arguments: {'on': true},
    );

    void stub(Future<Object?>? Function(MethodCall call)? handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, handler);
    }

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('passes the action name and arguments through', () async {
      Map<Object?, Object?>? seen;
      stub((call) async {
        seen = call.arguments as Map<Object?, Object?>;
        return {'outcome': 'performed', 'detail': 'torch'};
      });

      final result = await executor.execute(invocation);

      expect(result.outcome, DeviceActionOutcome.performed);
      expect(result.detail, 'torch');
      expect(seen!['name'], 'torch');
      expect((seen!['arguments'] as Map)['on'], isTrue);
    });

    test('maps a platform exception to a failed result', () async {
      stub(
        (call) async => throw PlatformException(code: 'boom', message: 'nope'),
      );

      final result = await executor.execute(invocation);

      expect(result.outcome, DeviceActionOutcome.failed);
      expect(result.error, 'nope');
    });

    test('an unhandled channel reports unavailable', () async {
      stub(null);
      final result = await executor.execute(invocation);
      expect(result.outcome, DeviceActionOutcome.unavailable);
    });

    test(
      'an unrecognised outcome is a failure, not a silent success',
      () async {
        stub((call) async => {'outcome': 'something-else'});
        final result = await executor.execute(invocation);
        expect(result.outcome, DeviceActionOutcome.failed);
      },
    );

    test('a non-map reply reports unavailable', () async {
      stub((call) async => 'ok');
      final result = await executor.execute(invocation);
      expect(result.outcome, DeviceActionOutcome.unavailable);
    });
  });

  group('pending action persistence', () {
    test('survives a JSON round trip', () {
      const invocation = DeviceActionInvocation(
        action: DeviceActionCatalog.openSettings,
        arguments: {'screen': 'wifi'},
      );
      final restored = DeviceActionInvocation.fromJson(invocation.toJson());

      expect(restored?.action.name, 'open_settings');
      expect(restored?.argument('screen'), 'wifi');
    });

    test('a message keeps its pending action through copyWith', () {
      final message = ConversationMessage(
        id: 'm1',
        role: ConversationRole.assistant,
        text: 'Open Wi-Fi settings',
        createdAt: DateTime(2026),
        pendingAction: const DeviceActionInvocation(
          action: DeviceActionCatalog.torch,
          arguments: {'on': true},
        ),
      );

      expect(message.copyWith(text: 'x').pendingAction, isNotNull);
      expect(message.copyWith(clearPendingAction: true).pendingAction, isNull);
    });

    test('drops an action the catalog no longer has', () {
      expect(
        DeviceActionInvocation.fromJson(<String, Object?>{
          'name': 'launch_missiles',
          'arguments': <String, Object?>{},
        }),
        isNull,
      );
      expect(DeviceActionInvocation.fromJson(null), isNull);
    });
  });

  group('NoopDeviceActionExecutor', () {
    test('reports unavailable rather than throwing', () async {
      const executor = NoopDeviceActionExecutor();
      final result = await executor.execute(
        const DeviceActionInvocation(action: DeviceActionCatalog.torch),
      );
      expect(result.outcome, DeviceActionOutcome.unavailable);
      expect(result.isSuccess, isFalse);
    });
  });

  group('DeviceActionDirective', () {
    test('names every action so the model can only pick a real one', () {
      final directive = DeviceActionDirective.build();
      for (final action in DeviceActionCatalog.all) {
        expect(directive, contains(action.name));
      }
    });

    test('stays inside a small-model token budget', () {
      expect(DeviceActionDirective.build().length, lessThan(2400));
    });
  });
}
