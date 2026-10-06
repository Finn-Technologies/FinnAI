import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Window-size classes shared by FinnAI and FinnAI Code, so a phone, a tablet
/// and a desktop window all make the same layout decisions from one place.
///
/// - **compact** (under [compactBreakpoint]): a phone. The sidebar slides over
///   the chat and is 322/420 of the width, as designed.
/// - **medium** (up to [dockBreakpoint]): a tablet in portrait or a narrow
///   window. The sidebar still slides over the chat, but keeps a fixed width
///   instead of growing with the screen.
/// - **expanded** (from [dockBreakpoint]): a landscape tablet or a desktop
///   window. The sidebar is docked beside the chat and always visible.
abstract final class FinnLayout {
  static const double compactBreakpoint = 600;
  static const double dockBreakpoint = 900;

  /// Width of the sidebar when it is docked, and its cap when it slides over.
  static const double dockWidth = 320;

  /// The narrowest window the app lays out well in. The Linux runner enforces
  /// it as the window's minimum size.
  static const double minWindowWidth = 360;
  static const double minWindowHeight = 480;

  static bool isDocked(double width) => width >= dockBreakpoint;

  /// Bottom padding that optically centres a one-line Geist field in
  /// a pill. The font carries more space above its letters than below, and
  /// how much shows depends on the text stack: measured on the Linux window
  /// (FreeType) the line box sat ~4.5px low; on Android (1080x2400 emulator)
  /// it already sits ~3.5dp higher and needs almost no lift.
  static double get fieldTextLift =>
      defaultTargetPlatform == TargetPlatform.linux ? 9 : 2;

  /// The width left for the chat once a docked sidebar has taken its share.
  static double bodyWidth(double width) =>
      isDocked(width) ? width - dockWidth : width;

  /// The most a wide window scales the phone design's vertical offsets.
  ///
  /// The phone layout hangs headers 70 px down and a greeting 125 px down so
  /// they clear a status bar and a thumb. On a landscape window those same
  /// offsets are dead space above a short canvas, so from [dockBreakpoint] up
  /// they are capped to this fraction of the design (enough to clear the title bar).
  static const double wideScaleY = .66;

  /// The factor the phone design's vertical offsets are multiplied by in a
  /// viewport [width] x [height]: proportional to the height on a phone, and
  /// capped at [wideCap] (default [wideScaleY]) once the window is wide. A
  /// sidebar passes a higher cap: its icon row has a fixed height, so squeezing
  /// its offsets further than this makes the rows overlap.
  static double scaleY(
    double height,
    double width, {
    double base = 912,
    double min = .72,
    double max = 1.2,
    double wideCap = wideScaleY,
  }) {
    final scale = (height / base).clamp(min, max);
    return isDocked(width) ? math.min(scale, wideCap) : scale;
  }

  /// The sidebar's width at a window [width].
  static double sidebarWidth(double width) {
    if (isDocked(width)) return dockWidth;
    if (width < compactBreakpoint) return width * (322 / 420);
    return math.min(dockWidth + 20, width * .6);
  }
}
