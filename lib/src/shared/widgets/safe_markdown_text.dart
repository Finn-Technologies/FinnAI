import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';

// Compiled once per isolate. These run per line, per build, while a reply is
// streaming, so constructing them inline cost tens of thousands of regex
// compilations per second on a mid-range device.
final RegExp _thinkingBlock = RegExp(
  r'<think>[\s\S]*?</think>',
  caseSensitive: false,
);
final RegExp _unterminatedThinking = RegExp(
  r'<think>[\s\S]*$',
  caseSensitive: false,
);
final RegExp _tierMarker = RegExp(
  r'<FINN_(?:PLUS|PRO)>',
  caseSensitive: false,
);
final RegExp _mdImage = RegExp(r'!\[([^\]]*)\]\(([^)]*)\)');
final RegExp _mdLink = RegExp(r'\[([^\]]+)\]\(([^)]*)\)');
final RegExp _htmlTag = RegExp(r'</?[A-Za-z][^>\n]*>');

/// A tag the model started and never closed, such as `</Head` at the end of a
/// reply. Only letters and digits may follow the `<` so ordinary prose like
/// "5 < 7 apples" is left alone; a trailing fragment is always meant as markup.
final RegExp _danglingTag = RegExp(r'</?[A-Za-z][A-Za-z0-9]*$');
final RegExp _imageLine = RegExp(r'^!\[([^\]]*)\]\((https://[^)]+)\)$');
final RegExp _quoteLine = RegExp(r'^\s*>\s*(.+)$');
final RegExp _keyValueLine = RegExp(r'^\s*\*\*([^*\n:]+):\*\*\s+(.+)$');
final RegExp _headingLine = RegExp(r'^(#{1,3})\s+(.+)$');
final RegExp _bulletLine = RegExp(r'^\s*[-*]\s+(.+)$');
final RegExp _numberedLine = RegExp(r'^\s*(\d+)[.)]\s+(.+)$');
final RegExp _inlineToken = RegExp(
  r'(\*\*[^*\n]+\*\*|`[^`\n]+`|\[[^\]\n]+\]\(https://[^)\s]+\))',
);
final RegExp _inlineLink = RegExp(r'^\[([^\]]+)\]\((https://[^)]+)\)$');

/// Single-entry memo for [SafeMarkdownText.sanitize]. A streaming reply
/// re-renders the same text several times per notify (multiple builds per
/// frame), and sanitizing is six full-string regex passes.
String? _sanitizeCacheKey;
String? _sanitizeCacheValue;

/// Renders the small Markdown subset useful in local-model answers.
///
/// Raw HTML, routing/thinking tags, and images are removed. Only explicit
/// HTTPS Markdown links are interactive; every other link target is stripped.
class SafeMarkdownText extends StatefulWidget {
  const SafeMarkdownText({
    super.key,
    required this.text,
    this.showImages = true,
    this.codeFontFamily = 'monospace',
  });

  final String text;
  final bool showImages;
  final String codeFontFamily; // FinnAI Code passes its bundled monospace.

  /// Full Markdown parses across all instances; tests assert what a stream
  /// costs (a reply used to re-parse whole on every build).
  @visibleForTesting
  static int debugParseCount = 0;

  /// How long the screen may trail a streaming answer (exposed for tests).
  @visibleForTesting
  static const Duration reparseDelay = Duration(milliseconds: 48);

  /// The largest growth that may be deferred; anything bigger re-parses at once.
  @visibleForTesting
  static const int maxDeferredGrowth = 192;

  static String sanitize(String source) {
    if (identical(source, _sanitizeCacheKey)) return _sanitizeCacheValue!;
    var value = source
        .replaceAll(_thinkingBlock, '')
        .replaceAll(_unterminatedThinking, '')
        .replaceAll(_tierMarker, '');
    value = value
        .replaceAllMapped(_mdImage, (match) {
          final uri = Uri.tryParse(match.group(2) ?? '');
          return uri?.scheme == 'https' && uri?.host.isNotEmpty == true
              ? match.group(0)!
              : (match.group(1) ?? '');
        })
        .replaceAllMapped(_mdLink, (match) {
          final uri = Uri.tryParse(match.group(2) ?? '');
          return uri?.scheme == 'https' && uri?.host.isNotEmpty == true
              ? match.group(0)!
              : match.group(1) ?? '';
        })
        .replaceAll(_htmlTag, '')
        .replaceAll(_danglingTag, '');
    final result = value.trim();
    _sanitizeCacheKey = source;
    _sanitizeCacheValue = result;
    return result;
  }

