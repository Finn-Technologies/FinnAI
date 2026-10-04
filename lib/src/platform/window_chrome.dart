import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/src/platform/platform_target.dart';

/// What the window manager currently says about the window.
@immutable
class WindowChromeState {
  const WindowChromeState({
    this.maximized = false,
    this.fullscreen = false,
    this.focused = true,
  });

  final bool maximized;
  final bool fullscreen;
  final bool focused;

  @override
  bool operator ==(Object other) =>
      other is WindowChromeState &&
      other.maximized == maximized &&
      other.fullscreen == fullscreen &&
      other.focused == focused;

  @override
  int get hashCode => Object.hash(maximized, fullscreen, focused);
}

/// The Dart end of `linux/runner/my_application.cc`'s window channel.
///
/// On desktop Linux FinnAI removes the native title bar and draws its own
/// (`FinnWindowFrame`), so moving, resizing and the minimise / maximise / close
/// buttons all have to be asked of the window through this channel. Anywhere
/// else, or when the runner kept the native title bar
/// (`FINN_NATIVE_TITLEBAR=1`), [enabled] stays false and nothing is drawn.
class WindowChrome {
  WindowChrome({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('finn_ai/window');

  static final WindowChrome instance = WindowChrome();

  final MethodChannel _channel;

  /// True when the app owns the window's title bar and edges.
  final ValueNotifier<bool> enabled = ValueNotifier(false);

  /// True when the window can show through where the app does not paint, so
  /// the app may round its own corners. False without a compositing window
  /// manager, where a rounded corner would show as black.
  final ValueNotifier<bool> transparent = ValueNotifier(false);

  /// Set by a full-bleed screen (the black welcome page) so the title bar
  /// blends into it instead of sitting on top as a light strip. Null follows
  /// the app theme.
  final ValueNotifier<Brightness?> tone = ValueNotifier(null);
  final ValueNotifier<WindowChromeState> state =
      ValueNotifier(const WindowChromeState());

  /// Asks the runner whether it removed the native chrome, and starts listening
  /// for window-state changes. Safe to call on any platform.
  Future<void> initialize() async {
    if (finnPlatform != FinnPlatform.linux) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'stateChanged') _apply(call.arguments);
      return null;
    });
    try {
      enabled.value =
          await _channel.invokeMethod<bool>('hasCustomChrome') ?? false;
      transparent.value =
          await _channel.invokeMethod<bool>('isTransparent') ?? false;
      _apply(await _channel.invokeMethod<Object?>('getState'));
    } on MissingPluginException {
      // The runner has no window channel (OpenHarmony, a test host).
      enabled.value = false;
    } on PlatformException {
      enabled.value = false;
    }
  }

  void _apply(Object? raw) {
    if (raw is! Map) return;
    state.value = WindowChromeState(
      maximized: raw['maximized'] == true,
      fullscreen: raw['fullscreen'] == true,
      focused: raw['focused'] != false,
    );
  }

  /// Hands the pointer drag in progress to the window manager as a move.
  Future<void> startDrag() => _call('startDrag');

  /// Starts an interactive resize from [edge]: 0 N, 1 NE, 2 E, 3 SE, 4 S,
  /// 5 SW, 6 W, 7 NW.
  Future<void> startResize(int edge) => _call('startResize', edge);

  Future<void> minimize() => _call('minimize');
  Future<void> toggleMaximize() => _call('toggleMaximize');
  Future<void> toggleFullscreen() => _call('toggleFullscreen');
  Future<void> close() => _call('close');

  Future<void> _call(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Nothing to drive: the window is not ours.
    } on PlatformException catch (error) {
      debugPrint('FINN_WINDOW $method failed: ${error.message}');
    }
  }
}
