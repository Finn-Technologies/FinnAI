import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/creation_shelf.dart';
import 'package:finn_ai/src/features/creations/creation_store.dart';
import 'package:finn_ai/src/features/creations/deck/deck_export_service.dart';
import 'package:finn_ai/src/features/creations/deck/deck_viewer.dart';
import 'package:finn_ai/src/features/creations/home_screen_service.dart';
import 'package:finn_ai/src/features/creations/runtime/mini_app_host.dart';
import 'package:finn_ai/src/features/creations/spec/deck_spec.dart';
import 'package:finn_ai/src/features/creations/widget_preview.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';

/// Opens and uses a saved creation from anywhere: a pinned shortcut, a card in
/// a chat. Each kind opens into its own full-screen view, so a creation made in
/// a conversation is one tap from being used.
abstract final class CreationLauncher {
  /// Opens the creation with [creationId]. False when it no longer exists.
  static Future<bool> open(
    BuildContext context,
    String creationId, {
    CreationStore? store,
  }) async {
    final creation = store == null
        ? await CreationShelf.instance.find(creationId)
        : (await store.load()).where((c) => c.id == creationId).firstOrNull;
    if (creation == null || !context.mounted) return false;
    await openCreation(context, creation);
    return true;
  }

  static Future<void> openCreation(
    BuildContext context,
    FinnCreation creation,
  ) async {
    final navigator = Navigator.of(context);
    switch (creation.artifact) {
      case MiniAppArtifact(:final spec):
        await navigator.push(
          FinnPageRoute<void>(
            child: MiniAppHost(
              title: creation.title,
              spec: spec,
              creationId: creation.id,
              onBack: navigator.pop,
              onAddToHome: () => unawaited(addToHome(context, creation)),
            ),
          ),
        );
      case PresentationArtifact(:final spec):
        await navigator.push(
          FinnPageRoute<void>(
            child: DeckViewer(
              title: creation.title,
              deck: spec,
              onBack: navigator.pop,
              onExport: () => unawaited(exportDeck(context, creation, spec)),
            ),
          ),
        );
      case WidgetArtifact(:final spec):
        await showFinnSheet<void>(
          context,
          title: creation.title,
          children: (sheet) => [
            HomeWidgetPreview(spec: spec),
            const SizedBox(height: 14),
            FinnButton(
              label: L10n.of(sheet).creationsAddToHomeScreen,
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(addToHome(context, creation));
              },
            ),
          ],
        );
      case LegacyDocumentArtifact():
        break;
    }
  }

  /// Puts a widget on the home screen, or pins an app as a shortcut, and says
  /// how it went.
  static Future<bool> addToHome(
    BuildContext context,
    FinnCreation creation,
  ) async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final service = HomeScreenService.instance;
    void say(String text) => messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          backgroundColor: FluxColors.inkOf(context),
        ),
      );
    if (!await service.isSupported()) {
      say(l10n.creationsHomeScreenUnsupported);
      return false;
    }
    final ok = switch (creation.artifact) {
      WidgetArtifact(:final spec) => await service.addWidgetToHomeScreen(
          creationId: creation.id,
          spec: spec,
          label: creation.title,
        ),
      MiniAppArtifact() => await service.addCreationShortcut(
          creationId: creation.id,
          label: creation.title,
        ),
      _ => false,
    };
    say(ok ? l10n.creationsHomeScreenAdded : l10n.creationsHomeScreenFailed);
    return ok;
  }

  /// Writes a deck as a `.pptx` and hands it to the share sheet.
  static Future<void> exportDeck(
    BuildContext context,
    FinnCreation creation,
    DeckSpec deck,
  ) async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final file =
          await DeckExportService().export(deck, title: creation.title);
      final shared = await HomeScreenService.instance.shareFile(
        path: file.path,
        mimeType: 'application/vnd.openxmlformats-officedocument'
            '.presentationml.presentation',
        label: creation.title,
      );
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            shared
                ? l10n.creationsExportedShared
                : l10n.creationsExportedTo(file.path.split('/').last),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on Object {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n.creationsExportFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
