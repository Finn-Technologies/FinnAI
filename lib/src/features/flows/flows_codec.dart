import 'dart:convert';

import 'package:finn_ai/src/features/flows/flow_model.dart';

/// Encodes and decodes a flow document.
///
/// Separate from the store so the format can be tested, and so each older
/// version is read by exactly one function that says what it did with it.
class FlowCodec {
  const FlowCodec._();

  /// The current on-disk version.
  ///
  /// * v1: `{name, description, instructions, category, enabled}` — a guide.
  /// * v2: flows with a flat list of `steps` and one `trigger`.
  /// * v3: a tree of `blocks`, a list of `triggers` and `conditions`.
  /// * v4: v3 without guides. Guides (flows with no blocks, including the
  ///   built-ins that used to ship with the app) are dropped on read.
  static const int currentVersion = 4;

  /// A v1 flow was only ever instructions for the model. Guides were removed,
  /// so there is nothing to keep: the caller drops the null.
  static FinnFlow? migrateV1(Map<String, Object?> json) => null;

  /// A v2 flow's steps become blocks of the same meaning, in the same order.
  ///
  /// Version 2 delivered the written answer to a chat on its own at the end of
  /// a run that wrote one; version 3 makes that a block, so the step is added
  /// where the old runner did it and the migrated flow behaves as before.
  static FinnFlow migrateV2(Map<String, Object?> json) {
    final blocks = <FlowBlock>[];
    var wrote = false;
    for (final step in (json['steps'] as List<Object?>? ?? const [])) {
      if (step is! Map) continue;
      final kind = FlowBlockKind.fromName(step['kind']?.toString());
      if (kind == null || kind == FlowBlockKind.branch) continue;
      wrote = wrote || kind == FlowBlockKind.ask;
      blocks.add(
        FlowBlock.fromJson({
          'kind': kind.name,
          'text': step['text'],
          'action': step['action'],
          'args': step['args'],
        })!,
      );
    }
    if (wrote) blocks.add(const FlowBlock.saveToChat());
    final trigger =
        json['trigger'] is Map ? FlowTrigger.fromJson(json['trigger']) : null;
    return FinnFlow(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      instructions: json['instructions']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Custom',
      enabled: json['enabled'] == true,
      builtIn: json['builtIn'] == true,
      blocks: blocks,
      triggers: [if (trigger != null && !trigger.isManual) trigger],
      granted: json['granted'] == true,
    );
  }

  /// Parses a whole document, migrating older versions.
  ///
  /// Returns an empty list for a document it cannot read, so a corrupt file
  /// shows an empty Flows screen rather than an error. Guides — flows with no
  /// blocks, including v1 flows and the built-ins that used to ship with the
  /// app — are dropped: there is nothing that runs them anymore.
  static ({int version, List<FinnFlow> flows}) decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) return (version: currentVersion, flows: const []);
    final json = decoded.cast<String, Object?>();
    final version = (json['version'] as num?)?.toInt() ?? 1;
    final raw = json['flows'] as List<Object?>? ?? const [];
    final migrated = <FinnFlow>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final flow = switch (version) {
        >= 3 => FinnFlow.fromJson(item.cast<String, Object?>()),
        2 => migrateV2(item.cast<String, Object?>()),
        _ => migrateV1(item.cast<String, Object?>()),
      };
      // A v1 flow always migrates to null; a v2/v3 flow with no blocks is a
      // guide left over from before guides were removed.
      if (flow != null && flow.blocks.isNotEmpty) migrated.add(flow);
    }
    return (version: version, flows: migrated);
  }

  static String encode(int version, List<FinnFlow> flows) => jsonEncode({
        'version': version,
        'flows': [for (final flow in flows) flow.toJson()],
      });
}
