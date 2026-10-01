import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/search/search_agent.dart';
import 'package:finn_ai/src/features/you/you_memory_store.dart';
import 'package:finn_ai/src/features/you/you_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';

/// What FinnAI took from You for a reply, with a switch for the rest of the
/// chat and a way into You.
Future<void> showFromYouSheet(BuildContext context, ToolActivity activity) {
  final l10n = L10n.of(context);
  final store = YouMemoryStore.instance;
  final chatId = ConversationStore.instance.active?.id;
  final lines = activity.detail.split('\n').where((l) => l.isNotEmpty).toList();
  return showFinnSheet<void>(
    context,
    title: l10n.fromYouTitle,
    subtitle: l10n.fromYouSub,
    children: (sheetContext) => [
      for (final line in lines) ...[
        FinnTile(title: line),
        const SizedBox(height: 10),
      ],
      ListenableBuilder(
        listenable: store,
        builder: (context, _) => FinnTile(
          title: l10n.fromYouUse,
          trailing: FinnSwitch(
            value: store.usesYouIn(chatId),
            label: l10n.fromYouUse,
            onChanged: chatId == null
                ? null
                : (value) => store.setUseInChat(chatId, value),
          ),
        ),
      ),
      const SizedBox(height: 10),
      FinnButton(
        label: l10n.fromYouOpen,
        onTap: () {
          Navigator.pop(sheetContext);
          Navigator.of(context).push(
            FinnPageRoute<void>(
              child: YouPage(onBack: () => Navigator.of(context).pop()),
            ),
          );
        },
      ),
    ],
  );
}