  @override
  State<SafeMarkdownText> createState() => SafeMarkdownTextState();
}

/// Everything the rendered form of a reply depends on besides its own text.
/// A change in any of these forces a full re-parse, because the cached
/// widgets baked in the old values.
@immutable
class _RenderInputs {
  const _RenderInputs({
    required this.isDark,
    required this.showImages,
    required this.bodyLarge,
    required this.primary,
  });

  final bool isDark;
  final bool showImages;
  final TextStyle? bodyLarge;
  final Color primary;

  @override
  bool operator ==(Object other) =>
      other is _RenderInputs &&
      other.isDark == isDark &&
      other.showImages == showImages &&
      other.bodyLarge == bodyLarge &&
      other.primary == primary;

  @override
  int get hashCode => Object.hash(isDark, showImages, bodyLarge, primary);
}

class SafeMarkdownTextState extends State<SafeMarkdownText> {
  final List<TapGestureRecognizer> _recognizers = [];

  // --- Incremental parse guard -------------------------------------------------
  //
  // The controller notifies at up to 60 Hz and the shell rebuilds several
  // times per notify, so a streaming answer used to re-run the whole parse
  // (six regex passes plus a per-line classification of every line so far) on
  // every one of those builds. The guard reuses the previous render only when
  // deferring is provably safe: the incoming text is a *pure extension* of what
  // is already on screen and the growth is small.
  //
  // Everything else re-parses immediately: first paint, a new turn (the text is
  // replaced rather than extended, including the empty string a turn starts
  // with), a jump larger than [kMaxDeferredGrowth], and any change of
  // brightness, theme style, link colour, or `showImages`. Because that last
  // group is exactly what determines the rendered text — and therefore the
  // semantics TalkBack reads off the rendered `Text` widgets — those changes
  // can never be deferred.
  //
  // A deferred render can never outlive the stream: [_scheduleReparse] ends the
  // window by setting [_forceReparse], which [_canReuseRender] treats as an
  // unconditional refusal. The screen therefore trails the token buffer by at
  // most [SafeMarkdownText.reparseDelay] plus the frame the parse lands in, and
  // any build after the window renders exactly.
  //
  // The decision is deliberately *not* made against `DateTime.now()`. This file
  // previously compared the age of the last parse against the window, which
  // made the behaviour depend on real elapsed time, untestable under the widget
  // test clock, and — because the trailing parse re-entered `build` and
  // re-evaluated the very same conditions — able to defer itself indefinitely
  // and strand the tail of an answer. Structural enforcement cannot fail that
  // way.

  String? _renderedSource;
  List<Widget>? _renderedBlocks;
  _RenderInputs? _renderedInputs;
  bool _forceReparse = false;
  Timer? _pendingReparse;

  /// True while the tree is showing a render that trails [widget.text].
  /// [kReparseDelay] plus a frame is the hard upper bound on that.
  @visibleForTesting
  bool get isRenderDeferred => _pendingReparse != null;

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void didUpdateWidget(SafeMarkdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new turn reuses this element, so the previous answer's first line must
    // not be mistaken for an extension of the new one.
    if (oldWidget.text != widget.text &&
        !widget.text.startsWith(oldWidget.text)) {
      _invalidateRender();
    }
  }

  void _invalidateRender() {
    _renderedSource = null;
    _renderedBlocks = null;
    _renderedInputs = null;
    _forceReparse = false;
    _pendingReparse?.cancel();
    _pendingReparse = null;
  }

  /// Queues the trailing parse that ends a deferral. The flag makes the next
  /// parse unconditional, so it cannot re-defer and lose the final tokens.
  void _scheduleReparse() {
    _pendingReparse ??= Timer(SafeMarkdownText.reparseDelay, () {
      _pendingReparse = null;
      _forceReparse = true;
      if (!mounted) return;
      setState(() {});
    });
  }

