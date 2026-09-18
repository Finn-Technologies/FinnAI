import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/creations/creation_generator.dart';
import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/creation_store.dart';

/// The outcome of one creation attempt, as the page needs to present it.
@immutable
class CreationResult {
  const CreationResult({required this.creation, required this.usedFallback});

  final FinnCreation creation;

  /// True when the model produced nothing usable and a deterministic starter
  /// was substituted — worth a quiet note, not an error.
  final bool usedFallback;
}

class CreationsController extends ChangeNotifier {
  CreationsController(
    this._store,
    this._generator, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final CreationStore _store;
  final CreationGenerator _generator;
  final DateTime Function() _clock;

  List<FinnCreation> _creations = const [];
  List<FinnCreation> get creations => _creations;

  CreationKind? _filter;
  CreationKind? get filter => _filter;
  List<FinnCreation> get visible => _filter == null
      ? _creations
      : _creations
          .where((creation) => creation.kind == _filter)
          .toList(growable: false);

  bool _loading = true;
  bool get loading => _loading;

  bool _generating = false;
  bool get generating => _generating;

  CreationStage? _stage;
  CreationStage? get stage => _stage;

  /// The brief currently being turned into a creation, shown in the transcript.
  String? _activePrompt;
  String? get activePrompt => _activePrompt;

  CreationKind? _activeKind;
  CreationKind? get activeKind => _activeKind;

  bool _cancelRequested = false;

  /// True once a job has been stopped by the user rather than by a failure.
  bool _cancelled = false;
  bool _disposed = false;

  /// Why the last operation failed, as a code the page localizes.
  ///
  /// The controller holds no user-facing sentence: a hardcoded English string
  /// would override the page's `L10n` lookup and leak English into the other
  /// four locales.
  CreationFailure? _failure;
  CreationFailure? get failure => _failure;

  /// Notifies unless the controller has been disposed.
  ///
  /// [load] can outlive the page that started it — closing the screen mid-load
  /// is normal — and notifying a disposed [ChangeNotifier] throws.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    _loading = true;
    _failure = null;
    _notify();
    try {
      _creations = await _store.load();
    } on Object {
      _failure = CreationFailure.load;
    } finally {
      _loading = false;
      _notify();
    }
  }

  void setFilter(CreationKind? value) {
    if (_filter == value) return;
    _filter = value;
    _notify();
  }

  Future<CreationResult?> create(String prompt, CreationKind kind) async {
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.isEmpty || _loading || _generating) return null;
    _generating = true;
    _cancelRequested = false;
    _cancelled = false;
    _failure = null;
    _activePrompt = cleanPrompt;
    _activeKind = kind;
    _stage = CreationStage.designing;
    _notify();
    try {
      final outcome = await _generator.generate(
        prompt: cleanPrompt,
        kind: kind,
        onStage: _reportStage,
      );
      if (_cancelRequested) {
        _cancelled = true;
        return null;
      }
      final now = _clock();
      final creation = FinnCreation(
        id: '${now.microsecondsSinceEpoch}-${kind.name}',
        prompt: cleanPrompt,
        title: outcome.title,
        summary: outcome.summary,
        artifact: outcome.artifact,
        createdAt: now,
      );
      final previous = _creations;
      _creations = [creation, ...previous];
      try {
        await _store.save(_creations);
      } on Object {
        _creations = previous;
        rethrow;
      }
      return CreationResult(
        creation: creation,
        usedFallback: outcome.usedFallback,
      );
    } on CreationCancelled {
      _cancelled = true;
      return null;
    } on Object catch (error) {
      // The reason is logged rather than shown: the page renders a localized
      // sentence, and an engine exception's English text would override it.
      debugPrint('FINN_CREATION failed: $error');
      _failure = CreationFailure.create;
      return null;
    } finally {
      _generating = false;
      _stage = null;
      _activePrompt = null;
      _activeKind = null;
      _notify();
    }
  }

  void _reportStage(CreationStage stage) {
    if (_cancelRequested || _stage == stage) return;
    _stage = stage;
    _notify();
  }

  Future<void> cancelGeneration() async {
    if (!_generating) return;
    _cancelRequested = true;
    final generator = _generator;
    if (generator is CancelableCreationGenerator) {
      await (generator as CancelableCreationGenerator).cancel();
    }
  }

  /// True when the last job ended because the user stopped it.
  ///
  /// The page reads this to write a quiet "stopped" turn, so a deliberate stop
  /// is never reported back as a failure.
  bool get wasCancelled => _cancelled;

  Future<void> delete(FinnCreation creation) async {
    final previous = _creations;
    _creations = _creations
        .where((item) => item.id != creation.id)
        .toList(growable: false);
    _notify();
    try {
      await _store.save(_creations);
    } on Object {
      _creations = previous;
      _failure = CreationFailure.delete;
      _notify();
    }
  }

  void clearFailure() {
    if (_failure == null) return;
    _failure = null;
    _notify();
  }
}

/// Why an operation failed, resolved to a sentence by the page.
enum CreationFailure { load, create, delete }
