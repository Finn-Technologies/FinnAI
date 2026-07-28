import 'package:flutter/foundation.dart';

import 'creation_generator.dart';
import 'creation_model.dart';
import 'creation_store.dart';

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
  bool _cancelRequested = false;
  String? _error;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _creations = await _store.load();
    } on Object {
      _error = 'Creations could not be loaded.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setFilter(CreationKind? value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  Future<FinnCreation?> create(String prompt, CreationKind kind) async {
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.isEmpty || _loading || _generating) return null;
    _generating = true;
    _cancelRequested = false;
    _error = null;
    notifyListeners();
    try {
      final draft = await _generator.generate(cleanPrompt, kind);
      if (_cancelRequested) return null;
      final now = _clock();
      final creation = FinnCreation(
        id: '${now.microsecondsSinceEpoch}-${kind.name}',
        kind: kind,
        prompt: cleanPrompt,
        title: draft.title,
        summary: draft.summary,
        sections: draft.sections,
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
      return creation;
    } on Object {
      if (!_cancelRequested) {
        _error = 'Finn could not finish that creation. Please try again.';
      }
      return null;
    } finally {
      _generating = false;
      notifyListeners();
    }
  }

  Future<void> cancelGeneration() async {
    if (!_generating) return;
    _cancelRequested = true;
    final generator = _generator;
    if (generator is CancelableCreationGenerator) {
      await (generator as CancelableCreationGenerator).cancel();
    }
  }

  Future<void> delete(FinnCreation creation) async {
    final previous = _creations;
    _creations = _creations
        .where((item) => item.id != creation.id)
        .toList(growable: false);
    notifyListeners();
    try {
      await _store.save(_creations);
    } on Object {
      _creations = previous;
      _error = 'That creation could not be deleted.';
      notifyListeners();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
