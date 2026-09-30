// ignore_for_file: invalid_use_of_protected_member
part of '../creations_page.dart';

extension _CreationsPageActions on _CreationsPageState {
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

  Future<void> _editCreation(FinnCreation creation) async {
    if (creation.template == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SlotEditorSheet(
        creation: creation,
        onSave: (slots) async {
          final updated = await _controller.editSlots(creation, slots);
          if (updated == null || !mounted) return;
          // The transcript card shows the edited creation, not the old one.
          setState(() {
            for (var i = 0; i < _turns.length; i++) {
              final turn = _turns[i];
              if (turn is _ArtifactTurn && turn.creation.id == creation.id) {
                _turns[i] = _ArtifactTurn(
                  creation: updated,
                  usedFallback: turn.usedFallback,
                );
              }
            }
          });
        },
      ),
    );
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
}
