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
  const _ArtifactTurn({required this.creation});

  final FinnCreation creation;
}

class _ErrorTurn extends _Turn {
  const _ErrorTurn(this.message);

  final String message;
}

class _StoppedTurn extends _Turn {
  const _StoppedTurn();
}
