part of '../creations_page.dart';

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.blocked,
    required this.onSubmit,
    required this.onStop,
    required this.onChooseKind,
    required this.hint,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final bool blocked;
  final VoidCallback onSubmit;
  final VoidCallback onStop;
  final VoidCallback onChooseKind;
  final String hint;

  @override
  Widget build(BuildContext context) => ChatComposer(
        controller: controller,
        focusNode: focusNode,
        blocked: blocked,
        busy: busy,
        onSend: onSubmit,
        onStop: onStop,
        hintText: hint,
        // Creations has no attachments, voice or browse mode: leaving those
        // callbacks null keeps the pill identical to the chat one without the
        // controls that would do nothing here.
        onPickAttachment: onChooseKind,
        pickAttachmentSemanticLabel:
            L10n.of(context).creationsChooseKindSemantic,
      );
}
