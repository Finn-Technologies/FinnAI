import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/flows/flow_edit.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';

void main() {
  group('blocks', () {
    test('every kind survives a JSON round trip', () {
      const blocks = [
        FlowBlock.ask('Write {input}'),
        FlowBlock.web('news: football'),
        FlowBlock.notify('Hi', title: 'Title'),
        FlowBlock.speak('Hello'),
        FlowBlock.action('torch', {'on': 'true'}),
        FlowBlock.wait(9),
        FlowBlock.branch(
          FlowCondition.batteryBelow(20),
          then: [FlowBlock.notify('low')],
          otherwise: [FlowBlock.stop()],
        ),
        FlowBlock.saveToChat(),
        FlowBlock.stop(),
      ];
      for (final block in blocks) {
        expect(FlowBlock.fromJson(block.toJson()), block, reason: '$block');
      }
    });

    test('a kind this version does not know is dropped, not guessed', () {
      expect(FlowBlock.fromJson({'kind': 'teleport'}), isNull);
      expect(
        FlowBlock.listFromJson([
          {'kind': 'notify', 'text': 'a'},
          {'kind': 'teleport'},
          'junk',
        ]),
        hasLength(1),
      );
    });

    test('text is clipped and a wait is capped', () {
      final block = FlowBlock.fromJson({
        'kind': 'wait',
        'seconds': 99999,
        'text': 'x' * 5000,
      })!;
      expect(block.seconds, FlowBlock.maxWaitSeconds);
      expect(block.text.length, FlowBlock.maxTextLength);
    });

    test('branches nested past the limit are cut off', () {
      Map<String, Object?> branch(Object? inner) => {
            'kind': 'branch',
            'if': {'kind': 'charging'},
            'then': [if (inner != null) inner],
          };
      final deep = branch(branch(branch(branch(null))));
      final parsed = FlowBlock.fromJson(deep)!;
      expect(parsed.depth, lessThanOrEqualTo(FlowBlock.maxDepth));
    });

    test('flatten walks both lanes in order', () {
      const block = FlowBlock.branch(
        FlowCondition(FlowConditionKind.charging),
        then: [FlowBlock.notify('a')],
        otherwise: [FlowBlock.notify('b')],
      );
      expect(block.flatten().map((b) => b.text), ['', 'a', 'b']);
      expect(block.size, 3);
    });

    test('the old step names still read', () {
      expect(FlowBlockKind.fromName('prompt'), FlowBlockKind.ask);
      expect(FlowBlockKind.fromName('browse'), FlowBlockKind.web);
      expect(FlowBlockKind.fromName('deviceAction'), FlowBlockKind.action);
    });
  });

  group('conditions', () {
    final env = FlowEnvironmentSnapshot(
      now: DateTime(2026, 10, 2, 23, 30), // a Friday
      batteryPercent: 25,
      charging: true,
      wifiConnected: true,
    );

    test('battery', () {
      expect(const FlowCondition.batteryBelow(30).holds(env), isTrue);
      expect(const FlowCondition.batteryBelow(25).holds(env), isFalse);
      expect(const FlowCondition.batteryAbove(20).holds(env), isTrue);
    });

    test('charger, Wi-Fi, headset, airplane', () {
      expect(
          const FlowCondition(FlowConditionKind.charging).holds(env), isTrue);
      expect(
        const FlowCondition(FlowConditionKind.notCharging).holds(env),
        isFalse,
      );
      expect(
        const FlowCondition(FlowConditionKind.wifiConnected).holds(env),
        isTrue,
      );
      expect(
        const FlowCondition(FlowConditionKind.headsetConnected).holds(env),
        isFalse,
      );
      expect(
        const FlowCondition(FlowConditionKind.airplaneOff).holds(env),
        isTrue,
      );
    });

    test('a time window may cross midnight', () {
      const night = FlowCondition.timeBetween(22 * 60, 6 * 60);
      expect(night.holds(env), isTrue);
      expect(
        night.holds(
          FlowEnvironmentSnapshot(now: DateTime(2026, 10, 2, 12)),
        ),
        isFalse,
      );
      const day = FlowCondition.timeBetween(9 * 60, 17 * 60);
      expect(day.holds(env), isFalse);
    });

    test('days of the week', () {
      expect(FlowCondition.weekdays(const {1, 2, 3, 4, 5}).holds(env), isTrue);
      expect(FlowCondition.weekdays(const {6, 7}).holds(env), isFalse);
    });

    test('the answer check is case-insensitive and never true when empty', () {
      expect(
        const FlowCondition.answerContains('rain').holds(env, answer: 'Rain!'),
        isTrue,
      );
      expect(
        const FlowCondition.answerContains('').holds(env, answer: 'anything'),
        isFalse,
      );
    });

    test('values out of range are invalid, and clamped when read back', () {
      expect(const FlowCondition.batteryBelow(150).isValid, isFalse);
      expect(const FlowCondition.timeBetween(2000, 5).isValid, isFalse);
      final read =
          FlowCondition.fromJson({'kind': 'batteryBelow', 'value': 500});
      expect(read!.value, 100);
    });

    test('round trip', () {
      for (final c in const [
        FlowCondition.batteryBelow(30),
        FlowCondition.timeBetween(60, 120),
        FlowCondition.weekdays({1, 3}),
        FlowCondition.answerContains('x'),
        FlowCondition(FlowConditionKind.charging),
      ]) {
        expect(FlowCondition.fromJson(c.toJson()), c);
      }
    });
  });

  group('triggers', () {
    test('every kind round trips', () {
      for (final kind in FlowTriggerKind.values) {
        if (kind == FlowTriggerKind.manual) continue;
        final trigger = switch (kind) {
          FlowTriggerKind.timeOfDay => const FlowTrigger.weekly(7, 5, {1, 3}),
          FlowTriggerKind.interval => const FlowTrigger.every(45),
          FlowTriggerKind.batteryLow => const FlowTrigger.batteryLow(12),
          _ => FlowTrigger.event(kind),
        };
        expect(FlowTrigger.fromJson(trigger.toJson()), trigger,
            reason: '$kind');
      }
    });

    test('an interval below the platform minimum is raised to it', () {
      final t = FlowTrigger.fromJson({'kind': 'interval', 'every': 1})!;
      expect(t.intervalMinutes, FlowTrigger.minInterval);
    });

    test('a daily time with all seven days saves as daily', () {
      final t = FlowTrigger.fromJson({
        'kind': 'timeOfDay',
        'hour': 8,
        'minute': 0,
        'days': [1, 2, 3, 4, 5, 6, 7],
      })!;
      expect(t.daysOfWeek, isEmpty);
    });

    test('events are the ones the service listens for', () {
      expect(FlowTriggerKind.chargerConnected.isEvent, isTrue);
      expect(FlowTriggerKind.timeOfDay.isEvent, isFalse);
      expect(FlowTriggerKind.interval.isScheduled, isTrue);
      expect(FlowTriggerKind.manual.isEvent, isFalse);
    });

    test('a manual trigger is never stored in a flow', () {
      expect(
        FlowTrigger.listFromJson([
          {'kind': 'manual'},
          {'kind': 'chargerConnected'},
        ]),
        hasLength(1),
      );
    });
  });

  group('the document', () {
    test('a v2 flow becomes blocks, and keeps delivering its answer', () {
      final v2 = jsonEncode({
        'version': 2,
        'flows': [
          {
            'id': 'custom-1',
            'name': 'Morning brief',
            'description': '',
            'instructions': '',
            'category': 'Automation',
            'enabled': true,
            'trigger': {'kind': 'timeOfDay', 'hour': 7, 'minute': 30},
            'granted': true,
            'steps': [
              {'kind': 'browse', 'text': 'news: x'},
              {'kind': 'prompt', 'text': 'Summarise'},
              {'kind': 'notify', 'text': ''},
              {
                'kind': 'deviceAction',
                'text': 'Torch',
                'action': 'torch',
                'args': {'on': 'true'},
              },
            ],
          },
        ],
      });

      final flow = FlowCodec.decode(v2).flows.single;

      expect(flow.blocks.map((b) => b.kind), [
        FlowBlockKind.web,
        FlowBlockKind.ask,
        FlowBlockKind.notify,
        FlowBlockKind.action,
        // Version 2 wrote the answer to a chat on its own; now it is a block.
        FlowBlockKind.saveToChat,
      ]);
      expect(flow.triggers.single, const FlowTrigger.daily(7, 30));
      expect(flow.granted, isTrue);
      expect(flow.enabled, isTrue);
    });

    test('a v2 flow with no prompt does not gain a save block', () {
      final flow = FlowCodec.decode(jsonEncode({
        'version': 2,
        'flows': [
          {
            'id': 'x',
            'name': 'n',
            'steps': [
              {'kind': 'notify', 'text': 'hi'},
            ],
          },
        ],
      })).flows.single;
      expect(flow.blocks.map((b) => b.kind), [FlowBlockKind.notify]);
    });

    test('a v1 flow is a guide: instructions, no blocks', () {
      final flow = FlowCodec.decode(jsonEncode({
        'version': 1,
        'flows': [
          {
            'id': 'g',
            'name': 'Guide',
            'description': 'd',
            'instructions': 'Be brief.',
            'category': 'Custom',
            'enabled': true,
          },
        ],
      })).flows.single;
      expect(flow.isAutomation, isFalse);
      expect(flow.instructions, 'Be brief.');
      expect(flow.promptLines, ['Be brief.']);
    });

    test('a v3 document round trips', () {
      const flow = FinnFlow(
        id: 'f',
        name: 'N',
        description: 'd',
        instructions: '',
        category: 'Automation',
        enabled: true,
        granted: true,
        blocks: [
          FlowBlock.branch(
            FlowCondition.batteryBelow(30),
            then: [FlowBlock.notify('low')],
          ),
        ],
        triggers: [FlowTrigger.batteryLow(15), FlowTrigger.every(30)],
        conditions: [FlowCondition(FlowConditionKind.notCharging)],
      );
      final again = FlowCodec.decode(
        FlowCodec.encode(FlowCodec.currentVersion, [flow]),
      ).flows.single;
      expect(again.toJson(), flow.toJson());
    });

    test('an automation contributes nothing to the chat prompt', () {
      const flow = FinnFlow(
        id: 'f',
        name: 'N',
        description: '',
        instructions: 'secret instruction',
        category: 'Automation',
        blocks: [FlowBlock.ask('x')],
      );
      expect(flow.promptLines, isEmpty);
    });
  });

  group('editing the tree', () {
    const a = FlowBlock.notify('a');
    const b = FlowBlock.notify('b');
    const c = FlowBlock.notify('c');
    const branch = FlowBlock.branch(
      FlowCondition(FlowConditionKind.charging),
      then: [a],
      otherwise: [b],
    );

    test('insert, replace, remove and move at the top level', () {
      var blocks = <FlowBlock>[a, b];
      blocks = FlowEdit.insert(blocks, FlowLane.root, 1, c);
      expect(blocks.map((x) => x.text), ['a', 'c', 'b']);
      blocks = FlowEdit.move(blocks, FlowLane.root, 2, -1);
      expect(blocks.map((x) => x.text), ['a', 'b', 'c']);
      blocks =
          FlowEdit.replace(blocks, FlowLane.root, 0, const FlowBlock.stop());
      expect(blocks.first.kind, FlowBlockKind.stop);
      blocks = FlowEdit.remove(blocks, FlowLane.root, 0);
      expect(blocks.map((x) => x.text), ['b', 'c']);
    });

    test('edits inside a branch lane change only that lane', () {
      final yes = FlowLane.root.into(0, otherwise: false);
      final no = FlowLane.root.into(0, otherwise: true);
      var blocks = <FlowBlock>[branch];
      blocks = FlowEdit.insert(blocks, yes, 1, c);
      expect(blocks.first.then.map((x) => x.text), ['a', 'c']);
      expect(blocks.first.otherwise.map((x) => x.text), ['b']);
      blocks = FlowEdit.remove(blocks, no, 0);
      expect(blocks.first.otherwise, isEmpty);
      expect(FlowEdit.at(blocks, yes, 1)?.text, 'c');
      expect(FlowEdit.laneBlocks(blocks, yes), hasLength(2));
    });

    test('a stale index changes nothing and throws nothing', () {
      final blocks = <FlowBlock>[a];
      expect(FlowEdit.remove(blocks, FlowLane.root, 5), blocks);
      expect(FlowEdit.replace(blocks, FlowLane.root, -1, b), blocks);
      expect(FlowEdit.move(blocks, FlowLane.root, 0, -1), blocks);
      expect(
        FlowEdit.insert(blocks, FlowLane.root.into(9, otherwise: false), 0, b),
        blocks,
      );
      expect(FlowEdit.at(blocks, FlowLane.root, 3), isNull);
    });

    test('a run-log path leads back to its block, or to nothing', () {
      final blocks = <FlowBlock>[a, branch];
      expect(FlowEdit.atPath(blocks, '0')?.text, 'a');
      expect(FlowEdit.atPath(blocks, '1.then.0')?.text, 'a');
      expect(FlowEdit.atPath(blocks, '1.else.0')?.text, 'b');
      expect(FlowEdit.atPath(blocks, '4'), isNull);
      expect(FlowEdit.atPath(blocks, '0.then.0'), isNull);
      expect(FlowEdit.atPath(blocks, 'x'), isNull);
    });

    test('a branch may nest only so deep', () {
      expect(FlowEdit.canNestBranch(FlowLane.root), isTrue);
      final deep =
          FlowLane.root.into(0, otherwise: false).into(0, otherwise: false);
      expect(FlowEdit.canNestBranch(deep), isFalse);
    });
  });

  group('validation', () {
    FinnFlow flow(List<FlowBlock> blocks, {List<FlowTrigger>? triggers}) =>
        FinnFlow(
          id: 'f',
          name: 'n',
          description: '',
          instructions: '',
          category: 'Automation',
          blocks: blocks,
          triggers: triggers ?? const [],
        );

    test('a valid flow has no problems', () {
      expect(
        FlowsStore.validate(flow(const [FlowBlock.notify('x')])).isValid,
        isTrue,
      );
    });

    test('a bad time or interval or level is a trigger problem', () {
      for (final trigger in const [
        FlowTrigger.daily(25, 0),
        FlowTrigger.every(5),
        FlowTrigger.batteryLow(0),
      ]) {
        expect(
          FlowsStore.validate(
            flow(const [FlowBlock.notify('x')], triggers: [trigger]),
          ).problems,
          contains(FlowValidationProblem.invalidTrigger),
          reason: '$trigger',
        );
      }
    });

    test('a branch with no condition is invalid', () {
      expect(
        FlowsStore.validate(
          flow(const [FlowBlock(kind: FlowBlockKind.branch)]),
        ).problems,
        contains(FlowValidationProblem.invalidCondition),
      );
    });

    test('the device-action flag sees inside branches', () {
      final v = FlowsStore.validate(
        flow(const [
          FlowBlock.branch(
            FlowCondition(FlowConditionKind.charging),
            then: [
              FlowBlock.action('torch', {'on': 'true'})
            ],
          ),
        ]),
      );
      expect(v.hasDeviceAction, isTrue);
    });
  });
}
