import 'package:flutter/animation.dart';

/// The app's single motion language.
///
/// The audit found three page motions and three modal motions with different
/// durations and curves, so the same gesture felt like a different app on
/// different screens. There is now exactly one duration and one curve per kind
/// of transition, named here, and every shared widget routes through them. Any
/// screen-level motion that is not one of these — a long-press preview, a
/// progress ring — is a bug, and the call site belongs in the handoff list.
abstract final class FluxMotion {
  /// Push/pop of a secondary page (Settings, You, Creations, Flows).
  static const Duration pageDuration = Duration(milliseconds: 320);
  static const Duration pageReverseDuration = Duration(milliseconds: 260);
  static const Curve pageCurve = Curves.easeOutCubic;
  static const Curve pageReverseCurve = Curves.easeInCubic;

  /// Presentation of a modal surface (context menu, bottom sheet, dialog).
  static const Duration modalDuration = Duration(milliseconds: 220);
  static const Curve modalCurve = Curves.easeOutCubic;
  static const Curve modalReverseCurve = Curves.easeInCubic;

  /// A control becoming the surface it opens: the "+" growing into its
  /// sheet, a create button into its chooser. Opens on a curve that ends
  /// with a hair of overshoot, so the panel lands rather than stops; closes
  /// quicker, accelerating back into the control.
  static const Duration morphDuration = Duration(milliseconds: 460);
  static const Duration morphReverseDuration = Duration(milliseconds: 300);
  static const Curve morphCurve = Cubic(.2, .9, .28, 1.035);
  static const Curve morphReverseCurve = Cubic(.4, 0, .7, .4);

  /// In-place content change: a disclosure opening, a chevron turning.
  static const Duration revealDuration = Duration(milliseconds: 180);
  static const Curve revealCurve = Curves.easeOutCubic;

  /// Something arriving that should be noticed: a sheet rising, a message
  /// landing. Pairs with [springCurve] when it may overshoot a little.
  static const Duration emphasisDuration = Duration(milliseconds: 400);
  static const Curve springCurve = ElasticOutCurve(.85);

  /// The voice panel giving the chat back: the transcript and the composer
  /// crossfade as voice recedes, in both directions. Named because two files
  /// carried the same 650ms by hand and had to be kept in step.
  static const Duration recedeDuration = Duration(milliseconds: 650);

  /// The breathing of the "Finn is generating" row, while there is still
  /// nothing to read. One loop; long on purpose, because a short loop reads
  /// as a spinner.
  static const Duration presencePulse = Duration(milliseconds: 1700);

  /// Press feedback. Shared by every tappable surface so a thumb gets the same
  /// answer everywhere.
  static const Duration pressIn = Duration(milliseconds: 120);
  static const Duration pressOut = Duration(milliseconds: 240);
  static const Curve pressCurve = Curves.easeOutCubic;
  static const Curve pressReturnCurve = Curves.easeOutBack;

  /// Minimum touch target, in logical pixels. Everything tappable in
  /// `lib/src/shared/widgets` reserves at least this much hit area even when
  /// the painted control is smaller.
  static const double minTapTarget = 48;
}
