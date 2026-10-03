import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/engine/api/web_source.dart';
import 'package:finn_ai/src/features/flows/flow_ports.dart';
import 'package:finn_ai/src/features/flows/flow_runner.dart';
import 'package:finn_ai/src/features/flows/flow_schedule.dart';
import 'package:finn_ai/src/features/flows/flow_templates.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/slots/slots.dart';

class _Model implements FlowModel {
  final prompts = <String>[];
  final contexts = <String>[];
  final limits = <int?>[];
  @override
  Future<String> answer(
    String prompt, {
    String groundedContext = '',
    int? maxTokens,
  }) async {
    limits.add(maxTokens);
    prompts.add(prompt);
    contexts.add(groundedContext);
    return '- first point\n- second point';
  }
}

class _Search implements FlowSearch {
  _Search({this.offline = false});
  final bool offline;
  final queries = <String>[];
  @override
  Future<FlowSearchResult> search(String query) async {
    queries.add(query);
    if (offline) return const FlowSearchResult(failed: true);
    return FlowSearchResult(
      groundedContext: 'RETRIEVED WEB RESULTS:\n[1] $query',
      sources: [
        WebSource(
          title: query,
          url: Uri.parse('https://example.com/${queries.length}'),
          snippet: 's',
        ),
      ],
    );
  }
}

/// News is unreachable, weather answers.
class _PartialSearch implements FlowSearch {
  @override
  Future<FlowSearchResult> search(String query) async {
    if (query.startsWith('news:')) {
      return const FlowSearchResult(failed: true);
    }
    return FlowSearchResult(
      groundedContext: 'RETRIEVED WEB RESULTS:\n[1] $query',
      sources: [
        WebSource(
            title: query, url: Uri.parse('https://e.com/w'), snippet: 's'),
      ],
    );
  }
}

class _Sink implements FlowOutputSink {
  final delivered = <(String, String, int)>[];
  @override
  Future<void> deliver(
      FinnFlow flow, String text, List<WebSource> sources) async {
    delivered.add((flow.name, text, sources.length));
  }
}

class _Notifier implements FlowNotifier {
  final sent = <(String, String)>[];
  @override
  Future<void> notify({
    required String flowId,
    required String title,
    required String body,
  }) async {
    sent.add((title, body));
  }
}

