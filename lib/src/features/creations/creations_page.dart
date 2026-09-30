import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/chat/home_shell.dart'
    show ChatComposer, FinnPageRoute;
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
import 'package:finn_ai/src/features/creations/templates/creation_template.dart';
import 'package:finn_ai/src/features/creations/templates/template_catalog.dart';
import 'package:finn_ai/src/shared/slots/slots.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/ambient_background.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_header.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

part 'parts/turns.dart';
part 'parts/transcript.dart';
part 'parts/artifact_card.dart';
part 'parts/gallery.dart';
part 'parts/composer.dart';
part 'parts/sheets.dart';
part 'parts/chrome.dart';
part 'parts/labels.dart';
part 'parts/template_ui.dart';
part 'parts/actions.dart';

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
  String? _pendingTemplateId;
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
      _pendingTemplateId = null;
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
    // The brief is in; the next thing the user needs to see is either the kind
    // question or the creation itself, and the keyboard would cover both.
    _focusNode.unfocus();
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
    unawaited(_run(text, kind, _pendingTemplateId));
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
      _pendingTemplateId = null;
      if (pending == null) {
        // A starting point is offered only for kinds that have templates, and
        // only while the brief has not been typed yet.
        if (CreationTemplates.forKind(kind).isNotEmpty) {
          _turns.add(_TemplateQuestionTurn(kind: kind));
        }
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
    unawaited(_run(pending, kind, null));
  }

  void _chooseTemplate(String? id) {
    setState(() {
      _pendingTemplateId = id;
      final index =
          _turns.lastIndexWhere((turn) => turn is _TemplateQuestionTurn);
      if (index >= 0) {
        final previous = _turns[index] as _TemplateQuestionTurn;
        _turns[index] =
            _TemplateQuestionTurn(kind: previous.kind, answered: id);
      }
    });
    _focusNode.requestFocus();
  }

  Future<void> _run(
    String prompt,
    CreationKind kind,
    String? templateId,
  ) async {
    const progress = _ProgressTurn();
    setState(() => _turns.add(progress));
    _scrollToEnd();

    final result =
        await _controller.create(prompt, kind, templateId: templateId);
    if (!mounted) return;
    setState(() {
      _turns.remove(progress);
      _pendingKind = null;
      _pendingTemplateId = null;
      _pendingPrompt = null;
      if (result == null) {
        // A stopped job is a deliberate user action, not a failure, so it gets
        // its own quiet turn rather than an error.
        _turns.add(
          _controller.wasCancelled
              ? const _StoppedTurn()
              : _ErrorTurn(L10n.of(context).creationsFailed),
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
                              // The gallery leads with its filters, matching
                              // the reference's tighter hierarchy; the sentence
                              // only appears where it has something to explain.
                              if (_mode == _Mode.builder) ...[
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
                              ],
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
                                child: _controller.failure == null ||
                                        _mode == _Mode.builder
                                    ? const SizedBox(width: double.infinity)
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: _ErrorNotice(
                                          message: _failureMessage(
                                            context,
                                            _controller.failure!,
                                          ),
                                          onDismiss: _controller.clearFailure,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        // The header collapses against the same scroll the
                        // content uses, whichever mode is showing.
                        Expanded(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification.metrics.axis == Axis.vertical) {
                                _headerOffset.value =
                                    notification.metrics.pixels;
                              }
                              return false;
                            },
                            child: _content(),
                          ),
                        ),
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
        onChooseTemplate: _chooseTemplate,
        onEdit: _editCreation,
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
