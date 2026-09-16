import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/features/creations/spec/spec_json.dart';

/// One label/value line in a home-screen widget.
@immutable
class HomeWidgetRow {
  const HomeWidgetRow({required this.label, required this.value});

  final String label;
  final String value;

  factory HomeWidgetRow.fromJson(Map<String, Object?> json) => HomeWidgetRow(
        label: SpecJson.string(json, 'label'),
        value: SpecJson.stringOr(json, 'value', ''),
      );

  Map<String, Object?> toJson() => {'label': label, 'value': value};
}

/// A home-screen widget layout.
///
/// Deliberately much narrower than [MiniAppSpec]: a launcher widget is rendered
/// through `RemoteViews`, which understands only text, images, a progress bar
/// and a click intent. Nothing here can be interactive beyond "tap to open", so
/// anything richer has to be a mini app instead of a widget.
@immutable
class HomeWidgetSpec {
  const HomeWidgetSpec({
    required this.title,
    required this.accent,
    required this.rows,
    this.footer = '',
  });

  final String title;
  final MiniAppAccent accent;
  final List<HomeWidgetRow> rows;
  final String footer;

  factory HomeWidgetSpec.fromJson(Map<String, Object?> json) => HomeWidgetSpec(
        title: SpecJson.string(json, 'title'),
        accent: MiniAppAccent.parse(SpecJson.stringOr(json, 'accent', 'mint')),
        rows: SpecJson.objectList(json, 'rows')
            .map(HomeWidgetRow.fromJson)
            .toList(growable: false),
        footer: SpecJson.stringOr(json, 'footer', ''),
      );

  Map<String, Object?> toJson() => {
        'title': title,
        'accent': accent.name,
        'rows': rows.map((row) => row.toJson()).toList(),
        'footer': footer,
      };
}
