import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// What can be done to a session: rename it, pin it, look at its files, or
/// delete it with everything it made.
Future<void> showCodeSessionOptions(
  BuildContext context, {
  required CodeSession session,
  required CodeServices services,
  required VoidCallback onOpenFiles,
}) {
  final l10n = L10n.of(context);
  return showFinnSheet<void>(
    context,
    title: session.title.isEmpty ? l10n.codeSessionsTitle : session.title,
    children: (sheet) => [
      FinnTile(
        icon: FluxIcons.edit,
        title: l10n.codeSessionRename,
        onTap: () async {
          Navigator.of(sheet).pop();
          final title = await showFinnPrompt(
            context,
            title: l10n.codeSessionRenameTitle,
            initial: session.title,
            confirmLabel: l10n.commonSave,
          );
          if (title != null) services.sessions.rename(session.id, title);
        },
      ),
      const SizedBox(height: 10),
      FinnTile(
        icon: CodeIcons.pin,
        title: session.pinned ? l10n.codeSessionUnpin : l10n.codeSessionPin,
        chevron: false,
        onTap: () {
          Navigator.of(sheet).pop();
          services.sessions.setPinned(session.id, !session.pinned);
        },
      ),
      const SizedBox(height: 10),
      FinnTile(
        icon: CodeIcons.folder,
        title: l10n.codeSessionFiles,
        onTap: () {
          Navigator.of(sheet).pop();
          onOpenFiles();
        },
      ),
      const SizedBox(height: 10),
      FinnTile(
        icon: CodeIcons.trash,
        title: l10n.codeSessionDelete,
        destructive: true,
        chevron: false,
        onTap: () async {
          Navigator.of(sheet).pop();
          final confirmed = await showFinnConfirm(
            context,
            title: l10n.codeSessionDeleteTitle,
            body: l10n.codeSessionDeleteBody,
            confirmLabel: l10n.commonDelete,
            destructive: true,
          );
          if (confirmed != true) return;
          if (services.agent.runningSessionId == session.id) {
            await services.agent.stop();
          }
          await services.sessions.delete(session.id);
        },
      ),
    ],
  );
}
