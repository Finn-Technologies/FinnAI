import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';

/// Stops phone-only platform calls from surfacing as errors on a desktop.
///
/// Haptic feedback, system-UI mode and the like are method-channel calls the
/// desktop embedders do not implement, and Flutter reports the resulting
/// [MissingPluginException] as an unhandled error. They are harmless there, so
/// that one exception is swallowed; every other error still reaches the
/// previous handler (or the default one) untouched.
void ignoreUnimplementedDesktopChannels() {
  final previous = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    if (error is MissingPluginException) return true;
    return previous?.call(error, stack) ?? false;
  };
}
