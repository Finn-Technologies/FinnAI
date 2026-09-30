import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/shared/slots/slots.dart';

/// A ready-made automation with a few slots to fill in.
///
/// Like a creation template, it owns the structure (which steps, in which
/// order, with which wording) and the user supplies only the content: a topic,
/// a city, a message. A template therefore always produces a flow that
/// [FlowsStore.validate] accepts, and the steps are the same every time.
abstract class FlowTemplate {
  const FlowTemplate();

  String get id;
  String get englishName;
  List<TemplateSlot> get slots;

  /// When the flow runs unless the user changes it.
  FlowTrigger get defaultTrigger;

  /// Builds the flow. [values] are already sanitised.
  FinnFlow build(String flowId, SlotValues values, {FlowTrigger? trigger});
}

const _language = 'Reply in the language of the topic.';

/// A short daily brief of the news that matters to you, plus the weather.
class MorningBriefTemplate extends FlowTemplate {
  const MorningBriefTemplate();

  @override
  String get id => 'morning_brief';
  @override
  String get englishName => 'morning brief';
  @override
  FlowTrigger get defaultTrigger => const FlowTrigger.daily(7, 30);

  @override
  List<TemplateSlot> get slots => const [
        TemplateSlot(
          'topics',
          SlotKind.text,
          fallback: 'world news and technology',
          example: 'football and local news',
          description: 'what you want to hear about',
          maxChars: 60,
        ),
        TemplateSlot(
          'city',
          SlotKind.text,
          fallback: '',
          example: 'Rome',
          description: 'a city for the weather, or leave empty',
          maxChars: 40,
        ),
      ];

  @override
  FinnFlow build(String flowId, SlotValues v, {FlowTrigger? trigger}) {
    final topics = v.text('topics');
    final city = v.text('city');
    return FinnFlow(
      id: flowId,
      name: 'Morning brief',
      description: topics,
      instructions: '',
      category: 'Automation',
      trigger: trigger ?? defaultTrigger,
      steps: [
        // `news:` and `weather:` pick a source built for the question; general
        // web search returns articles *about* news and weather, not the news.
        FlowStep(kind: FlowStepKind.browse, text: 'news: $topics'),
        if (city.isNotEmpty)
          FlowStep(kind: FlowStepKind.browse, text: 'weather: $city'),
        FlowStep(
          kind: FlowStepKind.prompt,
          text:
              'Write a short morning brief of 3 to 5 bullet points: first the '
              'most important news about $topics'
              '${city.isEmpty ? '' : ', then the weather in $city'}. '
              'Use only the search results above; where a part has no results '
              'say so instead of inventing it. Under 120 words. $_language',
        ),
        const FlowStep(kind: FlowStepKind.notify, text: ''),
      ],
    );
  }
}

/// Checks one topic and says what is new.
class WebCheckTemplate extends FlowTemplate {
  const WebCheckTemplate();

  @override
  String get id => 'web_check';
  @override
  String get englishName => 'web check';
  @override
  FlowTrigger get defaultTrigger => const FlowTrigger.daily(18, 0);

  @override
  List<TemplateSlot> get slots => const [
        TemplateSlot(
          'topic',
          SlotKind.text,
          fallback: 'technology news',
          example: 'new phone releases',
          description: 'the one thing to keep an eye on',
          maxChars: 60,
        ),
      ];

  @override
  FinnFlow build(String flowId, SlotValues v, {FlowTrigger? trigger}) {
    final topic = v.text('topic');
    return FinnFlow(
      id: flowId,
      name: 'Check: $topic',
      description: topic,
      instructions: '',
      category: 'Automation',
      trigger: trigger ?? defaultTrigger,
      steps: [
        FlowStep(kind: FlowStepKind.browse, text: 'news: $topic'),
        FlowStep(
          kind: FlowStepKind.prompt,
          text: 'What is the latest on $topic? Answer in 3 short bullet points '
              'using only the search results above. If they show nothing new, '
              'say so. $_language',
        ),
        const FlowStep(kind: FlowStepKind.notify, text: ''),
      ],
    );
  }
}

/// A notification with your own words. No model, no network.
class ReminderTemplate extends FlowTemplate {
  const ReminderTemplate();

  @override
  String get id => 'reminder';
  @override
  String get englishName => 'reminder';
  @override
  FlowTrigger get defaultTrigger => const FlowTrigger.daily(9, 0);

  @override
  List<TemplateSlot> get slots => const [
        TemplateSlot(
          'message',
          SlotKind.text,
          fallback: 'Time for a short break',
          example: 'Take your medication',
          description: 'what the reminder says',
          maxChars: 100,
        ),
      ];

  @override
  FinnFlow build(String flowId, SlotValues v, {FlowTrigger? trigger}) {
    final message = v.text('message');
    return FinnFlow(
      id: flowId,
      name: 'Reminder',
      description: message,
      instructions: '',
      category: 'Automation',
      trigger: trigger ?? defaultTrigger,
      steps: [FlowStep(kind: FlowStepKind.notify, text: message)],
    );
  }
}

abstract final class FlowTemplates {
  static const List<FlowTemplate> all = [
    MorningBriefTemplate(),
    WebCheckTemplate(),
    ReminderTemplate(),
  ];

  static FlowTemplate? byId(String? id) {
    for (final template in all) {
      if (template.id == id) return template;
    }
    return null;
  }
}
