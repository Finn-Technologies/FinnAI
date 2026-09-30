import 'dart:math' as math;

/// A closed set of deck looks. A model may pick one by name; it can never
/// supply a colour, so every generated deck is one of these five.
enum DeckTheme {
  paper(
    background: 0xFFFAF8F3,
    text: 0xFF1B1B1B,
    muted: 0xFF6B6B66,
    accent: 0xFF2F6F5E,
  ),
  midnight(
    background: 0xFF101522,
    text: 0xFFF2F4FA,
    muted: 0xFF9AA3B8,
    accent: 0xFF7DFFCD,
  ),
  mint(
    background: 0xFFE6F7EF,
    text: 0xFF0F2A21,
    muted: 0xFF4C6B5E,
    accent: 0xFF1F9E73,
  ),
  sunset(
    background: 0xFFFFEFE2,
    text: 0xFF3A1F12,
    muted: 0xFF8A5A43,
    accent: 0xFFE2672A,
  ),
  mono(
    background: 0xFF111111,
    text: 0xFFFFFFFF,
    muted: 0xFFA0A0A0,
    accent: 0xFFFFFFFF,
  );

  const DeckTheme({
    required this.background,
    required this.text,
    required this.muted,
    required this.accent,
  });

  /// ARGB colours.
  final int background;
  final int text;
  final int muted;
  final int accent;

  static const String names = 'paper, midnight, mint, sunset, mono';

  /// Tolerant parse: anything unknown is the default, never an error.
  static DeckTheme parse(Object? raw) {
    final wanted = raw?.toString().trim().toLowerCase() ?? '';
    for (final theme in DeckTheme.values) {
      if (theme.name == wanted) return theme;
    }
    return DeckTheme.paper;
  }

  /// `RRGGBB` for OOXML.
  static String hex(int argb) =>
      (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  /// WCAG contrast ratio between two ARGB colours.
  static double contrast(int a, int b) {
    double channel(int v) {
      final s = v / 255;
      return s <= 0.03928
          ? s / 12.92
          : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    double luminance(int c) =>
        0.2126 * channel((c >> 16) & 0xFF) +
        0.7152 * channel((c >> 8) & 0xFF) +
        0.0722 * channel(c & 0xFF);

    final la = luminance(a);
    final lb = luminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }
}

/// How one slide is laid out.
enum DeckLayout {
  /// Big centred title with a line of subtitle: the opening slide.
  title,

  /// A heading and up to six bullets: the workhorse.
  bullets,

  /// A big heading that marks a new part of the talk.
  section,

  /// One large quotation (the first bullet) with the title as its source.
  quote;

  static const String names = 'title, bullets, section, quote';

  static DeckLayout? tryParse(Object? raw) {
    final wanted = raw?.toString().trim().toLowerCase() ?? '';
    for (final layout in DeckLayout.values) {
      if (layout.name == wanted) return layout;
    }
    return null;
  }
}
