part of '../finn_accelerator.dart';

/// Bounded FIFO turn gate for queued generations (see
/// [FinnAccelerator.generateReplyQueued]).
///
/// [waitTurn] reserves a place in line and resolves when [signalNext] hands
/// the turn over (the engine became free). Reservations are capped at
/// [capacity]; beyond that [waitTurn] throws [StateError] so callers get a
/// clear failure instead of unbounded queue growth. A waiter that gives up
/// before its turn arrives calls [abandon] to restore capacity; abandoning
/// after the turn was granted is a no-op.
@visibleForTesting
class ReplyTurnGate {
  ReplyTurnGate({this.capacity = 2});

  /// Maximum number of callers that can wait at once.
  final int capacity;

  final List<Completer<void>> _waiters = [];

  /// Number of callers currently waiting for their turn.
  int get waitingCount => _waiters.length;

  /// Reserves a place in line; resolves when the turn is granted.
  Future<void> waitTurn() {
    if (_waiters.length >= capacity) {
      throw StateError(
        'Finn already has $capacity queued generations; '
        'try again when the current answer finishes.',
      );
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  /// Gives up a reserved [turn] that was not granted yet (no-op afterwards).
  void abandon(Future<void> turn) {
    _waiters.removeWhere((completer) => identical(completer.future, turn));
  }

  /// Hands the engine to the oldest waiter, if any.
  void signalNext() {
    if (_waiters.isEmpty) return;
    _waiters.removeAt(0).complete();
  }
}
