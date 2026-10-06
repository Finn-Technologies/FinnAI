import 'package:flutter/material.dart';

import 'package:finn_ai/src/features/code/ui/code_style.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/flux_surfaces.dart';

/// A `/command` the composer offers.
@immutable
class CodeSlashCommand {
  const CodeSlashCommand({
    required this.name,
    required this.description,
    required this.icon,
    required this.run,
  });

  /// Without the slash: `new`, `files`.
  final String name;
  final String description;
  final IconData icon;
  final VoidCallback run;
}

/// One row offered above the composer: a command or a file.
@immutable
class CodeSuggestion {
  const CodeSuggestion({
    required this.label,
    required this.icon,
    this.detail = '',
  });

  final String label;
  final String detail;
  final IconData icon;
}

/// What the composer is completing, read from the text and the cursor.
@immutable
class CodeCompletionQuery {
  const CodeCompletionQuery._(this.kind, this.query, this.start);

  final CodeCompletionKind kind;

  /// What has been typed after the `/` or `@`.
  final String query;

  /// Where the `/` or `@` is in the text.
  final int start;

  /// A `/command` is the whole message so far; an `@file` is the word the
  /// cursor is in. Null when neither is being typed.
  static CodeCompletionQuery? of(TextEditingValue value) {
    final text = value.text;
    if (RegExp(r'^/[\w-]*$').hasMatch(text)) {
      return CodeCompletionQuery._(
          CodeCompletionKind.command, text.substring(1), 0);
    }
    final cursor = value.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return null;
    var start = cursor;
    while (start > 0 && !RegExp(r'\s').hasMatch(text[start - 1])) {
      start--;
    }
    final word = text.substring(start, cursor);
    if (!word.startsWith('@')) return null;
    return CodeCompletionQuery._(
        CodeCompletionKind.file, word.substring(1), start);
  }
}

enum CodeCompletionKind { command, file }

/// The list that floats above the composer while a `/` or `@` is typed.
class CodeSuggestionList extends StatelessWidget {
  const CodeSuggestionList({
    super.key,
    required this.items,
    required this.onPick,
    this.empty,
  });

  final List<CodeSuggestion> items;
  final ValueChanged<int> onPick;

  /// Shown when [items] is empty.
  final String? empty;

  @override
  Widget build(BuildContext context) {
    final rows = items.take(6).toList();
    return Container(
      key: const ValueKey('code-suggestions'),
      decoration: FluxSurfaces.flatCard(context),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rows.isEmpty && empty != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(empty!, style: CodeStyle.meta(context)),
            ),
          for (final (i, item) in rows.indexed)
            InkWell(
              key: ValueKey('code-suggestion-$i'),
              onTap: () => onPick(i),
              child: SizedBox(
                height: 34,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      FluxIcon(
                        icon: item.icon,
                        size: 14,
                        color: FluxColors.mutedOf(context),
                      ),
                      const SizedBox(width: 10),
                      Text(item.label, style: CodeStyle.code(context)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CodeStyle.label(
                            context,
                            color: FluxColors.mutedOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
