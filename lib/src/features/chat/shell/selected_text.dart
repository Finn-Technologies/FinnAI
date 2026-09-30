part of '../home_shell.dart';

bool _isImageAttachmentPath(String path) {
  final extension = path.split('.').last.toLowerCase();
  return const {'jpg', 'jpeg', 'png', 'webp', 'heic'}.contains(extension);
}

/// Turns a text selection shared through "Ask Finn AI" into a prompt.
///
/// A bare topic ("quantum entanglement") reads better wrapped as a question,
/// but a selection that is already a question or an instruction has to be sent
/// verbatim: wrapping it produced malformed prompts such as
/// "What is Explain gravity in one sentence?".
String selectedTextPrompt(String text) {
  final value = text.trim();
  if (value.isEmpty) return value;
  if (value.endsWith('?') ||
      value.contains('\n') ||
      _selectedTextRequestOpener.hasMatch(value)) {
    return value;
  }
  return 'What is $value?';
}

final RegExp _selectedTextRequestOpener = RegExp(
  r'^(?:what|why|how|who|where|when|which|whose|can|could|should|would|will|'
  r'is|are|was|were|do|does|did|explain|summari[sz]e|translate|write|tell|'
  r'describe|compare|list|give|help|make|create|draft|fix|review|analy[sz]e)\b',
  caseSensitive: false,
);
