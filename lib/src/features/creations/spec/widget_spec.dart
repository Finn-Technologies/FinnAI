import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/features/creations/spec/spec_json.dart';

/// One label/value line in a home-screen widget.
@immutable
class HomeWidgetRow {
  const HomeWidgetRow({required this.label, required this.value});

  final String label;
  final String value;

  /// The value as a whole number, or null when it is text.
  int? get number => int.tryParse(value.trim());

  factory HomeWidgetRow.fromJson(Map<String, Object?> json) => HomeWidgetRow(
        label: SpecJson.string(json, 'label'),
        value: SpecJson.stringOr(json, 'value', ''),
      );

  Map<String, Object?> toJson() => {'label': label, 'value': value};
}

/// What a home-screen widget does when it is touched.
///
/// The launcher draws a widget with `RemoteViews`, which cannot run our code,
/// but it *can* send a tap to a receiver. So every interaction is one of a few
/// fixed taps that the receiver applies to state it keeps itself, and the
/// widget redraws from that state. It works with the app closed and never calls
/// into Dart.
enum HomeWidgetKind {
  /// Shows its rows and opens the app when tapped.
  display,

  /// One number with minus and plus buttons, and an optional goal.
  counter,

  /// Rows that tick on and off when tapped.
  checklist,

  /// Rows that each hold a number; tapping a row adds one step.
  tracker;

  /// Whether touching the widget changes it.
  bool get interactive => this != display;

  static HomeWidgetKind parse(Object? raw) {
    if (raw is String) {
      for (final kind in values) {
        if (kind.name == raw) return kind;
      }
    }
    return display;
  }
}

/// A home-screen widget layout.
///
/// Deliberately much narrower than [MiniAppSpec]: a launcher widget is rendered
/// through `RemoteViews`, which understands only text, images, a progress bar
/// and a click intent. Anything richer has to be a mini app instead.
@immutable
class HomeWidgetSpec {
  const HomeWidgetSpec({
    required this.title,
    required this.accent,
    required this.rows,
    this.footer = '',
    this.kind = HomeWidgetKind.display,
    this.step = 1,
    this.goal = 0,
  });

  final String title;
  final MiniAppAccent accent;
  final List<HomeWidgetRow> rows;
  final String footer;
  final HomeWidgetKind kind;

  /// How much one tap adds to a [HomeWidgetKind.counter] or tracker row.
  final int step;

  /// The number a counter is working towards, or 0 for none.
  final int goal;

  factory HomeWidgetSpec.fromJson(Map<String, Object?> json) => HomeWidgetSpec(
        title: SpecJson.string(json, 'title'),
        accent: MiniAppAccent.parse(SpecJson.stringOr(json, 'accent', 'mint')),
        rows: SpecJson.objectList(json, 'rows')
            .map(HomeWidgetRow.fromJson)
            .toList(growable: false),
        footer: SpecJson.stringOr(json, 'footer', ''),
        kind: HomeWidgetKind.parse(json['kind']),
        step: SpecJson.intOr(json, 'step', 1).clamp(1, 1000),
        goal: SpecJson.intOr(json, 'goal', 0).clamp(0, 1000000),
      );

  Map<String, Object?> toJson() => {
        'title': title,
        'accent': accent.name,
        'rows': rows.map((row) => row.toJson()).toList(),
        'footer': footer,
        if (kind != HomeWidgetKind.display) 'kind': kind.name,
        if (kind == HomeWidgetKind.counter || kind == HomeWidgetKind.tracker)
          'step': step,
        if (kind == HomeWidgetKind.counter && goal > 0) 'goal': goal,
      };
}
