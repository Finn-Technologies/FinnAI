import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/you/you_add_page.dart';
import 'package:finn_ai/src/features/you/you_labels.dart';
import 'package:finn_ai/src/features/you/you_memory_sheet.dart';
import 'package:finn_ai/src/features/you/you_memory_store.dart';
import 'package:finn_ai/src/shared/widgets/finn_create_button.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';

/// Everything FinnAI remembers in one group; tap one to see where it came from.
class YouCategoryPage extends StatelessWidget {
  const YouCategoryPage({super.key, required this.category});

  final YouCategory category;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final store = YouMemoryStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = store.inCategory(category);
        return FinnPage(
          title: youCategoryLabel(l10n, category),
          footer: FinnCreateButton(
            label: l10n.youTellFinn,
            onTap: () => Navigator.of(context).push(
              FinnPageRoute<void>(child: YouAddPage(category: category)),
            ),
          ),
          children: [
            FinnCaption(
              items.isEmpty
                  ? l10n.youCategoryEmpty
                  : l10n.youCategoryIntro(items.length),
            ),
            for (var i = 0; i < items.length; i++)
              FinnReveal(
                index: i,
                child: FinnTile(
                  title: items[i].text,
                  subtitle: youSeenLine(l10n, items[i]),
                  icon: null,
                  onTap: () => unawaited(showYouMemorySheet(context, items[i])),
                ),
              ),
          ],
        );
      },
    );
  }
}
