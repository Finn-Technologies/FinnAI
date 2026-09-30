import 'package:flutter/material.dart';

import 'package:finn_ai/src/features/creations/spec/deck_spec.dart';
import 'package:finn_ai/src/features/creations/spec/deck_theme.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// One slide, drawn in its deck's theme and its own layout.
///
/// The viewer and any future thumbnail share this, and [PptxWriter] mirrors the
/// same theme colours and layouts, so what is reviewed on the phone is what is
/// exported.
class DeckSlideCard extends StatelessWidget {
  const DeckSlideCard({
    super.key,
    required this.slide,
    required this.theme,
    required this.index,
  });

  final DeckSlide slide;
  final DeckTheme theme;
  final int index;

  @override
  Widget build(BuildContext context) {
    final layout = slide.layoutAt(index);
    final background = Color(theme.background);
    final text = Color(theme.text);
    final muted = Color(theme.muted);
    final accent = Color(theme.accent);
    final textTheme = Theme.of(context).textTheme;
    final isHeading =
        layout == DeckLayout.title || layout == DeckLayout.section;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          padding: EdgeInsets.all(isHeading ? 26 : 22),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(FluxRadius.card),
            border: Border.all(color: muted.withValues(alpha: .25)),
          ),
          child: switch (layout) {
            DeckLayout.quote => _quote(textTheme, text, muted, accent),
            DeckLayout.section => _heading(
                textTheme,
                text,
                muted,
                accent,
                big: true,
              ),
            DeckLayout.title => _heading(
                textTheme,
                text,
                muted,
                accent,
                big: false,
              ),
            DeckLayout.bullets => _bullets(textTheme, text, muted, accent),
          },
        ),
      ),
    );
  }

  Widget _bar(Color accent) => Container(
        width: 34,
        height: 4,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(FluxRadius.pill),
        ),
      );

  Widget _heading(
    TextTheme textTheme,
    Color text,
    Color muted,
    Color accent, {
    required bool big,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _bar(accent),
          const SizedBox(height: 14),
          Text(
            slide.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: (big ? textTheme.displaySmall : textTheme.headlineLarge)
                ?.copyWith(height: 1.15, color: big ? accent : text),
          ),
          if (slide.bullets.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              slide.bullets.take(2).join('\n'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyLarge?.copyWith(color: muted, height: 1.35),
            ),
          ],
        ],
      );

  Widget _quote(TextTheme textTheme, Color text, Color muted, Color accent) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '“',
            style: textTheme.displayLarge?.copyWith(color: accent, height: .6),
          ),
          Flexible(
            child: Text(
              slide.bullets.isEmpty ? slide.title : slide.bullets.first,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleLarge?.copyWith(
                color: text,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
            ),
          ),
          if (slide.bullets.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '— ${slide.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ],
        ],
      );

  Widget _bullets(TextTheme textTheme, Color text, Color muted, Color accent) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _bar(accent),
          const SizedBox(height: 14),
          Text(
            slide.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleLarge?.copyWith(height: 1.2, color: text),
          ),
          if (slide.bullets.isNotEmpty) ...[
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final bullet in slide.bullets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                bullet,
                                style: textTheme.bodyMedium?.copyWith(
                                  height: 1.35,
                                  color: text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
}
