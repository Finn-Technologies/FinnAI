import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/app/data_export.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/conversations/conversation_timestamp.dart';
import 'package:finn_ai/src/features/conversations/pinned_chats_store.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The chat's own menu: rename, pin, export as text, delete.
Future<void> showChatOptions(
  BuildContext context,
  FinnConversation conversation,
) {
  final l10n = L10n.of(context);
  final pins = PinnedChatsStore.instance;
  final generating = conversation.messages.any(
    (message) => message.status == ConversationMessageStatus.generating,
  );
  return showFinnSheet<void>(
    context,
    title: conversation.title,
    subtitle: l10n.optionsStarted(
      formatConversationTimestamp(context, conversation.createdAt),
    ),
    children: (sheetContext) => [
      FinnTile(
        icon: FluxIcons.edit,
        title: l10n.chatRenameAction,
        onTap: () async {
          Navigator.pop(sheetContext);
          final title = await showFinnPrompt(
            context,
            title: l10n.chatRenamePrompt,
            initial: conversation.title,
            hint: l10n.chatRenameEnterTitleHint,
            confirmLabel: l10n.commonSave,
          );
          if (title != null) {
            ConversationStore.instance.renameConversation(
              conversation.id,
              title,
            );
          }
        },
      ),
      const SizedBox(height: 10),
      FinnTile(
        icon: FluxIcons.flag,
        title: pins.isPinned(conversation.id)
            ? l10n.optionsUnpin
            : l10n.optionsPin,
        onTap: () {
          Navigator.pop(sheetContext);
          unawaited(
            pins.setPinned(conversation.id, !pins.isPinned(conversation.id)),
          );
        },
      ),
      const SizedBox(height: 10),
      FinnTile(
        icon: FluxIcons.download,
        title: l10n.optionsExport,
        onTap: () {
          Navigator.pop(sheetContext);
          unawaited(_exportText(context, conversation));
        },
      ),
      const SizedBox(height: 10),
      FinnTile(
        icon: FluxIcons.close,
        title: l10n.optionsDelete,
        destructive: true,
        onTap: () async {
          Navigator.pop(sheetContext);
          await confirmDeleteChat(context, conversation, generating);
        },
      ),
    ],
  );
}

/// Asks, then deletes. A chat that is still generating cannot be deleted.
Future<void> confirmDeleteChat(
  BuildContext context,
  FinnConversation conversation,
  bool generating,
) async {
  final l10n = L10n.of(context);
  if (generating) {
    await showFinnConfirm(
      context,
      title: l10n.chatDeleteTitle,
      body: l10n.chatDeleteActiveGenerationBody,
      confirmLabel: l10n.commonClose,
      cancelLabel: l10n.commonCancel,
    );
    return;
  }
  final ok = await showFinnConfirm(
    context,
    title: l10n.deleteChatTitle,
    body: l10n.deleteChatBody,
    confirmLabel: l10n.commonDelete,
    destructive: true,
  );
  if (ok == true) {
    unawaited(PinnedChatsStore.instance.setPinned(conversation.id, false));
    ConversationStore.instance.deleteConversation(conversation.id);
  }
}

Future<void> _exportText(
  BuildContext context,
  FinnConversation conversation,
) async {
  final text = StringBuffer('${conversation.title}\n\n');
  for (final message in conversation.messages) {
    if (message.text.trim().isEmpty) continue;
    final who = message.role == ConversationRole.user ? 'You' : 'FinnAI';
    text.writeln('$who: ${message.text.trim()}\n');
  }
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/finnai-chat.txt');
  await file.writeAsString(text.toString(), flush: true);
  final shared = await shareLocalFile(file.path, 'text/plain', 'FinnAI');
  if (!shared && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L10n.of(context).dataExportFailed)),
    );
  }
}
