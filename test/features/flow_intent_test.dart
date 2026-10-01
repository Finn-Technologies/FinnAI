import 'package:flutter_test/flutter_test.dart';

import 'package:finn_ai/src/features/flows/flow_intent.dart';
import 'package:finn_ai/src/features/flows/flow_model.dart';

void main() {
  group('FlowIntent', () {
    test('reads a brief with weekdays and a time', () {
      final intent = FlowIntent.parse(
        'Every weekday at 7:30 give me a news brief about football',
      )!;

      expect(intent.template.id, 'morning_brief');
      expect(intent.slots['topics'], 'football');
      expect(intent.trigger.daysOfWeek, {1, 2, 3, 4, 5});
      expect(intent.trigger.hour, 7);
      expect(intent.trigger.minute, 30);
    });

    test('reads pm times and a single weekday', () {
      final intent = FlowIntent.parse('Remind me to stretch on Friday at 6pm')!;

      expect(intent.template.id, 'reminder');
      expect(intent.slots['message'], contains('stretch'));
      expect(intent.trigger.daysOfWeek, {5});
      expect(intent.trigger.hour, 18);
    });

    test('says nothing when no template fits', () {
      expect(FlowIntent.parse('Do my taxes'), isNull);
    });

    test('"when I ask" is a manual flow', () {
      final intent =
          FlowIntent.parse('Check the price of a flight when I ask')!;
      expect(intent.trigger.isScheduled, isFalse);
    });
  });

  test('a weekly trigger survives a save and load', () {
    const original = FlowTrigger.weekly(18, 0, {1, 3, 5});
    final copy = FlowTrigger.fromJson(original.toJson());

    expect(copy.daysOfWeek, {1, 3, 5});
    expect(copy.hour, 18);
  });
}
