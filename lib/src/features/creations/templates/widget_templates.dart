import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/spec/widget_spec.dart';
import 'package:finn_ai/src/features/creations/spec/spec_limits.dart';
import 'package:finn_ai/src/features/creations/templates/creation_template.dart';
import 'package:finn_ai/src/shared/slots/slots.dart';

const _accent = TemplateSlot(
  'accent',
  SlotKind.choice,
  options: SpecLimits.accentList,
  fallback: 'sky',
  example: 'mint',
  description: 'one colour word: mint, blue, lime, amber, rose, violet or sky',
);

const _footer = TemplateSlot(
  'footer',
  SlotKind.text,
  fallback: 'Tap to open',
  example: 'Updated today',
  description: 'a few words at the bottom',
  maxChars: 30,
);

CreationArtifact _widget(
  String title,
  String accent,
  List<Map<String, Object?>> rows,
  String footer,
) =>
    WidgetArtifact(
      HomeWidgetSpec.fromJson({
        'title': title,
        'accent': accent,
        'rows': rows,
        'footer': footer,
      }),
    );

/// One big number with a label: a countdown, a streak, a balance.
class StatWidgetTemplate extends CreationTemplate {
  const StatWidgetTemplate();

  @override
  String get id => 'stat';
  @override
  CreationKind get kind => CreationKind.widget;
  @override
  String get englishName => 'single number widget';
  @override
  String get purpose => 'one number with a label, like a streak or a countdown';

  @override
  List<TemplateSlot> get slots => const [
        TemplateSlot(
          'title',
          SlotKind.text,
          fallback: 'My widget',
          example: 'Reading streak',
          description: 'a short name',
          maxChars: 30,
        ),
        TemplateSlot(
          'label',
          SlotKind.text,
          fallback: 'Today',
          example: 'Days in a row',
          description: 'what the number means, a few words',
          maxChars: 24,
        ),
        TemplateSlot(
          'value',
          SlotKind.text,
          fallback: '0',
          example: '12',
          description: 'the number or a very short value',
          maxChars: 18,
        ),
        _footer,
        _accent,
      ];

  @override
  List<String> get keywords => const [
        'streak',
        'countdown',
        'days',
        'number',
        'stat',
        'balance',
        'counter',
        'serie',
        'giorni',
        'conto alla rovescia',
        'racha',
        'días',
        'dias',
        'série',
        'jours',
        'tage',
        'zähler',
      ];

  @override
  CreationArtifact build(SlotValues v) => _widget(
        titleFor(v),
        v.text('accent'),
        [
          {'label': v.text('label'), 'value': v.text('value')},
        ],
        v.text('footer'),
      );
}

/// Up to four label/value lines: a day plan, a scoreboard, a few stats.
class RowsWidgetTemplate extends CreationTemplate {
  const RowsWidgetTemplate();

  @override
  String get id => 'rows';
  @override
  CreationKind get kind => CreationKind.widget;
  @override
  String get englishName => 'list widget';
  @override
  String get purpose => 'up to four short label: value lines';

  @override
  List<TemplateSlot> get slots => const [
        TemplateSlot(
          'title',
          SlotKind.text,
          fallback: 'My widget',
          example: 'Today',
          description: 'a short name',
          maxChars: 30,
        ),
        TemplateSlot(
          'rows',
          SlotKind.list,
          fallback: <String>['Today: 0', 'Goal: 1'],
          example: <String>['Water: 3', 'Steps: 4000'],
          description: 'between 1 and 4 lines, each written "Label: value"',
          maxChars: 40,
          maxItems: 4,
          minItems: 1,
        ),
        _footer,
        _accent,
      ];

  @override
  List<String> get keywords => const [
        'widget',
        'plan',
        'schedule',
        'today',
        'stats',
        'list',
        'agenda',
        'oggi',
        'programma',
        'hoy',
        'agenda',
        "aujourd'hui",
        'heute',
      ];

  @override
  CreationArtifact build(SlotValues v) {
    final rows = <Map<String, Object?>>[];
    for (final line in v.list('rows')) {
      final split = line.indexOf(':');
      final label = split < 0 ? line : line.substring(0, split).trim();
      final value = split < 0 ? '' : line.substring(split + 1).trim();
      rows.add({
        'label': label.isEmpty ? line : label,
        'value': value.length > 18 ? value.substring(0, 18).trimRight() : value,
      });
    }
    return _widget(titleFor(v), v.text('accent'), rows, v.text('footer'));
  }
}
