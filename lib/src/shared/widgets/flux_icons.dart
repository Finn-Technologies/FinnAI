import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// The app's icon set: Phosphor, fill weight, everywhere. One style — the same
/// 256-unit grid, rounded corners and weight — so no screen mixes outline and
/// filled glyphs. A selected or toggled state is shown with colour or a
/// backing, never by swapping an outline for a fill.
abstract final class FluxIcons {
  // Bare strokes (plus, close, menu) take the bold weight: their fill glyphs
  // sit inside a filled square, which reads as a different icon. Bold is the
  // same solid weight as the fill set, with no box.
  static const add = PhosphorIconsBold.plus;
  static const close = PhosphorIconsBold.x;
  static const arrowUp01 = PhosphorIconsFill.caretUp;
  static const arrowUp02 = PhosphorIconsFill.arrowUp;
  static const menu = PhosphorIconsBold.list;
  static const copy = PhosphorIconsFill.copy;
  static const exchange = PhosphorIconsFill.arrowsLeftRight;
  static const internet = PhosphorIconsFill.globe;
  static const sad = PhosphorIconsFill.smileySad;
  static const canvas = PhosphorIconsFill.paintBrush;
  static const you = PhosphorIconsFill.smiley;
  static const flows = PhosphorIconsFill.bookOpenText;
  static const chip = PhosphorIconsFill.cpu;
  static const settings = PhosphorIconsFill.gearSix;
  static const edit = PhosphorIconsFill.pencilSimple;
  static const security = PhosphorIconsFill.shieldWarning;
  static const magic = PhosphorIconsFill.sparkle;
  static const lock = PhosphorIconsFill.lock;
  static const download = PhosphorIconsFill.downloadSimple;
  static const delete = PhosphorIconsFill.trash;
  static const translate = PhosphorIconsFill.translate;
  static const voiceId = PhosphorIconsFill.userSound;
  static const speed = PhosphorIconsFill.gauge;
  static const subtitle = PhosphorIconsFill.closedCaptioning;
  static const bluetooth = PhosphorIconsFill.bluetooth;
  static const robot = PhosphorIconsFill.robot;
  static const leaf = PhosphorIconsFill.leaf;
  static const game = PhosphorIconsFill.gameController;
  static const refresh = PhosphorIconsFill.arrowClockwise;
  static const loading = PhosphorIconsFill.spinnerGap;
  static const check = PhosphorIconsFill.checkCircle;
  static const flag = PhosphorIconsFill.flag;
  static const mic = PhosphorIconsFill.microphone;
  static const micOff = PhosphorIconsFill.microphoneSlash;
  static const voiceWaveform = PhosphorIconsFill.waveform;
  static const cpu = PhosphorIconsFill.cpu;
  static const error = PhosphorIconsFill.warningCircle;
  static const info = PhosphorIconsFill.info;
  static const moreHorizontal = PhosphorIconsFill.dotsThree;
  static const arrowRight01 = PhosphorIconsFill.caretRight;
  static const arrowRight02 = PhosphorIconsFill.arrowRight;
  static const cloudOff = PhosphorIconsFill.cloudSlash;
  static const image = PhosphorIconsFill.image;
  static const brokenImage = PhosphorIconsFill.imageBroken;
  static const note = PhosphorIconsFill.note;
  static const sourceCode = PhosphorIconsFill.codeBlock;
  static const education = PhosphorIconsFill.graduationCap;
  static const task = PhosphorIconsFill.clipboardText;
  static const search = PhosphorIconsFill.magnifyingGlass;
  static const alarm = PhosphorIconsFill.alarm;
  static const timer = PhosphorIconsFill.timer;
  static const flashlight = PhosphorIconsFill.flashlight;
  static const volume = PhosphorIconsFill.speakerHigh;
  static const wifi = PhosphorIconsFill.wifiHigh;
  static const calendar = PhosphorIconsFill.calendarBlank;
  static const navigation = PhosphorIconsFill.navigationArrow;
  static const camera = PhosphorIconsFill.camera;
  static const battery = PhosphorIconsFill.batteryFull;
  static const moon = PhosphorIconsFill.moon;
  static const sun = PhosphorIconsFill.sun;
}

class FluxIcon extends StatelessWidget {
  const FluxIcon({
    super.key,
    required this.icon,
    this.size = 24,
    this.color,
  });

  /// A filled glyph from [FluxIcons] (Phosphor, fill weight). One style app
  /// wide: selection is shown with colour or a backing, never by swapping an
  /// outline for a fill.
  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Icon(
        icon,
        // Phosphor's fill glyphs sit a little heavier than the stroke set they
        // replace; 92% keeps the optical size every caller was tuned for.
        size: size * .92,
        color: color ??
            DefaultTextStyle.of(context).style.color ??
            FluxColors.inkOf(context),
      );
}
