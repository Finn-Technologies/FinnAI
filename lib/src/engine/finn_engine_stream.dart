import 'dart:async';
import 'finn_engine_types.dart';

/// Active generation stream emitted by FinnEngine.
class FinnEngineStream {
  FinnEngineStream({required this.tokenStream, required this.cancel});

  /// The broadcast stream of streamed tokens.
  final Stream<String> tokenStream;

  /// Cancel callback to immediately abort native worker generation.
  final Future<void> Function() cancel;

  final Completer<GenerationReport> _reportCompleter =
      Completer<GenerationReport>();

  /// Completes when the generation finishes with a full telemetry report.
  Future<GenerationReport> get report => _reportCompleter.future;

  void completeReport(GenerationReport report) {
    if (!_reportCompleter.isCompleted) {
      _reportCompleter.complete(report);
    }
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!_reportCompleter.isCompleted) {
      _reportCompleter.completeError(error, stackTrace);
    }
  }
}
