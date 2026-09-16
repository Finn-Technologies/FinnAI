import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/chat/home_shell.dart' show FinnPageRoute;
import 'package:finn_ai/src/features/creations/creation_generator.dart';
import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/creation_palette.dart';
import 'package:finn_ai/src/features/creations/creation_store.dart';
import 'package:finn_ai/src/features/creations/creations_controller.dart';
import 'package:finn_ai/src/features/creations/deck/deck_export_service.dart';
import 'package:finn_ai/src/features/creations/deck/deck_viewer.dart';
import 'package:finn_ai/src/features/creations/home_screen_service.dart';
import 'package:finn_ai/src/features/creations/runtime/mini_app_host.dart';
import 'package:finn_ai/src/features/creations/spec/deck_spec.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/features/creations/spec/widget_spec.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/ambient_background.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_header.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// Which surface the page is showing.
enum _Mode { gallery, builder }

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
  const _ArtifactTurn({required this.creation, required this.usedFallback});

  final FinnCreation creation;
  final bool usedFallback;
}

class _ErrorTurn extends _Turn {
  const _ErrorTurn(this.message);

  final String message;
}

class CreationsPage extends StatefulWidget {
  const CreationsPage({super.key, this.controller});

  /// Injectable for tests and alternate local generation/storage backends.
  final CreationsController? controller;

  @override
  State<CreationsPage> createState() => _CreationsPageState();
}

class _CreationsPageState extends State<CreationsPage> {
  late final CreationsController _controller;
  late final bool _ownsController;
  final _promptController = TextEditingController();
  final _focusNode = FocusNode();
  final _headerOffset = ValueNotifier<double>(0);
  final _transcriptScroll = ScrollController();

  final _deckExport = DeckExportService();
  final _homeScreen = HomeScreenService.instance;

