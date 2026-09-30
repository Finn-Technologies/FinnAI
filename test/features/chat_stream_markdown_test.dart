import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/safe_markdown_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => SafeMarkdownText.debugParseCount = 0);

  group('streaming answers are never left stale', () {
    testWidgets('the final render equals the final streamed text', (
      tester,
    ) async {
      const finalAnswer =
          'The sky is blue.\n\n- because of Rayleigh scattering';
      await tester.pumpWidget(_host(''));
      expect(find.text('The sky is blue.'), findsNothing);

      // A burst of tokens inside one paint gap. Only the first paint is exact;
      // the rest reuse the previous render — that is the throttle buying its
      // win, and the screen is allowed to trail *within* its window.
      for (final text in ['The', 'The sky', 'The sky is blue.']) {
        await tester.pumpWidget(_host(text));
      }

      // The turn gains its list, then ends. The trailing parse must land on its
      // own, with no further input, and the tree must then show exactly the
      // final answer — a deferred render may never outlive the stream.
      await tester.pumpWidget(_host(finalAnswer.split('\n').first));
      await tester.pumpWidget(_host(finalAnswer));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('The sky is blue.'),
        findsOneWidget,
        reason: 'a deferred render must never outlive the stream',
      );
      expect(find.text('because of Rayleigh scattering'), findsOneWidget);

      // And the tree renders the real input, not a prefix of it. `Text.data` is
      // null for anything drawn as `Text.rich` — bullets, quotes, headings — so
      // this reads the spans too. Reading only `data` would silently pass on a
      // tree that had dropped every rich line.
      //
      // The comparison is line-wise rather than against `sanitize` wholesale:
      // the renderer deliberately drops markup and layout the sanitizer leaves
      // in the source (a bullet's "- " becomes a dot, a blank line a spacer),
      // so what must survive is the wording of every content line.
      final rendered = _renderedText(tester);
      for (final line in _contentLines(finalAnswer)) {
        expect(
          rendered,
          contains(line),
          reason: 'the final answer is missing a line it must show',
        );
      }
    });

    testWidgets('an edit that is not an extension re-parses immediately', (
      tester,
    ) async {
      await tester.pumpWidget(_host('The sky is blue'));
      expect(find.text('The sky is blue'), findsOneWidget);

      final parsesBefore = SafeMarkdownText.debugParseCount;
      // Same length, different content: a regenerate, not a continuation.
      await tester.pumpWidget(_host('The sky is green'));
      expect(SafeMarkdownText.debugParseCount, greaterThan(parsesBefore));
      expect(find.text('The sky is green'), findsOneWidget);
      expect(find.text('The sky is blue'), findsNothing);
    });

    testWidgets('a new turn starting empty re-parses instead of reusing', (
      tester,
    ) async {
      await tester.pumpWidget(_host('The sky is blue'));
      final parsesBefore = SafeMarkdownText.debugParseCount;
      await tester.pumpWidget(_host(''));
      expect(SafeMarkdownText.debugParseCount, greaterThan(parsesBefore));
    });
  });

  group('the guard never caches across a change that alters the render', () {
    testWidgets('a brightness change re-parses', (tester) async {
      await tester
          .pumpWidget(_host('The sky is blue', brightness: Brightness.light));
      final parsesBefore = SafeMarkdownText.debugParseCount;
      await tester.pumpWidget(
        _host('The sky is bl', brightness: Brightness.dark),
      );
      expect(
        SafeMarkdownText.debugParseCount,
        greaterThan(parsesBefore),
        reason: 'the cached widgets baked in the old brightness',
      );
    });

    testWidgets('a showImages change re-parses', (tester) async {
      await tester.pumpWidget(_host('![alt](https://example.com/a.png)'));
      final parsesBefore = SafeMarkdownText.debugParseCount;
      await tester.pumpWidget(
        _host('![alt](https://example.com/a.png)', showImages: false),
      );
      expect(SafeMarkdownText.debugParseCount, greaterThan(parsesBefore));
    });
  });

  testWidgets('a burst inside one paint gap costs one parse, not one per build',
      (
    tester,
  ) async {
    // First paint always parses.
    await tester.pumpWidget(_host('a'));
    expect(SafeMarkdownText.debugParseCount, 1);

    // 60 Hz notify burst, all inside the 48 ms repaint gap: the throttle must
    // collapse them into renders that reuse the previous parse.
    for (var i = 0; i < 30; i++) {
      await tester.pumpWidget(_host('a${'b' * i}'));
    }
    final afterBurst = SafeMarkdownText.debugParseCount;
    expect(afterBurst, lessThan(6),
        reason: '30 builds in one paint gap must not mean 31 full parses');

    // The trailing re-parse is what makes the final text exact.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('a${'b' * 29}'), findsOneWidget);
    expect(SafeMarkdownText.debugParseCount, greaterThan(afterBurst));
  });

  testWidgets('the screen trails only inside the window, never after it', (
    tester,
  ) async {
    await tester.pumpWidget(_host('The sky is blue'));
    expect(find.text('The sky is blue'), findsOneWidget);

    // Every build inside the window reuses the previous render, so the tree is
    // knowingly stale here. This is the cost of the throttle, and it is the
    // thing that must not leak past the window.
    for (final text in ['The sky is blue and', 'The sky is blue and bright']) {
      await tester.pumpWidget(_host(text));
    }
    final state =
        tester.state<SafeMarkdownTextState>(find.byType(SafeMarkdownText));
    expect(state.isRenderDeferred, isTrue, reason: 'the window is open');
    expect(
      find.text('The sky is blue and bright'),
      findsNothing,
      reason: 'this build is inside the window and is allowed to trail',
    );

    // The trailing parse ends it with no further input from the stream. It
    // must be unconditional: a parse that re-tested the deferral conditions
    // could defer itself forever, which is the bug this file guards.
    await tester
        .pump(SafeMarkdownText.reparseDelay + const Duration(milliseconds: 16));
    expect(state.isRenderDeferred, isFalse);
    expect(find.text('The sky is blue and bright'), findsOneWidget);
  });

  testWidgets('a large jump re-parses immediately, it is not deferred', (
    tester,
  ) async {
    await tester.pumpWidget(_host('short'));
    final parsesBefore = SafeMarkdownText.debugParseCount;
    final jumped = 'short${' long'.padRight(400, 'x')}';
    await tester.pumpWidget(_host(jumped));
    expect(
      SafeMarkdownText.debugParseCount,
      greaterThan(parsesBefore),
      reason: 'a big jump lands in a different shape, so it cannot wait',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('xxxx'), findsOneWidget);
  });
}

/// The wording of every line the reader is meant to see: blank lines and the
/// `- ` / `1. ` markers become layout, not text.
List<String> _contentLines(String source) => SafeMarkdownText.sanitize(source)
    .split('\n')
    .map((line) => line.replaceFirst(RegExp(r'^\s*[-*]\s+'), '').trim())
    .where((line) => line.isNotEmpty)
    .toList();

/// Everything the answer actually shows, whether it was drawn as plain `Text`
/// or as a `Text.rich` span tree.
String _renderedText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((widget) => widget.data ?? _flattenSpan(widget.textSpan))
    .where((value) => value.isNotEmpty)
    .join('\n');

String _flattenSpan(InlineSpan? span) {
  if (span == null) return '';
  if (span is TextSpan) {
    return span.text ?? (span.children?.map(_flattenSpan).join() ?? '');
  }
  return '';
}

Widget _host(
  String text, {
  Brightness brightness = Brightness.light,
  bool showImages = true,
}) =>
    MaterialApp(
      theme: brightness == Brightness.dark ? FluxTheme.dark : FluxTheme.light,
      home: Scaffold(
        body: SafeMarkdownText(text: text, showImages: showImages),
      ),
    );
