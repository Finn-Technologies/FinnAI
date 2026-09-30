part of '../creations_page.dart';

class _Transcript extends StatelessWidget {
  const _Transcript({
    required this.turns,
    required this.scrollController,
    required this.stage,
    required this.onChooseKind,
    required this.onChooseTemplate,
    required this.onEdit,
    required this.onOpen,
    required this.onAddToHomeScreen,
    required this.onExport,
  });

  final List<_Turn> turns;
  final ScrollController scrollController;
  final CreationStage? stage;
  final ValueChanged<CreationKind> onChooseKind;
  final ValueChanged<String?> onChooseTemplate;
  final ValueChanged<FinnCreation> onEdit;
  final ValueChanged<FinnCreation> onOpen;
  final ValueChanged<FinnCreation> onAddToHomeScreen;
  final ValueChanged<FinnCreation> onExport;

  @override
  Widget build(BuildContext context) => ListView.builder(
        controller: scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const FluxBouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
        itemCount: turns.length,
        itemBuilder: (context, index) {
          final turn = turns[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: switch (turn) {
              _KindQuestionTurn(:final answered) => _AssistantBubble(
                  child: _KindQuestion(
                    answered: answered,
                    onChooseKind: onChooseKind,
                  ),
                ),
              _TemplateQuestionTurn(:final kind, :final answered) =>
                _AssistantBubble(
                  child: _TemplateQuestion(
                    kind: kind,
                    answered: answered,
                    onChoose: onChooseTemplate,
                  ),
                ),
              _AssistantNoteTurn(:final text) => _AssistantBubble(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              _UserTurn(:final text) => Align(
                  alignment: Alignment.centerRight,
                  child: _UserBubble(text: text),
                ),
              _ProgressTurn() => _AssistantBubble(
                  child: _StageLine(stage: stage),
                ),
              _ErrorTurn(:final message) => _ErrorNotice(
                  message: message,
                  onDismiss: null,
                ),
              _StoppedTurn() => _AssistantBubble(
                  child: Text(
                    L10n.of(context).creationsStopped,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: FluxColors.mutedOf(context),
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
              _ArtifactTurn(:final creation, :final usedFallback) =>
                _ArtifactCard(
                  creation: creation,
                  usedFallback: usedFallback,
                  onOpen: () => onOpen(creation),
                  onAddToHomeScreen: () => onAddToHomeScreen(creation),
                  onExport: () => onExport(creation),
                  onEdit:
                      creation.template == null ? null : () => onEdit(creation),
                ),
            },
          );
        },
      );
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .82,
          ),
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
          decoration: BoxDecoration(
            color: FluxColors.cardOf(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(19),
              topRight: Radius.circular(19),
              bottomLeft: Radius.circular(5),
              bottomRight: Radius.circular(19),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: FluxColors.isDark(context) ? .28 : .04,
                ),
                blurRadius: FluxColors.isDark(context) ? 12 : 9,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: child,
        ),
      );
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: FluxColors.isDark(context)
              ? FluxColors.bubbleUserDark
              : FluxColors.bubbleUserLight,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(19),
            topRight: Radius.circular(19),
            bottomLeft: Radius.circular(19),
            bottomRight: Radius.circular(5),
          ),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
}

/// The kind question, with full-width answers inside the bubble.
class _KindQuestion extends StatelessWidget {
  const _KindQuestion({required this.answered, required this.onChooseKind});

  final CreationKind? answered;
  final ValueChanged<CreationKind> onChooseKind;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          L10n.of(context).creationsAskKind,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        for (final kind in CreationKind.values)
          Padding(
            // No trailing gap: the bubble's own padding closes the stack, so
            // the last answer sits flush with the others.
            padding: EdgeInsets.only(
              bottom: kind == CreationKind.values.last ? 0 : 8,
            ),
            child: _KindAnswer(
              kind: kind,
              selected: answered == kind,
              onTap: () => onChooseKind(kind),
            ),
          ),
      ],
    );
  }
}

class _KindAnswer extends StatelessWidget {
  const _KindAnswer({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final CreationKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: _kindLabel(context, kind),
        child: Material(
          color: FluxColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.sm),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(FluxRadius.sm),
            child: Container(
              // The answer rows are the primary builder control, so they keep
              // the 48dp minimum even though the label alone is shorter.
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _kindLabel(context, kind),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  // Only the chosen answer carries a mark: an arrow on every
                  // option would promise a navigation each one does not do.
                  if (selected)
                    FluxIcon(
                      icon: FluxIcons.check,
                      size: 16,
                      color: FluxColors.inkOf(context),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _StageLine extends StatelessWidget {
  const _StageLine({required this.stage});

  final CreationStage? stage;

  @override
  Widget build(BuildContext context) {
    final label = switch (stage) {
      CreationStage.designing => L10n.of(context).creationsStageDesigning,
      CreationStage.writing => L10n.of(context).creationsStageWriting,
      CreationStage.validating => L10n.of(context).creationsStageValidating,
      CreationStage.repairing => L10n.of(context).creationsStageRepairing,
      null => L10n.of(context).creationsGenerating,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Spinner(),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: FluxColors.mutedOf(context),
                ),
          ),
        ),
      ],
    );
  }
}

class _Spinner extends StatefulWidget {
  const _Spinner();

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _animation.value = .15;
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
        turns: _animation,
        child: FluxIcon(
          icon: FluxIcons.loading,
          size: 18,
          color: FluxColors.mutedOf(context),
        ),
      );
}