  bool _canReuseRender(_RenderInputs inputs) {
    final source = _renderedSource;
    final blocks = _renderedBlocks;
    if (source == null || blocks == null) return false;
    // A deferred render is already outstanding, so the newest text is owed a
    // full parse; reusing here is what strands the tail of an answer.
    if (_forceReparse) return false;
    if (_renderedInputs != inputs) return false;
    final text = widget.text;
    if (text.length < source.length) return false;
    // Pure extension only: a rewritten or re-generated answer is never treated
    // as a continuation of what is on screen.
    if (!text.startsWith(source)) return false;
    return text.length - source.length <= SafeMarkdownText.maxDeferredGrowth;
  }

  @override
  void dispose() {
    _pendingReparse?.cancel();
    _pendingReparse = null;
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    final theme = Theme.of(context);
    final inputs = _RenderInputs(
      isDark: isDark,
      showImages: widget.showImages,
      bodyLarge: theme.textTheme.bodyLarge,
      primary: theme.colorScheme.primary,
    );

    final cached = _renderedBlocks;
    if (cached != null && _canReuseRender(inputs)) {
      _scheduleReparse();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cached,
      );
    }

    _pendingReparse?.cancel();
    _pendingReparse = null;
    _forceReparse = false;
    SafeMarkdownText.debugParseCount++;
    _disposeRecognizers();
    final fallback = const TextStyle(fontSize: 16, height: 1.25);
    final base = (theme.textTheme.bodyLarge ?? fallback).copyWith(
      fontSize: 16,
      height: 1.25,
      letterSpacing: -0.12,
      color: FluxColors.inkOf(context),
    );

    final rawBlocks = SafeMarkdownText.sanitize(widget.text).split('\n');
    final widgets = <Widget>[];

    var inCodeBlock = false;
    final codeBuffer = StringBuffer();
    String? codeLang;

    for (var index = 0; index < rawBlocks.length; index++) {
      final line = rawBlocks[index];
      if (line.trim().startsWith('```')) {
        if (inCodeBlock) {
          widgets.add(_buildCodeBlock(
              context, codeBuffer.toString().trim(), codeLang, isDark));
          codeBuffer.clear();
          codeLang = null;
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
          final tag = line.trim().substring(3).trim();
          codeLang = tag.isNotEmpty ? tag : null;
        }
        continue;
      }

      if (inCodeBlock) {
        codeBuffer.writeln(line);
        continue;
      }

      if (line.trim().isEmpty) {
        // A run of blank lines is one paragraph break, none before the first.
        if (widgets.isNotEmpty && widgets.last is! SizedBox) {
          widgets.add(const SizedBox(height: 10));
        }
        continue;
      }

      // 1. Markdown Images ![alt](https://url)
      final imgMatch = _imageLine.firstMatch(line.trim());
      if (imgMatch != null && widget.showImages) {
        final alt = imgMatch.group(1) ?? '';
        final url = imgMatch.group(2)!;
        widgets.add(_buildWebImageCard(context, url, alt, isDark));
        continue;
      }

      // 2. Blockquotes / Siri Callout Cards (> text)
      final quoteMatch = _quoteLine.firstMatch(line);
      if (quoteMatch != null) {
        widgets.add(
            _buildCalloutCard(context, quoteMatch.group(1)!, base, isDark));
        continue;
      }

      // 3. Key-Value Summary Pill / Spec pair (e.g. "**Battery**: 5000 mAh" or "**Release**: 2026")
      final kvMatch = _keyValueLine.firstMatch(line);
      if (kvMatch != null) {
        widgets.add(_buildKeyValueChip(
            context, kvMatch.group(1)!, kvMatch.group(2)!, base, isDark));
        continue;
      }

      // 4. Standard Line with Siri Editorial Polish
      widgets.add(_line(context, line, base, index == 0, isDark));
    }

    // Flush any open code block
    if (inCodeBlock && codeBuffer.isNotEmpty) {
      widgets.add(_buildCodeBlock(
          context, codeBuffer.toString().trim(), codeLang, isDark));
    }

