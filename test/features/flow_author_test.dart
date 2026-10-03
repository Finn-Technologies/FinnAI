import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/flows/flow_author.dart';
import 'package:finn_ai/src/features/flows/flow_phrases.dart';
import 'package:finn_ai/src/features/flows/flow_script.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';

void main() {
  group('triggers in plain English', () {
    FlowTrigger? trigger(String text) => FlowPhrases.findTrigger(text)?.trigger;

    test('the charger', () {
      for (final text in [
        'when I plug in my charger turn on the flashlight',
        'whenever my phone starts charging',
        'when the charger is connected',
        'as soon as I plug my phone in',
      ]) {
        expect(trigger(text)?.kind, FlowTriggerKind.chargerConnected,
            reason: text);
      }
      for (final text in [
        'when I unplug my phone',
        'when the charger is disconnected',
        'when it stops charging',
      ]) {
        expect(trigger(text)?.kind, FlowTriggerKind.chargerDisconnected,
            reason: text);
      }
    });

    test('battery low, with and without a number', () {
      expect(trigger('when the battery is low')!.level, 20);
      expect(trigger('when my battery drops below 15%')!.level, 15);
      expect(trigger('when battery reaches 10 percent')!.level, 10);
      expect(trigger('low battery')!.kind, FlowTriggerKind.batteryLow);
    });

    test('headphones, Wi-Fi, airplane mode, boot, unlock', () {
      expect(trigger('when I connect my headphones')!.kind,
          FlowTriggerKind.headsetConnected);
      expect(trigger('when I unplug my earbuds')!.kind,
          FlowTriggerKind.headsetDisconnected);
      expect(trigger('when I connect to wifi')!.kind,
          FlowTriggerKind.wifiConnected);
      expect(trigger('when I leave the wi-fi')!.kind,
          FlowTriggerKind.wifiDisconnected);
      expect(trigger('when airplane mode is turned on')!.kind,
          FlowTriggerKind.airplaneOn);
      expect(trigger('when my phone restarts')!.kind,
          FlowTriggerKind.deviceBooted);
      expect(trigger('when I unlock my phone')!.kind,
          FlowTriggerKind.screenUnlocked);
    });

    test('"turn on" is not a boot trigger', () {
      expect(trigger('turn on the flashlight'), isNull);
    });

    test('times of day', () {
      expect(trigger('every day at 7:30'), const FlowTrigger.daily(7, 30));
      expect(trigger('every morning'), const FlowTrigger.daily(7, 30));
      expect(trigger('every evening'), const FlowTrigger.daily(18, 0));
      expect(trigger('daily at 9pm'), const FlowTrigger.daily(21, 0));
      expect(trigger('every day at 12am'), const FlowTrigger.daily(0, 0));
      expect(
        trigger('on weekdays at 8:15'),
        const FlowTrigger.weekly(8, 15, {1, 2, 3, 4, 5}),
      );
      expect(
        trigger('every monday and friday at 6pm'),
        const FlowTrigger.weekly(18, 0, {1, 5}),
      );
    });

    test('a bare number is not a time', () {
      expect(trigger('buy 2 apples'), isNull);
      expect(trigger('at 2 in the park'), isNull);
    });

    test('intervals', () {
      expect(trigger('every 30 minutes'), const FlowTrigger.every(30));
      expect(trigger('every 2 hours'), const FlowTrigger.every(120));
      expect(trigger('hourly'), const FlowTrigger.every(60));
      expect(trigger('every 5 minutes'), const FlowTrigger.every(15),
          reason: 'raised to what the platform can do');
    });

    test('what is left is what to do', () {
      final found = FlowPhrases.findTrigger(
        'when I plug in my charger, turn on the flashlight',
      )!;
      expect(found.rest, 'turn on the flashlight');
    });
  });

  group('conditions in plain English', () {
    List<FlowCondition> conditions(String text) =>
        FlowPhrases.findConditions(text).conditions;

    test('battery, charging, time window, days', () {
      expect(conditions('only if battery is below 30%'),
          [const FlowCondition.batteryBelow(30)]);
      expect(conditions('only when charging').single.kind,
          FlowConditionKind.charging);
      expect(conditions('only when not charging').single.kind,
          FlowConditionKind.notCharging);
      expect(conditions('between 9am and 5pm'),
          [const FlowCondition.timeBetween(9 * 60, 17 * 60)]);
      expect(conditions('only on weekdays').single.days, {1, 2, 3, 4, 5});
    });

    test('nothing is invented from a sentence without one', () {
      expect(conditions('turn on the flashlight'), isEmpty);
    });
  });

  group('a sentence becomes a flow', () {
    FlowDraft? build(String text) =>
        FlowAuthor.fromSentence(text, id: 'f', now: DateTime(2026, 10, 2));

    test('charger then flashlight', () {
      final draft = build('when I plug in my charger, turn on the flashlight')!;
      final flow = draft.flow;
      expect(flow.triggers.single.kind, FlowTriggerKind.chargerConnected);
      expect(flow.blocks.single.kind, FlowBlockKind.action);
      expect(flow.blocks.single.actionName, 'torch');
      expect(flow.blocks.single.arguments['on'], 'true');
      expect(FlowsStore.validate(flow).isValid, isTrue);
      expect(flow.granted, isFalse, reason: 'permission is never inferred');
      expect(flow.enabled, isFalse);
    });

    test('a battery reminder with a condition', () {
      final flow = build(
        'when the battery is below 15% remind me to charge, only on weekdays',
      )!
          .flow;
      expect(flow.triggers.single, const FlowTrigger.batteryLow(15));
      expect(flow.blocks.single.kind, FlowBlockKind.notify);
      expect(flow.blocks.single.text, 'Charge');
      expect(flow.conditions.single.kind, FlowConditionKind.weekdays);
    });

    test('two things to do, in order', () {
      final flow = build(
        'when I connect my headphones, turn the volume down and play music',
      )!
          .flow;
      expect(flow.blocks.map((b) => b.actionName), ['volume', 'media']);
    });

    test('a news brief at a time uses the template', () {
      final flow = build('every morning at 7 give me the football news')!.flow;
      expect(flow.blocks.first.kind, FlowBlockKind.web);
      expect(flow.blocks.first.text, contains('football'));
      expect(flow.blocks.first.text, isNot(contains('give me')));
      expect(flow.triggers.single, const FlowTrigger.daily(7, 0));
      expect(flow.blocks.last.kind, FlowBlockKind.saveToChat);
    });

    test('"tell me a fun fact" asks the model, "remind me" does not', () {
      final ask = build('when I plug in my charger tell me a fun fact')!.flow;
      expect(ask.blocks.map((b) => b.kind), [
        FlowBlockKind.ask,
        FlowBlockKind.notify,
        FlowBlockKind.saveToChat,
      ]);
      final note = build('when I unlock my phone remind me to stretch')!.flow;
      expect(note.blocks.single.kind, FlowBlockKind.notify);
      expect(note.blocks.single.text, 'Stretch');
    });

    test('speak', () {
      final flow = build('when I plug in my charger say good morning')!.flow;
      expect(flow.blocks.single.kind, FlowBlockKind.speak);
      expect(flow.blocks.single.text, 'good morning');
    });

    test('a sentence with no action builds nothing', () {
      expect(build('when I plug in my charger'), isNull);
      expect(build('the weather is nice'), isNull);
      expect(build('   '), isNull);
    });

    test('what was not understood is reported, not silently dropped', () {
      final draft = build(
        'when I plug in my charger turn on the flashlight and frobnicate the widgets',
      )!;
      expect(draft.flow.blocks, hasLength(1));
      expect(draft.notUnderstood, ['frobnicate the widgets']);
    });

    test('a name is made from what it does', () {
      final flow =
          build('when I plug in my charger turn on the flashlight')!.flow;
      expect(flow.name, 'Turn on the flashlight');
    });
  });

  group('the script the model writes', () {
    test('the example in the prompt parses to what it describes', () {
      final draft = FlowAuthor.fromScript(
        '''
name: Flashlight on charge
when: charger connected
only if: battery below 30
do: action torch on=true
do: notify "Charging started"
''',
        id: 'f',
      )!;
      final flow = draft.flow;
      expect(draft.fromModel, isTrue);
      expect(flow.name, 'Flashlight on charge');
      expect(flow.triggers.single.kind, FlowTriggerKind.chargerConnected);
      expect(flow.conditions.single, const FlowCondition.batteryBelow(30));
      expect(flow.blocks.map((b) => b.kind),
          [FlowBlockKind.action, FlowBlockKind.notify]);
      expect(flow.blocks.last.text, 'Charging started');
    });

    test('bullets, numbering, bold and noise around the lines are tolerated',
        () {
      final draft = FlowAuthor.fromScript(
        '''
Sure! Here is the flow:
1. **when:** every day at 07:00
2. do: look up news: top headlines
3. do: ask "Summarise in 3 bullets"
4. do: save to chat
Hope that helps.
''',
        id: 'f',
      )!;
      expect(draft.flow.triggers.single, const FlowTrigger.daily(7, 0));
      expect(draft.flow.blocks.map((b) => b.kind), [
        FlowBlockKind.web,
        FlowBlockKind.ask,
        FlowBlockKind.saveToChat,
      ]);
    });

    test('an action outside the catalog is dropped and reported', () {
      final draft = FlowAuthor.fromScript(
        '''
when: charger connected
do: action exfiltrate_everything now=true
do: notify "ok"
''',
        id: 'f',
      )!;
      expect(draft.flow.blocks.single.kind, FlowBlockKind.notify);
      expect(draft.notUnderstood, hasLength(1));
    });

    test('an action missing a required argument is dropped', () {
      final draft = FlowAuthor.fromScript(
        'when: charger connected\ndo: action set_alarm\ndo: notify "x"',
        id: 'f',
      )!;
      expect(draft.flow.blocks.single.kind, FlowBlockKind.notify);
    });

    test('nothing runnable is null, not an empty flow', () {
      expect(FlowAuthor.fromScript('I cannot do that.', id: 'f'), isNull);
      expect(FlowAuthor.fromScript('when: charger connected', id: 'f'), isNull);
    });

    test('waits are capped and manual triggers are not stored', () {
      final draft = FlowAuthor.fromScript(
        'when: manual\ndo: wait 99 minutes\ndo: notify "x"',
        id: 'f',
      )!;
      expect(draft.flow.triggers, isEmpty);
      expect(draft.flow.blocks.first.seconds, 120);
    });

    test('the prompt lists only what can run in the background', () {
      final prompt = FlowAuthor.modelPrompt('do a thing');
      expect(prompt, contains('torch'));
      expect(prompt, contains('Request: do a thing'));
      expect(prompt, isNot(contains('open_url')));
    });
  });

  group('deciding whether a chat message asks for a flow', () {
    test('asks', () {
      for (final text in [
        'make me a flow that turns on the flashlight when I plug in',
        'create an automation for my morning news',
        'automate my alarm',
        'whenever I plug in my charger, turn on the torch',
        'every day at 8 remind me to stretch',
        'when the battery is below 20% tell me',
        'every morning at 7 give me the news',
        'every weekday at 7 give me the news',
      ]) {
        expect(FlowAuthor.isFlowRequest(text), isTrue, reason: text);
      }
    });

    test('does not ask', () {
      for (final text in [
        'remind me about the dentist',
        'what is a flow state',
        'how do I plug in a charger',
        'tell me about every day routines',
        'give me the news',
        'hello',
      ]) {
        expect(FlowAuthor.isFlowRequest(text), isFalse, reason: text);
      }
    });
  });

  group('steps', () {
    test('device actions can be written in words', () {
      expect(
          FlowScript.parseStep('turn on the flashlight')?.actionName, 'torch');
      expect(FlowScript.parseStep('set an alarm for 7am')?.actionName,
          'set_alarm');
    });

    test('quotes are removed and long text is clipped', () {
      expect(FlowScript.parseStep('notify "Hello there"')?.text, 'Hello there');
      expect(
        FlowScript.parseStep('ask ${'x' * 2000}')!.text.length,
        FlowBlock.maxTextLength,
      );
    });
  });
}
