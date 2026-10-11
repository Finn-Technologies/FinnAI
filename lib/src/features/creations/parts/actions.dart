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
              creationId: creation.id,
              onBack: () => Navigator.of(context).pop(),
              onAddToHome: () => unawaited(_confirmAddToHome(creation)),
              onEdit: () => unawaited(_editWithFinn(creation)),
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
    return Navigator.of(context).push(
      FinnPageRoute<void>(
        child: _WidgetDetailPage(
          creation: creation,
          spec: spec,
          onAddToHome: () => _confirmAddToHome(creation),
          onEdit: () => unawaited(_editWithFinn(creation)),
          onMenu: (anchor) => _showCreationMenu(creation, anchor),
        ),
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

  /// "Add X to your home screen?": the design asks once before it does it.
  Future<void> _confirmAddToHome(FinnCreation creation) async {
    final l10n = L10n.of(context);
    final ok = await showFinnConfirm(
      context,
      title: l10n.creationsAddHomeTitle(creation.title),
      body: l10n.creationsAddHomeBody,
      confirmLabel: l10n.creationsAddHomeConfirm,
      cancelLabel: l10n.commonNotNow,
    );
    if (ok == true) await _addToHomeScreen(creation);
  }

  /// The long-press menu on a creation.
  void _showCreationMenu(FinnCreation creation, Rect anchor) {
    final l10n = L10n.of(context);
    final canHome = creation.kind != CreationKind.presentation;
    unawaited(
      showFinnMenu(
        context,
        anchor: anchor,
        items: [
          FinnMenuItem(
            label: l10n.commonOpen,
            icon: FluxIcons.arrowRight02,
            onTap: () => unawaited(_open(creation)),
          ),
          FinnMenuItem(
            label: l10n.creationsMenuEditWithFinn,
            icon: FluxIcons.edit,
            onTap: () => unawaited(_editWithFinn(creation)),
          ),
          if (canHome)
            FinnMenuItem(
              label: l10n.creationsAddToHomeScreen,
              icon: FluxIcons.canvas,
              onTap: () => unawaited(_confirmAddToHome(creation)),
            ),
          FinnMenuItem(
            label: l10n.creationsMenuShare,
            icon: FluxIcons.arrowUp01,
            onTap: () => unawaited(_share(creation)),
          ),
          FinnMenuItem(
            label: l10n.creationsMenuDuplicate,
            icon: FluxIcons.copy,
            onTap: () {
              unawaited(_controller.duplicate(creation));
              _snack(l10n.creationsDuplicated);
            },
          ),
          FinnMenuItem(
            label: l10n.commonDelete,
            icon: FluxIcons.close,
            destructive: true,
            onTap: () => unawaited(_confirmDelete(creation)),
          ),
        ],
      ),
    );
  }

  /// Opens the builder seeded with the original brief, so the model designs
  /// the creation again with the changes the user types.
  Future<void> _editWithFinn(FinnCreation creation) async {
    _startBuilder();
    _chooseKind(creation.kind);
    _promptController.text = creation.prompt;
  }

  Future<void> _share(FinnCreation creation) async {
    if (creation.artifact case PresentationArtifact(:final spec)) {
      await _exportDeck(creation, spec);
      return;
    }
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${creation.id}.json');
      await file.writeAsString(jsonEncode(creation.toJson()), flush: true);
      final shared = await _homeScreen.shareFile(
        path: file.path,
        mimeType: 'application/json',
        label: creation.title,
      );
      if (!shared && mounted) _snack(L10n.of(context).creationsExportFailed);
    } on Object {
      if (mounted) _snack(L10n.of(context).creationsExportFailed);
    }
  }

  Future<void> _confirmDelete(FinnCreation creation) async {
    final l10n = L10n.of(context);
    final ok = await showFinnConfirm(
      context,
      title: l10n.creationsDeleteNamed(creation.title),
      body: l10n.creationsDeleteNamedBody,
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (ok == true) await _controller.delete(creation);
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
