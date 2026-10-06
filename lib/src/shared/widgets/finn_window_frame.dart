import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/platform/window_chrome.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// The `MaterialApp.builder` every FinnAI app uses: the system-UI overlay style
/// and, on desktop Linux, the window frame.
Widget finnAppBuilder(BuildContext context, Widget? child) =>
    FluxTheme.applySystemUi(
      context,
      FinnWindowFrame(child: child ?? const SizedBox.shrink()),
    );

/// Wraps the whole app in FinnAI's own window chrome on desktop Linux: a title
/// bar with the app name and the window buttons, plus invisible edges to
/// resize from. Everywhere else it is transparent and adds nothing.
///
/// It sits in `MaterialApp.builder`, above the navigator, so it frames every
/// screen (and every pushed page) the same way and the native GTK title bar is
/// not needed. The screen fills the window and runs under the bar, which is
/// transparent: the child's [MediaQuery] top padding is the bar's height, so a
/// screen that keeps clear of a status bar keeps clear of this.
class FinnWindowFrame extends StatelessWidget {
  const FinnWindowFrame({
    super.key,
    required this.child,
    this.chrome,
    this.forceChrome = false,
  });

  final Widget child;

  /// The window to drive; the process-wide one unless a test supplies its own.
  final WindowChrome? chrome;

  /// Draws the chrome even when the runner did not remove the native bar. For
  /// tests and previews.
  final bool forceChrome;

  static const double barHeight = 40;

  /// The window's corner radius, and the radius the app's own large images
  /// share so they read as part of the same window.
  static const double cornerRadius = 14;
  static const double _edge = 5;
  static const double _corner = 12;

  @override
  Widget build(BuildContext context) {
    final window = chrome ?? WindowChrome.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: window.enabled,
      builder: (context, enabled, _) {
        if (!enabled && !forceChrome) return child;
        return ValueListenableBuilder<WindowChromeState>(
          valueListenable: window.state,
          builder: (context, state, _) => ValueListenableBuilder<Brightness?>(
            valueListenable: window.tone,
            builder: (context, _, __) => _framed(context, window, state),
          ),
        );
      },
    );
  }

  Widget _framed(
    BuildContext context,
    WindowChrome window,
    WindowChromeState state,
  ) {
    final media = MediaQuery.of(context);
    // Full screen is the one state with no chrome: F11 brings it back.
    final bar = state.fullscreen ? 0.0 : barHeight;
    // The screen runs under the bar, so the bar has no colour of its own: it is
    // whatever the screen behind it is. The screen is told to keep clear of it
    // the way it keeps clear of a status bar.
    final padding = media.padding.copyWith(
      top: bar > media.padding.top ? bar : media.padding.top,
    );
    final content = MediaQuery(
      data: media.copyWith(
        padding: padding,
        viewPadding: media.viewPadding.copyWith(top: padding.top),
      ),
      child: child,
    );
    final canResize = !state.maximized && !state.fullscreen;
    // Rounded only when the window can be transparent outside the rounding,
    // and never when it fills the screen.
    final round = canResize && (forceChrome || window.transparent.value);
    Widget surface = Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        ),
        Positioned.fill(child: content),
        if (!state.fullscreen)
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: barHeight,
            child: FinnTitleBar(window: window, state: state),
          ),
      ],
    );
    if (round) {
      surface = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cornerRadius),
          border: Border.all(color: FluxColors.lineOf(context), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cornerRadius),
          child: surface,
        ),
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f11): window.toggleFullscreen,
      },
      child: Stack(
        children: [
          Positioned.fill(child: surface),
          if (canResize) ..._resizeEdges(window),
        ],
      ),
    );
  }

  List<Widget> _resizeEdges(WindowChrome window) {
    Widget edge(
      int index,
      MouseCursor cursor, {
      double? left,
      double? top,
      double? right,
      double? bottom,
      double? width,
      double? height,
    }) =>
        Positioned(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          width: width,
          height: height,
          child: MouseRegion(
            cursor: cursor,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                if (event.buttons == kPrimaryButton) window.startResize(index);
              },
            ),
          ),
        );
    return [
      edge(0, SystemMouseCursors.resizeUp,
          left: _corner, right: _corner, top: 0, height: _edge),
      edge(4, SystemMouseCursors.resizeDown,
          left: _corner, right: _corner, bottom: 0, height: _edge),
      edge(6, SystemMouseCursors.resizeLeft,
          left: 0, top: _corner, bottom: _corner, width: _edge),
      edge(2, SystemMouseCursors.resizeRight,
          right: 0, top: _corner, bottom: _corner, width: _edge),
      edge(7, SystemMouseCursors.resizeUpLeft,
          left: 0, top: 0, width: _corner, height: _corner),
      edge(1, SystemMouseCursors.resizeUpRight,
          right: 0, top: 0, width: _corner, height: _corner),
      edge(5, SystemMouseCursors.resizeDownLeft,
          left: 0, bottom: 0, width: _corner, height: _corner),
      edge(3, SystemMouseCursors.resizeDownRight,
          right: 0, bottom: 0, width: _corner, height: _corner),
    ];
  }
}

