import 'package:flutter/material.dart';

import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';

/// Pastel colors shared by creation tiles, mini-app chrome and widgets.
///
/// The Figma used one green gradient across the whole surface. FinnAI's
/// `AmbientBackground` is a flat canvas instead, so the colour that distinguishes
/// creations comes from these per-accent pastels rather than from the backdrop.
abstract final class CreationPalette {
  static Color pastel(MiniAppAccent accent) => switch (accent) {
        MiniAppAccent.mint => const Color(0xFFBDECCB),
        MiniAppAccent.blue => const Color(0xFFB9DFF1),
        MiniAppAccent.lime => const Color(0xFFDFF3B0),
        MiniAppAccent.amber => const Color(0xFFFCE3B4),
        MiniAppAccent.rose => const Color(0xFFF8C6CB),
        MiniAppAccent.violet => const Color(0xFFE5D4F5),
        MiniAppAccent.sky => const Color(0xFFC9E6F5),
      };

  /// The accent a creation uses when its spec does not name one.
  static MiniAppAccent defaultAccentFor(CreationKind kind) => switch (kind) {
        CreationKind.app => MiniAppAccent.mint,
        CreationKind.widget => MiniAppAccent.blue,
        CreationKind.presentation => MiniAppAccent.violet,
      };

  /// Tile background for a gallery item, matching the round tiles in the design.
  static Color tileFor(CreationKind kind) => pastel(defaultAccentFor(kind));

  /// Icon colour for text and glyphs drawn on a pastel surface.
  static const Color onPastel = Color(0xFF121212);

  /// Muted variant of [onPastel] for captions on a pastel surface.
  static const Color onPastelMuted = Color(0xFF4A4A48);
}
