import 'package:flutter/material.dart';

/// Renders the small Markdown subset useful in local-model answers.
///
/// Raw HTML, routing/thinking tags, images, and interactive links are removed.
/// This intentionally avoids a WebView or URL launcher in model output.
class SafeMarkdownText extends StatelessWidget {
  const SafeMarkdownText({super.key, required this.text});

  final String text;

  @visibleForTesting
  static String sanitize(String source) {
    var value = source
        .replaceAll(
          RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'<think>[\s\S]*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'<FINN_(?:PLUS|PRO)>', caseSensitive: false), '');
    value = value
        .replaceAllMapped(
          RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]*\)'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll(RegExp(r'</?[A-Za-z][^>\n]*>'), '');
    return value.trim();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium!.copyWith(height: 1.38);
    final blocks = sanitize(text).split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < blocks.length; index++)
          _line(context, blocks[index], base, index),
      ],
    );
  }

  Widget _line(BuildContext context, String line, TextStyle base, int index) {
    if (line.trim().isEmpty) return const SizedBox(height: 8);
    final heading = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
    final bullet = RegExp(r'^\s*[-*]\s+(.+)$').firstMatch(line);
    final numbered = RegExp(r'^\s*(\d+)[.)]\s+(.+)$').firstMatch(line);
    if (heading != null) {
      final level = heading.group(1)!.length;
      return Padding(
        padding: EdgeInsets.only(top: index == 0 ? 0 : 8, bottom: 3),
        child: Text.rich(
          _inline(
            heading.group(2)!,
            base.copyWith(
              fontSize: (base.fontSize ?? 14) + (4 - level),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    if (bullet != null || numbered != null) {
      final marker = bullet != null ? '•' : '${numbered!.group(1)}.';
      final content = bullet?.group(1) ?? numbered!.group(2)!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 25, child: Text(marker, style: base)),
            Expanded(child: Text.rich(_inline(content, base))),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(_inline(line, base)),
    );
  }

  TextSpan _inline(String value, TextStyle base) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*[^*\n]+\*\*|`[^`\n]+`)');
    var cursor = 0;
    for (final match in pattern.allMatches(value)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: _plain(value.substring(cursor, match.start))));
      }
      final token = match.group(0)!;
      if (token.startsWith('**')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(
              fontFamily: 'monospace',
              backgroundColor: base.color?.withValues(alpha: .08),
            ),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < value.length) {
      spans.add(TextSpan(text: _plain(value.substring(cursor))));
    }
    return TextSpan(style: base, children: spans);
  }

  String _plain(String value) => value.replaceAll('**', '');
}