/// The title bar: the mark and name on the left, which also drag the window
/// (double-click maximises), and the three window buttons on the right.
class FinnTitleBar extends StatelessWidget {
  const FinnTitleBar({super.key, required this.window, required this.state});

  final WindowChrome window;
  final WindowChromeState state;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final tone = window.tone.value;
    final onDark = tone == Brightness.dark;
    final ink = onDark ? Colors.white : FluxColors.inkOf(context);
    final quiet =
        onDark ? const Color(0x99FFFFFF) : FluxColors.secondaryInkOf(context);
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: FinnWindowFrame.barHeight,
        child: DecoratedBox(
          decoration: const BoxDecoration(),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('title-bar-drag'),
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => window.startDrag(),
                  onDoubleTap: window.toggleMaximize,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            width: 20,
                            height: 20,
                            cacheWidth: 40,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox(width: 20, height: 20),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l10n.appBrandFinnAI,
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                            color: state.focused ? ink : quiet,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _CaptionButton(
                key: const ValueKey('window-minimize'),
                label: l10n.windowMinimize,
                glyph: _Glyph.minimize,
                color: ink,
                onTap: window.minimize,
              ),
              _CaptionButton(
                key: const ValueKey('window-maximize'),
                label:
                    state.maximized ? l10n.windowRestore : l10n.windowMaximize,
                glyph: state.maximized ? _Glyph.restore : _Glyph.maximize,
                color: ink,
                onTap: window.toggleMaximize,
              ),
              _CaptionButton(
                key: const ValueKey('window-close'),
                label: l10n.commonClose,
                glyph: _Glyph.close,
                color: ink,
                onTap: window.close,
                danger: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Glyph { minimize, maximize, restore, close }

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    super.key,
    required this.label,
    required this.glyph,
    required this.color,
    required this.onTap,
    this.danger = false,
  });

  final Color color;
  final String label;
  final _Glyph glyph;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ink = widget.color;
    final hoverFill =
        widget.danger ? const Color(0xFFE5484D) : ink.withValues(alpha: .08);
    final glyphColor = _hover && widget.danger ? Colors.white : ink;
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            width: 48,
            height: FinnWindowFrame.barHeight,
            color: _hover ? hoverFill : Colors.transparent,
            child: Center(
              child: CustomPaint(
                size: const Size.square(11),
                painter: _GlyphPainter(widget.glyph, glyphColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final _Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..isAntiAlias = true;
    final s = size.width;
    switch (glyph) {
      case _Glyph.minimize:
        canvas.drawLine(Offset(0, s / 2), Offset(s, s / 2), paint);
      case _Glyph.maximize:
        canvas.drawRect(Rect.fromLTWH(.5, .5, s - 1, s - 1), paint);
      case _Glyph.restore:
        canvas.drawRect(Rect.fromLTWH(.5, 2.5, s - 2.5, s - 2.5), paint);
        final back = Path()
          ..moveTo(2.5, 2.5)
          ..lineTo(2.5, .5)
          ..lineTo(s - .5, .5)
          ..lineTo(s - .5, s - 2.5)
          ..lineTo(s - 2.5, s - 2.5);
        canvas.drawPath(back, paint);
      case _Glyph.close:
        canvas.drawLine(const Offset(0, 0), Offset(s, s), paint);
        canvas.drawLine(Offset(s, 0), Offset(0, s), paint);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}

/// A full-bleed black screen that also asks the window's title bar to go black
/// while it is showing, so the light bar does not cut across it, and gives a
/// phone's status and navigation bars light icons whatever the app theme is:
/// in light mode they were drawn dark on black.
class FinnBlackScreen extends StatefulWidget {
  const FinnBlackScreen({super.key, required this.child});

  final Widget child;

  @override
  State<FinnBlackScreen> createState() => _FinnBlackScreenState();
}

class _FinnBlackScreenState extends State<FinnBlackScreen> {
  @override
  void initState() {
    super.initState();
    // Not during build: the title bar listens to this.
    Future.microtask(() => WindowChrome.instance.tone.value = Brightness.dark);
  }

  @override
  void dispose() {
    Future.microtask(() => WindowChrome.instance.tone.value = null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: FluxTheme.systemUiOverlayStyle(context).copyWith(
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: ColoredBox(color: Colors.black, child: widget.child),
      );
}
