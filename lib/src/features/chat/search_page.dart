import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/conversations/conversation_timestamp.dart';
import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/creation_store.dart';
import 'package:finn_ai/src/features/you/you_labels.dart';
import 'package:finn_ai/src/features/you/you_memory_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/ambient_background.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_header.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// Searches chats, creations and You in one place.
class FinnSearchPage extends StatefulWidget {
  const FinnSearchPage({
    super.key,
    required this.onOpenChat,
    required this.onOpenCreations,
    required this.onOpenYou,
  });

  final ValueChanged<String> onOpenChat;
  final VoidCallback onOpenCreations;
  final VoidCallback onOpenYou;

  @override
  State<FinnSearchPage> createState() => _FinnSearchPageState();
}

class _FinnSearchPageState extends State<FinnSearchPage> {
  final TextEditingController _query = TextEditingController();
  List<FinnCreation> _creations = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadCreations());
  }

  Future<void> _loadCreations() async {
    try {
      final all = await CreationStore.instance.load();
      if (mounted) setState(() => _creations = all);
    } catch (_) {}
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matches(String text, String needle) =>
      text.toLowerCase().contains(needle);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final metrics = FinnPageHeaderMetrics.forHeight(
      MediaQuery.sizeOf(context).height,
      MediaQuery.sizeOf(context).width,
    );
    return Scaffold(
      body: AmbientBackground(
        intensity: 1,
        child: ListenableBuilder(
          listenable: _query,
          builder: (context, _) {
            final needle = _query.text.trim().toLowerCase();
            final chats = needle.isEmpty
                ? const <FinnConversation>[]
                : ConversationStore.instance.conversations
                    .where(
                      (c) =>
                          _matches(c.title, needle) ||
                          c.messages.any((m) => _matches(m.text, needle)),
                    )
                    .toList();
            final creations = needle.isEmpty
                ? const <FinnCreation>[]
                : _creations.where((c) => _matches(c.title, needle)).toList();
            final memories = needle.isEmpty
                ? const <YouMemory>[]
                : YouMemoryStore.instance.kept
                    .where((m) => _matches(m.text, needle))
                    .toList();
            final nothing = needle.isNotEmpty &&
                chats.isEmpty &&
                creations.isEmpty &&
                memories.isEmpty;
            return Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(
                    25,
                    metrics.contentTop,
                    25,
                    40,
                  ),
                  children: [
                    if (needle.isEmpty) FinnCaption(l10n.searchPrompt),
                    if (nothing) FinnCaption(l10n.searchNothing),
                    if (chats.isNotEmpty) ...[
                      _heading(l10n.searchChatsHeading),
                      for (final chat in chats.take(8))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FinnTile(
                            title: chat.title,
                            subtitle: formatConversationTimestamp(
                              context,
                              chat.updatedAt,
                            ),
                            onTap: () => widget.onOpenChat(chat.id),
                          ),
                        ),
                    ],
                    if (creations.isNotEmpty) ...[
                      _heading(l10n.searchCreationsHeading),
                      for (final creation in creations.take(8))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FinnTile(
                            title: creation.title,
                            subtitle: _kindLabel(l10n, creation.kind),
                            onTap: widget.onOpenCreations,
                          ),
                        ),
                    ],
                    if (memories.isNotEmpty) ...[
                      _heading(l10n.hubYouTitle),
                      for (final memory in memories.take(8))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FinnTile(
                            title: memory.text,
                            subtitle: youCategoryLabel(l10n, memory.category),
                            onTap: widget.onOpenYou,
                          ),
                        ),
                    ],
                  ],
                ),
                Positioned(
                  left: 25,
                  right: 25,
                  top: metrics.headerTop,
                  height: 50,
                  child: Row(
                    children: [
                      FinnCircleButton(
                        key: const ValueKey('page-back-button'),
                        glyph: const FigmaSvg(
                          asset: FigmaAssets.back,
                          width: 25,
                          height: 25,
                        ),
                        label: l10n.commonBack,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _query,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          style: Theme.of(context).textTheme.bodyMedium,
                          decoration: InputDecoration(
                            hintText: l10n.searchHint,
                            filled: true,
                            fillColor: FluxColors.controlOf(context),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(100),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(5, 15, 5, 8),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      );
}

String _kindLabel(AppLocalizations l10n, CreationKind kind) => switch (kind) {
      CreationKind.app => l10n.plusMiniApp,
      CreationKind.widget => l10n.plusWidget,
      CreationKind.presentation => l10n.plusPresentation,
    };
