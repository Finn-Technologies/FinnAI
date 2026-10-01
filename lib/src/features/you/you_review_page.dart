import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/you/you_labels.dart';
import 'package:finn_ai/src/features/you/you_memory_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';

/// What FinnAI noticed in recent chats: keep what is right, forget the rest.
class YouReviewPage extends StatelessWidget {
  const YouReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final store = YouMemoryStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = store.pending;
        return FinnPage(
          title: l10n.youReviewTitleBar,
          children: [
            FinnCaption(
              items.isEmpty ? l10n.youReviewEmpty : l10n.youReviewIntro,
            ),
            for (var i = 0; i < items.length; i++)
              FinnReveal(
                index: i,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: FluxColors.controlOf(context),
                    borderRadius: BorderRadius.circular(FluxRadius.card),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].text,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.youFrom(
                          youCategoryLabel(l10n, items[i].category),
                          items[i].sources.isEmpty
                              ? ''
                              : items[i].sources.first,
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: FluxColors.actionOf(context),
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FinnButton(
                              compact: true,
                              label: l10n.youKeep,
                              onTap: () => unawaited(
                                store.update(items[i].id, pending: false),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FinnButton(
                              compact: true,
                              secondary: true,
                              label: l10n.youForgetConfirm,
                              onTap: () => unawaited(store.forget(items[i].id)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
