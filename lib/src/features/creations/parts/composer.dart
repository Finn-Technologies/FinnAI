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
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final bool blocked;
  final VoidCallback onSubmit;
  final VoidCallback onStop;
  final VoidCallback onChooseKind;

  @override
  Widget build(BuildContext context) => ChatComposer(
        controller: controller,
        focusNode: focusNode,
        blocked: blocked,
        busy: busy,
        onSend: onSubmit,
        onStop: onStop,
        hintText: L10n.of(context).creationsDescribeHint,
        // Creations has no attachments, voice or browse mode: leaving those
        // callbacks null keeps the pill identical to the chat one without the
        // controls that would do nothing here.
        onPickAttachment: onChooseKind,
        pickAttachmentSemanticLabel:
            L10n.of(context).creationsChooseKindSemantic,
      );
}

class _KindPicker extends StatelessWidget {
  const _KindPicker();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: FluxColors.canvasOf(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(FluxRadius.sheet),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.paddingOf(context).bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              child: Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: FluxColors.lineOf(context),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              L10n.of(context).creationsWhatAreWeMaking,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              L10n.of(context).creationsFinnAdapts,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FluxColors.mutedOf(context),
                  ),
            ),
            const SizedBox(height: 18),
            ...CreationKind.values.map(
              (kind) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Material(
                  color: FluxColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(FluxRadius.md),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, kind),
                    borderRadius: BorderRadius.circular(FluxRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        children: [
                          FluxIcon(icon: _kindIcon(kind), size: 21),
                          const SizedBox(width: 13),
                          Text(
                            _kindLabel(context, kind),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const Spacer(),
                          const FluxIcon(
                              icon: FluxIcons.arrowRight01, size: 17),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
