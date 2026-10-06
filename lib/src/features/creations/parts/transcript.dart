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
        padding: const EdgeInsets.fromLTRB(25, 2, 25, 14),
        itemCount: turns.length,
        itemBuilder: (context, index) {
          final turn = turns[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
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

/// The assistant's side of the builder chat: plain text, no bubble.
class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: child,
        ),
      );
}

/// The user's side: a white pill, as in the chat.
class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: FluxColors.isDark(context)
              ? FluxColors.bubbleUserDark
              : FluxColors.bubbleUserLight,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
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
          color: FluxColors.controlOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.card),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(FluxRadius.card),
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

/// The build's steps, as the design draws them: a dark tile, a line, then a
/// check once the step is done or a spinner while it runs.
class _StageLine extends StatelessWidget {
  const _StageLine({required this.stage});

  final CreationStage? stage;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final steps = <(CreationStage, String, IconData)>[
      (CreationStage.designing, l10n.creationsStageDesigning, FluxIcons.canvas),
      (CreationStage.writing, l10n.creationsStageWriting, FluxIcons.edit),
      (
        CreationStage.validating,
        l10n.creationsStageValidating,
        FluxIcons.check,
      ),
    ];
    final current = switch (stage) {
      CreationStage.designing => 0,
      CreationStage.writing => 1,
      CreationStage.validating || CreationStage.repairing => 2,
      null => 0,
    };
    final ink = FluxColors.actionOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i <= current; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == current ? 0 : 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: FluxIcon(
                      icon: steps[i].$3,
                      size: 16,
                      color: FluxColors.actionInkOf(context),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    stage == CreationStage.repairing && i == current
                        ? l10n.creationsStageRepairing
                        : steps[i].$2,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: ink),
                  ),
                ),
                const SizedBox(width: 10),
                if (i < current)
                  FluxIcon(
                    icon: FluxIcons.check,
                    size: 18,
                    color: ink,
                  )
                else
                  const _Spinner(),
              ],
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
