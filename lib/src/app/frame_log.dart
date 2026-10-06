import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Frame timing on a device, for checking that an animation stays smooth.
///
/// Off unless the build asks for it (`--dart-define=FINN_FRAME_LOG=true`,
/// best with `--profile`). Every two seconds of drawing it prints one
/// `FINN_FRAMES` line: how many frames, the median and 90th/99th percentile
/// build (UI thread) and raster (GPU thread) times, and how many frames went
/// over the display's budget. `adb logcat -s flutter | grep FINN_FRAMES`.
abstract final class FrameLog {
  static const enabled = bool.fromEnvironment('FINN_FRAME_LOG');

  static final List<FrameTiming> _window = [];
  static DateTime _since = DateTime.now();

  /// Starts logging when the build enabled it; otherwise does nothing.
  static void start({double budgetMs = 1000 / 60}) {
    if (!enabled) return;
    SchedulerBinding.instance.addTimingsCallback((timings) {
      _window.addAll(timings);
      final now = DateTime.now();
      if (now.difference(_since).inMilliseconds < 2000) return;
      _since = now;
      _flush(budgetMs);
    });
  }

  static void _flush(double budgetMs) {
    if (_window.isEmpty) return;
    double ms(Duration d) => d.inMicroseconds / 1000;
    final build = [for (final t in _window) ms(t.buildDuration)]..sort();
    final raster = [for (final t in _window) ms(t.rasterDuration)]..sort();
    double at(List<double> v, double q) => v[((v.length - 1) * q).round()];
    final over = _window
        .where((t) =>
            ms(t.buildDuration) > budgetMs || ms(t.rasterDuration) > budgetMs)
        .length;
    debugPrint(
      'FINN_FRAMES n=${_window.length} '
      'build p50=${at(build, .5).toStringAsFixed(1)} '
      'p90=${at(build, .9).toStringAsFixed(1)} '
      'p99=${at(build, .99).toStringAsFixed(1)} '
      'raster p50=${at(raster, .5).toStringAsFixed(1)} '
      'p90=${at(raster, .9).toStringAsFixed(1)} '
      'p99=${at(raster, .99).toStringAsFixed(1)} '
      'over_budget=$over',
    );
    _window.clear();
  }
}