void main() {
  late Directory directory;
  late FlowsStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finn-flow-tpl');
    store = FlowsStore(directoryProvider: () async => directory);
    await store.initialize();
  });
  tearDown(() => directory.deleteSync(recursive: true));

  group('templates build valid flows', () {
    for (final template in FlowTemplates.all) {
      test('${template.id}: fallbacks and 200 rounds of hostile input', () {
        final random = Random(template.id.hashCode);
        for (var round = 0; round < 200; round++) {
          final raw = <String, Object?>{
            for (final slot in template.slots)
              if (random.nextInt(4) != 0)
                slot.key: [
                  null,
                  '',
                  'x' * random.nextInt(400),
                  '{input}{date} \u0007 ${random.nextInt(99)}',
                  random.nextInt(1000),
                ][random.nextInt(5)],
          };
          final values = SlotSanitizer.sanitize(template.slots, raw);
          final flow = template.build('f', values);
          final validation = FlowsStore.validate(flow);
          expect(validation.isValid, isTrue, reason: '$raw');
          expect(validation.hasDeviceAction, template.actsOnDevice);
          // Every template starts something: an alarm or a device event.
          expect(flow.trigger.isScheduled || flow.trigger.isEvent, isTrue);
          if (flow.trigger.isScheduled) {
            expect(
              FlowSchedule.nextRun(flow.trigger, DateTime(2026, 9, 30, 12)),
              isNotNull,
            );
          }
        }
      });
    }

    test('a slot value cannot smuggle a placeholder into a step', () {
      final template = FlowTemplates.byId('web_check')!;
      final values = SlotSanitizer.sanitize(
          template.slots, {'topic': 'cats {input} and {date}'});
      final flow = template.build('f', values);
      final query = flow.blocks.first.text;
      // No placeholder can come in through a slot.
      expect(query.contains('{date}'), isFalse);
      expect(query.contains('{input}'), isFalse);
    });
  });

  group('running a template', () {
    test(
        'morning brief: two searches, one grounded prompt, a notification, '
        'and the result delivered', () async {
      final template = FlowTemplates.byId('morning_brief')!;
      final flow = template.build(
        'brief',
        SlotSanitizer.sanitize(
            template.slots, {'topics': 'football', 'city': 'Rome'}),
      );
      final model = _Model();
      final search = _Search();
      final sink = _Sink();
      final notifier = _Notifier();
      final run = await FlowRunner(
        store: store,
        model: model,
        search: search,
        sink: sink,
        notifier: notifier,
        clock: () => DateTime(2026, 9, 30, 7, 30),
      ).run(flow, triggeredBy: 'schedule');

      expect(run.outcome, FlowRunOutcome.completed);
      expect(search.queries, ['news: football', 'weather: Rome']);
      expect(model.prompts, hasLength(1));
      expect(model.limits.single, FlowRunner.maxAnswerTokens,
          reason: 'a brief is bounded');
      expect(model.contexts.single, contains('news: football'));
      expect(model.contexts.single, contains('weather: Rome'));
      expect(notifier.sent.single.$1, 'Morning brief');
      expect(notifier.sent.single.$2, contains('first point'));
      expect(sink.delivered.single.$3, 2, reason: 'both sources delivered');
      expect(run.steps.map((s) => s.outcome),
          everyElement(FlowRunOutcome.completed));
    });

    test('offline: a brief with no sources does not invent one', () async {
      final template = FlowTemplates.byId('web_check')!;
      final flow = template.build(
          'c', SlotSanitizer.sanitize(template.slots, {'topic': 'cats'}));
      final model = _Model();
      final notifier = _Notifier();
      final sink = _Sink();
      final run = await FlowRunner(
        store: store,
        model: model,
        search: _Search(offline: true),
        notifier: notifier,
        sink: sink,
      ).run(flow);
      expect(run.outcome, FlowRunOutcome.failed);
      expect(run.steps.first.detail, 'offline');
      expect(run.steps[1].detail, 'no sources');
      expect(model.prompts, isEmpty, reason: 'the model must not be asked');
      expect(notifier.sent, isEmpty);
      expect(sink.delivered, isEmpty);
    });

    test('one source out of two is enough to write the brief', () async {
      final template = FlowTemplates.byId('morning_brief')!;
      final flow = template.build(
        'b',
        SlotSanitizer.sanitize(
            template.slots, {'topics': 'football', 'city': 'Rome'}),
      );
      final model = _Model();
      final run = await FlowRunner(
        store: store,
        model: model,
        search: _PartialSearch(),
        notifier: _Notifier(),
      ).run(flow);
      expect(run.outcome, FlowRunOutcome.completed);
      expect(model.contexts.single, contains('weather: Rome'));
      // The missing part is named, so the model is told not to fill it in.
      expect(model.contexts.single,
          contains('NO RESULTS were found for "football"'));
      expect(model.contexts.single, contains('Do not make anything up'));
    });

    test('a reminder needs no model and no network', () async {
      final template = FlowTemplates.byId('reminder')!;
      final flow = template.build('r',
          SlotSanitizer.sanitize(template.slots, {'message': 'Drink water'}));
      final notifier = _Notifier();
      final sink = _Sink();
      final run = await FlowRunner(
        store: store,
        notifier: notifier,
        sink: sink,
      ).run(flow, triggeredBy: 'schedule');
      expect(run.outcome, FlowRunOutcome.completed);
      expect(notifier.sent.single, ('Reminder', 'Drink water'));
      expect(sink.delivered, isEmpty, reason: 'nothing written, nothing saved');
    });

    test('a run that fails delivers nothing and notifies nobody', () async {
      final template = FlowTemplates.byId('web_check')!;
      final flow = template.build(
          'c', SlotSanitizer.sanitize(template.slots, {'topic': 'cats'}));
      final notifier = _Notifier();
      final sink = _Sink();
      final run = await FlowRunner(
        store: store,
        // No model: the prompt step fails, so the notify step must not run.
        search: _Search(),
        notifier: notifier,
        sink: sink,
      ).run(flow);
      expect(run.outcome, FlowRunOutcome.failed);
      expect(notifier.sent, isEmpty);
      expect(sink.delivered, isEmpty);
    });

    test('the log still holds no model text', () async {
      final template = FlowTemplates.byId('web_check')!;
      final flow = template.build(
          'c', SlotSanitizer.sanitize(template.slots, {'topic': 'cats'}));
      await FlowRunner(
        store: store,
        model: _Model(),
        search: _Search(),
        notifier: _Notifier(),
      ).run(flow);
      final raw = directory
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join();
      expect(raw.contains('first point'), isFalse);
    });
  });

  group('next run', () {
    final wed = DateTime(2026, 9, 30, 12); // a Wednesday
    test('a daily flow later today runs today', () {
      expect(FlowSchedule.nextRun(const FlowTrigger.daily(18, 0), wed),
          DateTime(2026, 9, 30, 18));
    });
    test('a daily flow already past runs tomorrow', () {
      expect(FlowSchedule.nextRun(const FlowTrigger.daily(7, 30), wed),
          DateTime(2026, 10, 1, 7, 30));
    });
    test('exactly now is not "next"', () {
      expect(FlowSchedule.nextRun(const FlowTrigger.daily(12, 0), wed),
          DateTime(2026, 10, 1, 12));
    });
    test('a weekly flow picks the next matching weekday', () {
      // Monday and Friday; today is Wednesday -> Friday 2 Oct.
      expect(
        FlowSchedule.nextRun(const FlowTrigger.weekly(9, 0, {1, 5}), wed),
        DateTime(2026, 10, 2, 9),
      );
    });
    test('a manual flow has no next run', () {
      expect(FlowSchedule.nextRun(const FlowTrigger.manual(), wed), isNull);
    });
    test('month and year boundaries roll over', () {
      expect(
        FlowSchedule.nextRun(
            const FlowTrigger.daily(6, 0), DateTime(2026, 12, 31, 23)),
        DateTime(2027, 1, 1, 6),
      );
    });
  });
}