    _renderedSource = widget.text;
    _renderedBlocks = widgets;
    _renderedInputs = inputs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  Widget _buildWebImageCard(
      BuildContext context, String url, String caption, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FluxRadius.md),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : const Color(0xFFEBEBF0),
            borderRadius: BorderRadius.circular(FluxRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: 800,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return SizedBox(
                    height: 140,
                    child: Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: FluxColors.mutedOf(context),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: Text(
                    caption,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FluxColors.mutedOf(context),
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalloutCard(
      BuildContext context, String content, TextStyle base, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1E) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(FluxRadius.sm),
        border: Border(
          left: BorderSide(
            color: isDark ? Colors.white70 : Colors.black87,
            width: 3.5,
          ),
        ),
      ),
      child: Text.rich(
        _inline(
          context,
          content,
          base.copyWith(
            fontStyle: FontStyle.italic,
            color: FluxColors.inkOf(context).withValues(alpha: 0.95),
            fontSize: 14.5,
          ),
        ),
      ),
    );
  }

  Widget _buildKeyValueChip(BuildContext context, String key, String value,
      TextStyle base, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF222226) : const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              key,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FluxColors.inkOf(context),
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              _inline(context, value, base.copyWith(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(
      BuildContext context, String code, String? lang, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151518) : const Color(0xFFECECEF),
        borderRadius: BorderRadius.circular(FluxRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lang != null && lang.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                lang.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: FluxColors.mutedOf(context),
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              code,
              style: TextStyle(
                fontFamily: widget.codeFontFamily,
                fontSize: 13,
                height: 1.42,
                color: FluxColors.inkOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String line, TextStyle base, bool isFirst,
      bool isDark) {
    final heading = _headingLine.firstMatch(line);
    final bullet = _bulletLine.firstMatch(line);
    final numbered = _numberedLine.firstMatch(line);

    if (heading != null) {
      final level = heading.group(1)!.length;
      final fontSize = switch (level) {
        1 => 28.0,
        2 => 20.0,
        _ => 16.0,
      };
      final weight = switch (level) {
        1 => FontWeight.w700,
        2 => FontWeight.w600,
        _ => FontWeight.w600,
      };
      final letterSpacing = switch (level) {
        1 => -0.5,
        2 => -0.3,
        _ => -0.2,
      };
      final fontFamily = level == 1 ? 'serif' : null;

      return Padding(
        padding: EdgeInsets.only(top: isFirst ? 0 : 14, bottom: 6),
        child: Text.rich(
          _inline(
            context,
            heading.group(2)!,
            base.copyWith(
              fontFamily: fontFamily,
              fontSize: fontSize,
              fontWeight: weight,
              letterSpacing: letterSpacing,
              height: 1.22,
            ),
          ),
        ),
      );
    }

    if (bullet != null || numbered != null) {
      final isBullet = bullet != null;
      final content = bullet?.group(1) ?? numbered!.group(2)!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 18,
              child: isBullet
                  ? Padding(
                      padding: const EdgeInsets.only(top: 7.5),
                      child: Container(
                        width: 5.5,
                        height: 5.5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: FluxColors.mutedOf(context)
                              .withValues(alpha: 0.75),
                        ),
                      ),
                    )
                  : Text(
                      '${numbered!.group(1)}.',
                      style: base.copyWith(
                        fontWeight: FontWeight.w600,
                        color: FluxColors.mutedOf(context),
                      ),
                    ),
            ),
            const SizedBox(width: 4),
            Expanded(child: Text.rich(_inline(context, content, base))),
          ],
        ),
      );
    }

    // Editorial Lead paragraph styling for the opening statement
    final style = (isFirst && line.length > 20 && !line.startsWith('**'))
        ? base.copyWith(
            fontSize: 16.5,
            height: 1.5,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.15,
          )
        : base;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text.rich(_inline(context, line, style)),
    );
  }

  TextSpan _inline(BuildContext context, String value, TextStyle base) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _inlineToken.allMatches(value)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: _plain(value.substring(cursor, match.start))));
      }
      final token = match.group(0)!;
      if (token.startsWith('[')) {
        final link = _inlineLink.firstMatch(token)!;
        final uri = Uri.parse(link.group(2)!);
        final recognizer = TapGestureRecognizer()
          ..onTap = () => launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: link.group(1)!,
            style: base.copyWith(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
              decorationColor: Theme.of(context).colorScheme.primary,
            ),
            recognizer: recognizer,
          ),
        );
      } else if (token.startsWith('**')) {
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
              fontFamily: widget.codeFontFamily,
              fontSize: (base.fontSize ?? 14) * 0.92,
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