  _Mode _mode = _Mode.gallery;
  final List<_Turn> _turns = [];
  CreationKind? _pendingKind;
  String? _pendingPrompt;
  bool _modeChosen = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        CreationsController(CreationStore(), FinnCreationGenerator());
    _controller.addListener(_changed);
    unawaited(_initialise());
  }

  Future<void> _initialise() async {
    await _controller.load();
    if (!mounted) return;
    // Applied explicitly rather than from a listener: a notifier can fire while
    // the tree is mid-build, and rebuilding there would abort the load.
    setState(_applyInitialMode);
  }

  void _changed() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  /// An install with no creations should land straight in the builder, which is
  /// the design's empty state; one with creations should land in the gallery.
  void _applyInitialMode() {
    if (_modeChosen) return;
    _modeChosen = true;
    if (_controller.creations.isEmpty) {
      _mode = _Mode.builder;
      if (_turns.isEmpty) _turns.add(const _KindQuestionTurn());
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    if (_ownsController) {
      if (_controller.generating) {
        unawaited(_controller.cancelGeneration());
      }
      _controller.dispose();
    }
    _promptController.dispose();
    _focusNode.dispose();
    _headerOffset.dispose();
    _transcriptScroll.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_controller.generating) {
      final stop = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FluxRadius.sheet),
          ),
          title: Text(L10n.of(context).creationsStopTitle),
          content: Text(L10n.of(context).creationsStopBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(L10n.of(context).commonKeepCreating),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(L10n.of(context).commonStop),
            ),
          ],
        ),
      );
      if (stop != true) return;
      await _controller.cancelGeneration();
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _startBuilder() {
    setState(() {
      _mode = _Mode.builder;
      _turns
        ..clear()
        ..add(const _KindQuestionTurn());
      _pendingKind = null;
      _pendingPrompt = null;
    });
    _focusNode.requestFocus();
  }

  void _showGallery() {
    setState(() => _mode = _Mode.gallery);
  }

  void _send() {
    final text = _promptController.text.trim();
    if (text.isEmpty || _controller.generating) return;
    _promptController.clear();
    if (_pendingKind == null) {
      // The brief arrived before the kind; keep it and ask.
      setState(() {
        _pendingPrompt = text;
        if (_mode == _Mode.gallery) _mode = _Mode.builder;
        _turns.add(_UserTurn(text));
        final alreadyAsking = _turns.any(
          (turn) => turn is _KindQuestionTurn && turn.answered == null,
        );
        if (!alreadyAsking) _turns.add(const _KindQuestionTurn());
      });
      _scrollToEnd();
      return;
    }
    final kind = _pendingKind!;
    setState(() {
      if (_mode == _Mode.gallery) _mode = _Mode.builder;
      _turns.add(_UserTurn(text));
    });
    unawaited(_run(text, kind));
  }

  void _chooseKind(CreationKind kind) {
    final pending = _pendingPrompt;
    setState(() {
      _pendingKind = kind;
      final index = _turns.lastIndexWhere((turn) => turn is _KindQuestionTurn);
      if (index >= 0) {
        _turns[index] = _KindQuestionTurn(answered: kind);
      } else {
        _turns.add(_KindQuestionTurn(answered: kind));
      }
      if (pending == null) {
        _turns.add(
          _AssistantNoteTurn(
            L10n.of(context).creationsDescribeKind(_kindLabel(context, kind)),
          ),
        );
      } else {
        _pendingPrompt = null;
      }
    });
    if (pending == null) {
      _focusNode.requestFocus();
      _scrollToEnd();
      return;
    }
    unawaited(_run(pending, kind));
  }

  Future<void> _run(String prompt, CreationKind kind) async {
    const progress = _ProgressTurn();
    setState(() => _turns.add(progress));
    _scrollToEnd();

    final result = await _controller.create(prompt, kind);
    if (!mounted) return;
    setState(() {
      _turns.remove(progress);
      _pendingKind = null;
      _pendingPrompt = null;
      if (result == null) {
        _turns.add(
          _ErrorTurn(_controller.error ?? L10n.of(context).creationsFailed),
        );
      } else {
        _turns.add(
          _ArtifactTurn(
            creation: result.creation,
            usedFallback: result.usedFallback,
          ),
        );
      }
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_transcriptScroll.hasClients) return;
      _transcriptScroll.animateTo(
        _transcriptScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _open(FinnCreation creation) async {
    switch (creation.artifact) {
      case MiniAppArtifact(:final spec):
        await Navigator.of(context).push(
          FinnPageRoute<void>(
            child: MiniAppHost(
              title: creation.title,
              spec: spec,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
        );
      case PresentationArtifact(:final spec):
        await Navigator.of(context).push(
          FinnPageRoute<void>(
            child: DeckViewer(
              title: creation.title,
              deck: spec,
              onBack: () => Navigator.of(context).pop(),
              onExport: () => unawaited(_exportDeck(creation, spec)),
            ),
          ),
        );
      case WidgetArtifact(:final spec):
        await _showWidgetPreview(creation, spec);
      case LegacyDocumentArtifact():
        await _showDocument(creation);
    }
  }

  Future<void> _showWidgetPreview(FinnCreation creation, HomeWidgetSpec spec) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _WidgetPreviewSheet(
        creation: creation,
        spec: spec,
        onAddToHomeScreen: () {
          Navigator.pop(context);
          unawaited(_addToHomeScreen(creation));
        },
      ),
    );
  }

  Future<void> _showDocument(FinnCreation creation) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DocumentSheet(
        creation: creation,
        onDelete: () {
          Navigator.pop(context);
          unawaited(_controller.delete(creation));
        },
      ),
    );
  }

  Future<void> _addToHomeScreen(FinnCreation creation) async {
    final supported = await _homeScreen.isSupported();
    if (!mounted) return;
    if (!supported) {
      _snack(L10n.of(context).creationsHomeScreenUnsupported);
      return;
    }
    final ok = switch (creation.artifact) {
      WidgetArtifact(:final spec) => await _homeScreen.addWidgetToHomeScreen(
          creationId: creation.id,
          spec: spec,
          label: creation.title,
        ),
      MiniAppArtifact() => await _homeScreen.addCreationShortcut(
          creationId: creation.id,
          label: creation.title,
        ),
      _ => false,
    };
    if (!mounted) return;
    _snack(
      ok
          ? L10n.of(context).creationsHomeScreenAdded
          : L10n.of(context).creationsHomeScreenFailed,
    );
  }

  Future<void> _exportDeck(FinnCreation creation, DeckSpec deck) async {
    try {
      final file = await _deckExport.export(deck, title: creation.title);
      if (!mounted) return;
      final shared = await _homeScreen.shareFile(
        path: file.path,
        mimeType: 'application/vnd.openxmlformats-officedocument'
            '.presentationml.presentation',
        label: creation.title,
      );
      if (!mounted) return;
      _snack(
        shared
            ? L10n.of(context).creationsExportedShared
            : L10n.of(context).creationsExportedTo(
                file.path.split(Platform.pathSeparator).last,
              ),
      );
    } on Object {
      if (mounted) _snack(L10n.of(context).creationsExportFailed);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: FluxColors.inkOf(context),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !_controller.generating,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: AmbientBackground(
          intensity: .6,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final metrics = FinnPageHeaderMetrics.forHeight(
                constraints.maxHeight,
              );
              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: metrics.contentTop + 5,
                    bottom: 0,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L10n.of(context).creationsSubtitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: FluxColors.mutedOf(context),
                                      height: 1.35,
                                    ),
                              ),
                              const SizedBox(height: 18),
                              if (_mode == _Mode.gallery)
                                _Filters(
                                  selected: _controller.filter,
                                  onSelected: _controller.setFilter,
                                )
                              else if (_controller.creations.isNotEmpty)
                                // The builder is a one-way sub-flow, so give it
                                // an explicit way back to the saved creations.
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FluxPillButton(
                                    label: L10n.of(context).creationsAll,
                                    icon: FluxIcons.canvas,
                                    compact: true,
                                    onTap: _showGallery,
                                  ),
                                ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                child: _controller.error == null ||
                                        _mode == _Mode.builder
                                    ? const SizedBox(width: double.infinity)
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: _ErrorNotice(
                                          message: _controller.error!,
                                          onDismiss: _controller.clearError,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(child: _content()),
                        AnimatedPadding(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.fromLTRB(
                            20,
                            10,
                            20,
                            bottomInset > 0
                                ? 12
                                : MediaQuery.paddingOf(context).bottom + 20,
                          ),
                          child: _Composer(
                            controller: _promptController,
                            focusNode: _focusNode,
                            busy: _controller.generating,
                            blocked: _controller.loading,
                            onSubmit: _send,
                            onStop: () => unawaited(
                              _controller.cancelGeneration(),
                            ),
                            onChooseKind: () => unawaited(_pickKind()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: FinnPageHeader(
                      title: L10n.of(context).creationsTitle,
                      onBack: _close,
                      metrics: metrics,
                      scrollOffset: _headerOffset,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickKind() async {
    final kind = await showModalBottomSheet<CreationKind>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _KindPicker(),
    );
    if (kind == null || !mounted) return;
    _chooseKind(kind);
  }

  Widget _content() {
    if (_controller.loading) {
      return Center(
        child: _QuietLoader(label: L10n.of(context).creationsOpening),
      );
    }
    if (_mode == _Mode.builder) {
      return _Transcript(
        turns: _turns,
        scrollController: _transcriptScroll,
        stage: _controller.stage,
        onChooseKind: _chooseKind,
        onOpen: _open,
        onAddToHomeScreen: _addToHomeScreen,
        onExport: (creation) => unawaited(
          _exportDeck(
              creation, (creation.artifact as PresentationArtifact).spec),
        ),
      );
    }
    final visible = _controller.visible;
    if (visible.isEmpty) {
      return _EmptyState(filtered: _controller.filter != null);
    }
    return _Gallery(
      creations: visible,
      onOpen: _open,
      onBadgeTap: (creation) => switch (creation.artifact) {
        PresentationArtifact(:final spec) =>
          unawaited(_exportDeck(creation, spec)),
        _ => unawaited(_addToHomeScreen(creation)),
      },
      badgeLabel: (creation) => switch (creation.artifact) {
        PresentationArtifact() => L10n.of(context).creationsExportDeck,
        _ => L10n.of(context).creationsAddToHomeScreen,
      },
      onNew: _startBuilder,
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({
    required this.turns,
    required this.scrollController,
    required this.stage,
    required this.onChooseKind,
    required this.onOpen,
    required this.onAddToHomeScreen,
    required this.onExport,
  });

  final List<_Turn> turns;
  final ScrollController scrollController;
  final CreationStage? stage;
  final ValueChanged<CreationKind> onChooseKind;
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
              _ArtifactTurn(:final creation, :final usedFallback) =>
                _ArtifactCard(
                  creation: creation,
                  usedFallback: usedFallback,
                  onOpen: () => onOpen(creation),
                  onAddToHomeScreen: () => onAddToHomeScreen(creation),
                  onExport: () => onExport(creation),
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
            padding: const EdgeInsets.only(bottom: 8),
            child: _KindAnswer(
              kind: kind,
              selected: answered == kind,
              showCheck: answered != null,
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
    required this.showCheck,
    required this.onTap,
  });

  final CreationKind kind;
  final bool selected;
  final bool showCheck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: _kindLabel(context, kind),
        child: Material(
          color: FluxColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.pill),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(FluxRadius.pill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _kindLabel(context, kind),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (showCheck)
                    FluxIcon(
                      icon: selected ? FluxIcons.check : FluxIcons.arrowRight01,
                      size: 16,
                      color: selected
                          ? FluxColors.inkOf(context)
                          : FluxColors.mutedOf(context),
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

/// The finished creation, presented as the assistant's answer.
class _ArtifactCard extends StatelessWidget {
  const _ArtifactCard({
    required this.creation,
    required this.usedFallback,
    required this.onOpen,
    required this.onAddToHomeScreen,
    required this.onExport,
  });

  final FinnCreation creation;
  final bool usedFallback;
  final VoidCallback onOpen;
  final VoidCallback onAddToHomeScreen;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final kind = creation.kind;
    final accent = CreationPalette.tileFor(kind);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .88,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FluxColors.cardOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.sheet),
          border: Border.all(
            color: FluxColors.lineOf(context).withValues(alpha: .8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: FluxIcon(
                      icon: _iconFor(creation),
                      color: CreationPalette.onPastel,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        creation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _artifactDescriptor(context, creation),
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: FluxColors.mutedOf(context),
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (usedFallback) ...[
              const SizedBox(height: 12),
              Text(
                L10n.of(context).creationsFallbackNote,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: FluxColors.mutedOf(context),
                      height: 1.35,
                    ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Flexible(
                  child: FluxPillButton(
                    label: L10n.of(context).commonOpen,
                    onTap: onOpen,
                  ),
                ),
                const SizedBox(width: 8),
                FluxIconButton(
                  icon: kind == CreationKind.presentation
                      ? FluxIcons.download
                      : FluxIcons.add,
                  tooltip: kind == CreationKind.presentation
                      ? L10n.of(context).creationsExportDeck
                      : L10n.of(context).creationsAddToHomeScreen,
                  onTap: kind == CreationKind.presentation
                      ? onExport
                      : onAddToHomeScreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Round, staggered tiles matching the creations design.
class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.creations,
    required this.onOpen,
    required this.onBadgeTap,
    required this.badgeLabel,
    required this.onNew,
  });

  final List<FinnCreation> creations;
  final ValueChanged<FinnCreation> onOpen;
  final ValueChanged<FinnCreation> onBadgeTap;
  final String Function(FinnCreation) badgeLabel;
  final VoidCallback onNew;

  static const double _gap = 16;
  static const double _stagger = 28;
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(20, 2, 20, 14);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileSize =
            (constraints.maxWidth - _padding.horizontal - _gap) / 2;
        final left = <FinnCreation>[];
        final right = <FinnCreation>[];
        for (var index = 0; index < creations.length; index++) {
          (index.isEven ? left : right).add(creations[index]);
        }
        Widget column(List<FinnCreation> items, {required double top}) =>
            Column(
              children: [
                for (final creation in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _CreationTile(
                      creation: creation,
                      size: tileSize,
                      badgeLabel: badgeLabel(creation),
                      onTap: () => onOpen(creation),
                      onBadgeTap: () => onBadgeTap(creation),
                    ),
                  ),
              ],
            );
        return SingleChildScrollView(
          physics: const FluxBouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: _padding,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: column(left, top: 0)),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: _stagger),
                      child: column(right, top: _stagger),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FluxPillButton(
                label: L10n.of(context).creationsNewCreation,
                icon: FluxIcons.add,
                onTap: onNew,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CreationTile extends StatelessWidget {
  const _CreationTile({
    required this.creation,
    required this.size,
    required this.badgeLabel,
    required this.onTap,
    required this.onBadgeTap,
  });

  final FinnCreation creation;
  final double size;
  final String badgeLabel;
  final VoidCallback onTap;
  final VoidCallback onBadgeTap;

  @override
  Widget build(BuildContext context) {
    final accent = CreationPalette.tileFor(creation.kind);
    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Material(
                  color: accent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap,
                    child: Center(child: _TileGlyph(creation: creation)),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: 2,
                child: Semantics(
                  button: true,
                  label: badgeLabel,
                  child: Material(
                    color: FluxColors.cardOf(context),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onBadgeTap,
                      customBorder: const CircleBorder(),
                      child: SizedBox.square(
                        dimension: 30,
                        child: Center(
                          child: FluxIcon(
                            icon: creation.kind == CreationKind.presentation
                                ? FluxIcons.download
                                : FluxIcons.add,
                            size: 15,
                            color: CreationPalette.onPastel,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          creation.title,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// A creation's tile glyph: its own emoji when it has one, else its kind icon.
class _TileGlyph extends StatelessWidget {
  const _TileGlyph({required this.creation});

  final FinnCreation creation;

  @override
  Widget build(BuildContext context) {
    final emoji = _emojiFor(creation);
    if (emoji != null) {
      return Text(emoji, style: const TextStyle(fontSize: 42));
    }
    return FluxIcon(
      icon: _iconFor(creation),
      color: CreationPalette.onPastel,
      size: creation.kind == CreationKind.presentation ? 34 : 38,
      strokeWidth: 1.5,
    );
  }
}

class _Composer extends StatefulWidget {
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
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  late bool _focused;

  @override
  void initState() {
    super.initState();
    _focused = widget.focusNode.hasFocus;
    widget.controller.addListener(_changed);
    widget.focusNode.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.focusNode.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.controller.text.trim().isNotEmpty && !widget.busy;
    return FluxGlass(
      radius: 999,
      color: FluxColors.surfaceOf(context),
      borderColor: FluxColors.inkOf(
        context,
      ).withValues(alpha: _focused ? .2 : .07),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 4, 7, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Semantics(
                button: true,
                label: L10n.of(context).creationsChooseKindSemantic,
                child: SizedBox.square(
                  dimension: 40,
                  child: InkWell(
                    onTap: widget.blocked ? null : widget.onChooseKind,
                    customBorder: const CircleBorder(),
                    child: Center(
                      child: FluxIcon(
                        icon: FluxIcons.add,
                        size: 20,
                        color: widget.blocked
                            ? FluxColors.mutedOf(context).withValues(alpha: .4)
                            : FluxColors.mutedOf(context),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(4000),
                    ],
                    enabled: !widget.blocked,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => canSend ? widget.onSubmit() : null,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration.collapsed(
                      hintText: L10n.of(context).creationsDescribeHint,
                      hintStyle: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: FluxColors.mutedOf(context)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (widget.busy)
                Semantics(
                  button: true,
                  label: L10n.of(context).creationsStopSemantic,
                  child: SizedBox.square(
                    dimension: 40,
                    child: InkWell(
                      onTap: widget.onStop,
                      customBorder: const CircleBorder(),
                      child: const Center(
                        child: FluxIcon(icon: FluxIcons.close, size: 18),
                      ),
                    ),
                  ),
                )
              else
                Semantics(
                  button: true,
                  enabled: canSend,
                  label: L10n.of(context).creationsCreateSemantic,
                  child: SizedBox.square(
                    dimension: 40,
                    child: InkWell(
                      onTap: canSend ? widget.onSubmit : null,
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: FigmaSvg(
                          asset: canSend
                              ? FigmaAssets.activeSend
                              : FigmaAssets.send,
                          width: 34,
                          height: 34,
                          invertForDark: FluxColors.isDark(context),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
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

class _WidgetPreviewSheet extends StatelessWidget {
  const _WidgetPreviewSheet({
    required this.creation,
    required this.spec,
    required this.onAddToHomeScreen,
  });

  final FinnCreation creation;
  final HomeWidgetSpec spec;
  final VoidCallback onAddToHomeScreen;

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
              creation.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              L10n.of(context).creationsWidgetPreview,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FluxColors.mutedOf(context),
                  ),
            ),
            const SizedBox(height: 18),
            _WidgetSurface(spec: spec),
            const SizedBox(height: 18),
            FluxPillButton(
              label: L10n.of(context).creationsAddToHomeScreen,
              icon: FluxIcons.add,
              onTap: onAddToHomeScreen,
            ),
          ],
        ),
      );
}

/// Approximates what the launcher widget will render.
///
/// The real widget is built by Kotlin from the same spec through `RemoteViews`,
/// so this is a preview of the same data and accent, not a separate design.
class _WidgetSurface extends StatelessWidget {
  const _WidgetSurface({required this.spec});

  final HomeWidgetSpec spec;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CreationPalette.pastel(spec.accent),
          borderRadius: BorderRadius.circular(FluxRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              spec.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: CreationPalette.onPastel,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 10),
            for (final row in spec.rows.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: CreationPalette.onPastelMuted,
                            ),
                      ),
                    ),
                    Text(
                      row.value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: CreationPalette.onPastel,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            if (spec.footer.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                spec.footer,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: CreationPalette.onPastelMuted,
                    ),
              ),
            ],
          ],
        ),
      );
}

class _DocumentSheet extends StatelessWidget {
  const _DocumentSheet({required this.creation, required this.onDelete});

  final FinnCreation creation;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final artifact = creation.artifact;
    final sections = artifact is LegacyDocumentArtifact
        ? artifact.sections
        : const <CreationSection>[];
    return Container(
      height: MediaQuery.sizeOf(context).height * .88,
      decoration: BoxDecoration(
        color: FluxColors.canvasOf(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(FluxRadius.sheet),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    creation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: onDelete,
                  child: Text(
                    L10n.of(context).commonDelete,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: const Color(0xFFD34B4B),
                        ),
                  ),
                ),
                FluxIconButton(
                  icon: FluxIcons.close,
                  tooltip: L10n.of(context).commonClose,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (creation.summary.isNotEmpty)
                  Text(
                    creation.summary,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: FluxColors.mutedOf(context),
                        ),
                  ),
                const SizedBox(height: 20),
                for (final section in sections)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        color: FluxColors.cardOf(context),
                        borderRadius: BorderRadius.circular(FluxRadius.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.heading,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            section.body,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: FluxColors.mutedOf(context),
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  L10n.of(context).creationsOriginalBrief,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: FluxColors.mutedOf(context),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  creation.prompt,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onSelected});

  final CreationKind? selected;
  final ValueChanged<CreationKind?> onSelected;

  @override
  Widget build(BuildContext context) {
    final values = <CreationKind?>[null, ...CreationKind.values];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final value = values[index];
          final active = selected == value;
          final radius = BorderRadius.circular(99);
          return Semantics(
            button: true,
            selected: active,
            label: L10n.of(context).creationsFilterSemantic(
              value == null
                  ? L10n.of(context).creationsAll
                  : _filterLabel(context, value),
            ),
            child: Material(
              color: active
                  ? FluxColors.inkOf(context)
                  : FluxColors.surfaceOf(context),
              borderRadius: radius,
              child: InkWell(
                onTap: () => onSelected(value),
                borderRadius: radius,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: Text(
                      value == null
                          ? L10n.of(context).creationsAll
                          : _filterLabel(context, value),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: active
                                ? FluxColors.canvasOf(context)
                                : FluxColors.inkOf(context),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 42),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: FluxColors.surfaceOf(context),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: FluxIcon(icon: FluxIcons.canvas, size: 27),
                ),
              ),
              const SizedBox(height: 17),
              Text(
                filtered
                    ? L10n.of(context).creationsEmptyFilteredTitle
                    : L10n.of(context).creationsEmptyTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                filtered
                    ? L10n.of(context).creationsEmptyFilteredBody
                    : L10n.of(context).creationsEmptyBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: FluxColors.mutedOf(context),
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
      );
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
        decoration: BoxDecoration(
          color: const Color(0xFFD34B4B).withValues(alpha: .09),
          borderRadius: BorderRadius.circular(FluxRadius.sm),
        ),
        child: Row(
          children: [
            const FluxIcon(
              icon: FluxIcons.sad,
              size: 18,
              color: Color(0xFFD34B4B),
            ),
            const SizedBox(width: 10),
            Expanded(
              child:
                  Text(message, style: Theme.of(context).textTheme.labelMedium),
            ),
            if (onDismiss != null)
              FluxIconButton(
                icon: FluxIcons.close,
                size: 30,
                tooltip: L10n.of(context).commonDismiss,
                onTap: onDismiss,
              ),
          ],
        ),
      );
}

class _QuietLoader extends StatelessWidget {
  const _QuietLoader({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Spinner(),
          if (label != null) ...[
            const SizedBox(width: 10),
            Text(
              label!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FluxColors.mutedOf(context),
                  ),
            ),
          ],
        ],
      );
}

List<List<dynamic>> _iconFor(FinnCreation creation) =>
    creation.artifact is LegacyDocumentArtifact
        ? FluxIcons.note
        : _kindIcon(creation.kind);

List<List<dynamic>> _kindIcon(CreationKind kind) => switch (kind) {
      CreationKind.app => FluxIcons.canvas,
      CreationKind.widget => FluxIcons.chip,
      CreationKind.presentation => FluxIcons.skills,
    };

String? _emojiFor(FinnCreation creation) {
  final artifact = creation.artifact;
  if (artifact is! MiniAppArtifact) return null;
  for (final node in artifact.spec.nodes) {
    if (node is ImageNode && node.emoji.trim().isNotEmpty) {
      return node.emoji.trim();
    }
  }
  return null;
}

/// A one-line, localized description of what the creation contains.
String _artifactDescriptor(BuildContext context, FinnCreation creation) {
  final l10n = L10n.of(context);
  return switch (creation.artifact) {
    MiniAppArtifact(:final spec) =>
      l10n.creationsElementCount(spec.nodes.length),
    WidgetArtifact(:final spec) => l10n.creationsRowCount(spec.rows.length),
    PresentationArtifact(:final spec) =>
      l10n.creationsSlideCount(spec.slides.length),
    LegacyDocumentArtifact() => _kindLabel(context, creation.kind),
  };
}

/// Localized label for a creation kind (the enum's own label stays English data
/// used for prompts and persistence).
String _kindLabel(BuildContext context, CreationKind kind) => switch (kind) {
      CreationKind.app => L10n.of(context).creationsKindApp,
      CreationKind.widget => L10n.of(context).creationsKindWidget,
      CreationKind.presentation => L10n.of(context).creationsKindPresentation,
    };

/// Plural label used by the gallery filters, matching the design.
String _filterLabel(BuildContext context, CreationKind kind) => switch (kind) {
      CreationKind.app => L10n.of(context).creationsFilterApps,
      CreationKind.widget => L10n.of(context).creationsFilterWidgets,
      CreationKind.presentation =>
        L10n.of(context).creationsFilterPresentations,
    };
