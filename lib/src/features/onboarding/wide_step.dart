import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/onboarding/artwork_card.dart';
import 'package:finn_ai/src/shared/widgets/finn_window_frame.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// Whether onboarding has the room for the two-pane layout: artwork on the
/// left, words and controls on the right. A desktop window or a tablet fits it;
/// a phone, even sideways (its height is under 440), keeps the single card.
bool wideStepFits(BoxConstraints constraints) =>
    constraints.maxWidth >= 720 && constraints.maxHeight >= 440;

/// How far in from each side the welcome screen's glow card sits: the phone's
/// 20, or on a wide window a card-sized 560 centred.
double welcomeGlowInset(BoxConstraints constraints) =>
    wideStepFits(constraints) ? (constraints.maxWidth - 560) / 2 : 20;

/// The glow card's corner radius: the phone design's 25, or the window's own
/// on a wide one, so the card sits in the window the way the artwork does.
double welcomeGlowRadius(BoxConstraints constraints) =>
    wideStepFits(constraints) ? FinnWindowFrame.cornerRadius : 25;

/// The one vertical scale every first-run surface applies to the phone
/// design's geometry.
///
/// The welcome card and the step it grows into scaled by the same
/// `avail / 912` factor but clamped it differently (.4 vs .6), so on a short
/// landscape screen the morph began from a 42px card and landed on a 72px
/// one — the design's "grow into the step" read as a jump in size. Both now
/// clamp here; the morph keeps the smaller floor because it is drawn over
/// the black and has nothing to protect.
double stepScale(double avail, {bool morph = false}) =>
    (avail / 912).clamp(morph ? .4 : .6, 1.0);

/// One onboarding step laid out for a wide window.
///
/// The step's artwork fills a rounded pane on the left, with the same radius on
/// every corner and the title still on the image as on a phone. The copy and the
/// controls sit in a column on the right, so the eye goes picture, then words, then the action, and the buttons
/// are where a mouse already is.
///
/// It takes exactly what the phone card takes, so a step does not know which of
/// the two it is drawing. [body] is given a bounded height: a body that scrolls
/// its own copy (consent) keeps working, and one that does not is wrapped in a
/// scroll view when [scrollBody] says so.
class WideStepLayout extends StatelessWidget {
  const WideStepLayout({
    super.key,
    required this.artwork,
    required this.title,
    required this.body,
    this.scrollBody = true,
    this.twoLineTitle = false,
    this.progress = 0,
    this.backEnabled = true,
    this.onBack,
    this.onNext,
    this.footer,
    this.footerHint,
  });

  final String artwork;
  final String title;
  final Widget? body;
  final bool scrollBody;
  final bool twoLineTitle;

  /// Filled quarters of the step bar; 0 on a step that carries none.
  final int progress;
  final bool backEnabled;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  /// Replaces the Back / Next row (the last step ends on one action).
  final Widget? footer;

  /// Shown above the controls while the step cannot advance yet.
  final String? footerHint;

  static const double _columnWidth = 500;

