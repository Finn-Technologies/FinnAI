import 'dart:async';

/// Collects a command's output as it streams and hands the screen the text
/// so far at most every [interval], so a chatty command (an install prints
/// hundreds of lines) never rebuilds the transcript per line.
class LiveOutput {
  LiveOutput(this.onShow, {this.interval = const Duration(milliseconds: 120)});

  final void Function(String text) onShow;
  final Duration interval;

  /// The most kept for the live view: the end of the output, where progress
  /// is.
  static const int keepChars = 6000;

  final StringBuffer _buffer = StringBuffer();
  Timer? _pending;

  void add(String chunk) {
    _buffer.write(chunk);
    _pending ??= Timer(interval, () {
      _pending = null;
      final text = _buffer.toString();
      onShow(text.length > keepChars
          ? text.substring(text.length - keepChars)
          : text);
    });
  }

  /// No more updates; the finished result replaces the live text.
  void close() {
    _pending?.cancel();
    _pending = null;
  }
}
