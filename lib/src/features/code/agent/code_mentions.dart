import 'package:finn_ai/src/features/code/sandbox/workspace.dart';

/// `@file` mentions in a request.
abstract final class CodeMentions {
  /// The files [text] names with `@path`, as fenced blocks, within [budget]
  /// characters. Names that are not files in the project are left alone.
  static Future<String> read(
    CodeWorkspace workspace,
    String text, {
    required int budget,
  }) async {
    final names = {
      for (final match in RegExp(r'(?:^|\s)@([\w./-]+)').allMatches(text))
        match.group(1)!.replaceAll(RegExp(r'[.,;:!?]+$'), ''),
    };
    if (names.isEmpty) return '';
    final blocks = <String>[];
    var left = budget;
    for (final name in names) {
      if (left <= 80) break;
      try {
        final file = workspace.fileFor(name);
        if (!await file.exists()) continue;
        var content = await workspace.readFile(name);
        if (content.length > left) {
          content = '${content.substring(0, left)}\n…';
        }
        left -= content.length;
        final fence = content.contains('```') ? '````' : '```';
        blocks.add('Contents of $name:\n$fence\n$content\n$fence');
      } catch (_) {
        // Not a readable project file: the mention stays plain text.
      }
    }
    return blocks.join('\n\n');
  }
}