  @override
  Widget build(BuildContext context) {
    // The window's title bar runs over the top of the screen; stay clear of it.
    final topInset = MediaQuery.paddingOf(context).top;
    final body = this.body;
    final hint = footerHint;
    final canNext = footer == null && onNext != null;
    final canBack = footer == null && backEnabled && onBack != null;
    return ColoredBox(
      color: FluxColors.cardOf(context),
      // Enter and the arrow keys walk the wizard, as in any desktop installer.
      child: _StepKeys(
        keys: {
          LogicalKeyboardKey.enter: canNext ? onNext : null,
          LogicalKeyboardKey.numpadEnter: canNext ? onNext : null,
          LogicalKeyboardKey.arrowRight: canNext ? onNext : null,
          LogicalKeyboardKey.arrowLeft: canBack ? onBack : null,
          LogicalKeyboardKey.escape: canBack ? onBack : null,
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20 + topInset,
            20,
            20,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 11,
                // The title stays on the image, in the phone card's type.
                child: OnboardingArtworkCard(
                  artwork: artwork,
                  title: title,
                  twoLineTitle: twoLineTitle,
                  radius: FinnWindowFrame.cornerRadius,
                ),
              ),
              Expanded(
                flex: 13,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _columnWidth),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(40, 28, 40, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 28),
                          Expanded(
                            child: body == null
                                ? const SizedBox.shrink()
                                : scrollBody
                                    ? Align(
                                        alignment: Alignment.centerLeft,
                                        child: SingleChildScrollView(
                                          child: body,
                                        ),
                                      )
                                    : body,
                          ),
                          if (hint != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                hint,
                                style: TextStyle(
                                  fontFamily: 'Geist',
                                  fontSize: 14,
                                  height: 1.2,
                                  color: FluxColors.secondaryInkOf(context),
                                ),
                              ),
                            ),
                          footer ??
                              _WideControls(
                                progress: progress,
                                onBack: canBack ? onBack : null,
                                onNext: onNext,
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back and Next as labelled pills with the step bar between them.
class _WideControls extends StatelessWidget {
  const _WideControls({
    required this.progress,
    required this.onBack,
    required this.onNext,
  });

  final int progress;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Row(
      children: [
        _Pill(
          key: const ValueKey('onboarding-back'),
          label: l10n.commonBack,
          onTap: onBack,
          background: FluxColors.tileOf(context),
          foreground: FluxColors.inkOf(context),
        ),
        // The step bar gives way before the buttons do on a narrow column.
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => c.maxWidth < 100
                ? const SizedBox.shrink()
                : Center(child: _Segments(filled: progress)),
          ),
        ),
        _Pill(
          key: const ValueKey('onboarding-next'),
          label: l10n.commonNext,
          onTap: onNext,
          background: FluxColors.actionOf(context),
          foreground: FluxColors.actionInkOf(context),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.onTap,
    required this.background,
    required this.foreground,
  });

  final String label;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : .38,
        child: FluxPressScale(
          enabled: enabled,
          child: MouseRegion(
            cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
            child: Material(
              color: background,
              borderRadius: BorderRadius.circular(40),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(40),
                child: SizedBox(
                  height: 52,
                  width: 104,
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w400,
                        color: foreground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Four segments, [filled] of them solid.
class _Segments extends StatelessWidget {
  const _Segments({required this.filled});

  final int filled;

  @override
  Widget build(BuildContext context) {
    if (filled <= 0) return const SizedBox.shrink();
    final ink = FluxColors.inkOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Container(
            width: 20,
            height: 4,
            decoration: BoxDecoration(
              color: i < filled ? ink : ink.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }
}

/// The welcome screen's call to action where there is no swipe to give: a white
/// pill on the black screen, also reachable with Enter.
class WelcomeStartButton extends StatelessWidget {
  const WelcomeStartButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = L10n.of(context).onboardingGetStarted;
    return _StepKeys(
      keys: {
        LogicalKeyboardKey.enter: onTap,
        LogicalKeyboardKey.numpadEnter: onTap,
      },
      child: Center(
        child: Semantics(
          button: true,
          label: label,
          onTap: onTap,
          excludeSemantics: true,
          child: FluxPressScale(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(40),
                  child: SizedBox(
                    height: 56,
                    width: 200,
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 18,
                          height: 1.2,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Makes Enter do what a step's single full-width button does (the last step's
/// "Start using"), on a window with a keyboard.
class StepEnterKey extends StatelessWidget {
  const StepEnterKey({super.key, required this.onEnter, required this.child});

  final VoidCallback onEnter;
  final Widget child;

  @override
  Widget build(BuildContext context) => _StepKeys(
        keys: {
          LogicalKeyboardKey.enter: onEnter,
          LogicalKeyboardKey.numpadEnter: onEnter,
        },
        child: child,
      );
}

/// Runs [keys] when one of their keys is pressed while this step is on screen,
/// whichever widget happens to hold keyboard focus.
///
/// Focus is the wrong tool here. When one step replaces another in the page
/// view the old step still holds focus while the new one builds, and in a real
/// window the focus was never inside the step at all, so Enter and the arrow
/// keys did nothing until something was clicked. Listening to the keyboard
/// directly does not depend on it.
class _StepKeys extends StatefulWidget {
  const _StepKeys({required this.keys, required this.child});

  /// Null entries are keys this step ignores right now (Next while disabled).
  final Map<LogicalKeyboardKey, VoidCallback?> keys;
  final Widget child;

  @override
  State<_StepKeys> createState() => _StepKeysState();
}

class _StepKeysState extends State<_StepKeys> {
  /// False until the step has had its first frame, so it never acts on the key
  /// press that brought it on screen.
  bool _ready = false;

  /// True for a moment after a key was acted on: the step is about to be
  /// replaced, and a quick second press belongs to its successor.
  Timer? _cooling;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ready = true);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _cooling?.cancel();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted || !_ready || _cooling != null) {
      return false;
    }
    if (!_onScreen()) return false;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      return false;
    }
    // Typing in a field is not navigation.
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus != null &&
        focus.findAncestorWidgetOfExactType<EditableText>() != null) {
      return false;
    }
    final action = widget.keys[event.logicalKey];
    if (action == null) return false;
    _cooling = Timer(const Duration(milliseconds: 450), () => _cooling = null);
    action();
    return true;
  }

  /// A page view leaves the step it just left mounted, off to one side, until
  /// something next lays it out, and its handler would answer first and swallow
  /// the key. Only a step whose middle is inside the window may act.
  bool _onScreen() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final middle = box.localToGlobal(box.size.center(Offset.zero));
    final view = View.of(context);
    final width = view.physicalSize.width / view.devicePixelRatio;
    return middle.dx >= 0 && middle.dx <= width;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
