import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CODE_MAP.md is how agents decide which file to edit. A map that names a
/// file that no longer exists sends the next agent to the wrong place, so a
/// rename or delete that forgets the map fails here.
void main() {
  final root = Directory.current.path;
  final pathPattern =
      RegExp(r'`((?:lib|test|tool|docs|android|ohos)/[^`\s]+)`');

  for (final doc in const [
    'docs/architecture/CODE_MAP.md',
    'AGENTS.md',
  ]) {
    test('$doc only names files that exist', () {
      final text = File('$root/$doc').readAsStringSync();
      final missing = <String>[];
      for (final match in pathPattern.allMatches(text)) {
        final path = match.group(1)!;
        // Globs, placeholders and elided paths are prose, not references.
        if (path.contains(RegExp(r'[*<>…{}]'))) continue;
        final clean = path.replaceAll(RegExp(r'[.,:;)]+$'), '');
        if (!File('$root/$clean').existsSync() &&
            !Directory('$root/$clean').existsSync()) {
          missing.add(clean);
        }
      }
      expect(missing, isEmpty, reason: '$doc references missing paths');
    });
  }

  test('every feature folder has a README stating its purpose', () {
    final features = Directory('$root/lib/src/features')
        .listSync()
        .whereType<Directory>()
        .map((d) => d.path.split(Platform.pathSeparator).last)
        .toList()
      ..sort();
    final without = [
      for (final f in features)
        if (!File('$root/lib/src/features/$f/README.md').existsSync()) f,
    ];
    expect(without, isEmpty, reason: 'add lib/src/features/<name>/README.md');
  });
}
