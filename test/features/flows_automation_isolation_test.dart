import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/flows/flow_templates.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/slots/slots.dart';

/// An automation's prompts are instructions for its own runs. They must never
/// become part of an ordinary chat turn, and an automation must not use up the
/// four-skill budget that exists to protect the chat prompt.
void main() {
  late Directory directory;
  late FlowsStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn-flow-iso');
    store = FlowsStore(directoryProvider: () async => directory);
    await store.initialize();
  });
  tearDown(() => directory.deleteSync(recursive: true));

  Future<FinnFlow> addAutomation(String topic) async {
    final template = FlowTemplates.byId('web_check')!;
    final flow = template.build(
      'x',
      SlotSanitizer.sanitize(template.slots, {'topic': topic}),
    );
    await store.upsertCustom(
      name: flow.name,
      description: flow.description,
      instructions: '',
      category: flow.category,
      blocks: flow.blocks,
      triggers: flow.triggers,
    );
    return store.flows.firstWhere((f) => f.name == flow.name);
  }

  test('an enabled automation never reaches the chat prompt', () async {
    final flow = await addAutomation('write python code news');
    expect(flow.enabled, isTrue);
    // A prompt that would match its name, category and description words.
    for (final prompt in [
      'write some python code about news',
      'check the latest automation',
      'Check: write python code news',
    ]) {
      final context = store.promptContextFor(prompt);
      expect(context.contains('bullet points'), isFalse, reason: prompt);
      expect(context.contains('search results'), isFalse, reason: prompt);
    }
    expect(store.enabledSkills.where((f) => f.id == flow.id), isEmpty);
    expect(store.enabledAutomations.map((f) => f.id), [flow.id]);
  });

  test('automations do not spend the four-skill budget', () async {
    for (var i = 0; i < 6; i++) {
      await addAutomation('topic $i');
    }
    expect(store.enabledAutomations, hasLength(6));
    expect(store.failure, isNull);
    // Four skills can still be enabled.
    for (final id in [
      'builtin-writing',
      'builtin-coding',
      'builtin-learning',
      'builtin-planning',
    ]) {
      expect(await store.setEnabled(id, true), isTrue, reason: id);
    }
    expect(store.enabledSkills, hasLength(4));
  });
}
