part of '../creations_page.dart';

/// One row of the creation transcript.
sealed class _Turn {
  const _Turn();
}

/// The "app, widget or presentation?" question, with tappable answers.
class _KindQuestionTurn extends _Turn {
  const _KindQuestionTurn({this.answered});

  final CreationKind? answered;
}

/// "Want a starting point?": optional template chips for an app or widget.
class _TemplateQuestionTurn extends _Turn {
  const _TemplateQuestionTurn({required this.kind, this.answered});

  final CreationKind kind;

  /// The template id the user picked, or null for "Let Finn choose".
  final String? answered;
}

/// A short assistant line, used between turns.
class _AssistantNoteTurn extends _Turn {
  const _AssistantNoteTurn(this.text);

  final String text;
}

class _UserTurn extends _Turn {
  const _UserTurn(this.text);

  final String text;
}

class _ProgressTurn extends _Turn {
  const _ProgressTurn();
}

class _ArtifactTurn extends _Turn {
  const _ArtifactTurn({required this.creation, required this.usedFallback});

  final FinnCreation creation;
  final bool usedFallback;
}

class _ErrorTurn extends _Turn {
  const _ErrorTurn(this.message);

  final String message;
}

class _StoppedTurn extends _Turn {
  const _StoppedTurn();
}
