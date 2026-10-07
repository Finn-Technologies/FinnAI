import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/you/you_add_page.dart';
import 'package:finn_ai/src/features/you/you_category_page.dart';
import 'package:finn_ai/src/features/you/you_labels.dart';
import 'package:finn_ai/src/features/you/you_memory_store.dart';
import 'package:finn_ai/src/features/you/you_privacy_page.dart';
import 'package:finn_ai/src/features/you/you_review_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_create_button.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// "You": what FinnAI has learned about the user, sorted into six groups.
class YouPage extends StatefulWidget {
  const YouPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<YouPage> createState() => _YouPageState();
}

class _YouPageState extends State<YouPage> {
  final YouMemoryStore _store = YouMemoryStore.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_store.initialize());
  }

  void _push(Widget page) =>
      Navigator.of(context).push(FinnPageRoute<void>(child: page));

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final empty = _store.keptCount == 0 && _store.pending.isEmpty;
        final actions = [
          FinnCircleButton.icon(
            icon: FluxIcons.lock,
            label: l10n.youPrivacyTitle,
            onTap: () => _push(const YouPrivacyPage()),
          ),
        ];
        if (empty) {
          return FinnPage(
            title: l10n.hubYouTitle,
            onBack: widget.onBack,
            actions: [actions.last],
            children: [
              const SizedBox(height: 40),
              FinnReveal(
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: FluxColors.controlOf(context),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: FluxIcon(
                          icon: FluxIcons.you,
                          size: 44,
                          color: FluxColors.actionOf(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text(
                      l10n.youEmptyTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.youEmptyBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: FluxColors.actionOf(context),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FinnButton(
                label: l10n.youTellFinn,
                icon: FluxIcons.add,
                onTap: () => _push(const YouAddPage()),
              ),
              FinnButton(
                label: l10n.youPrivacyTitle,
                icon: FluxIcons.lock,
                secondary: true,
                onTap: () => _push(const YouPrivacyPage()),
              ),
            ],
          );
        }
        final updated = _store.updatedAt;
        final pending = _store.pending.length;
        final summary = _store.summary;
        return FinnPage(
          title: l10n.hubYouTitle,
          onBack: widget.onBack,
          actions: actions,
          footer: FinnCreateButton(
            label: l10n.youTellFinn,
            onTap: () => _push(const YouAddPage()),
          ),
          children: [
            FinnReveal(
              child: _Hero(
                caption: l10n.youAboutTitle,
                text: summary.isEmpty ? l10n.youEmptyBody : summary,
                footer: updated == null
                    ? null
                    : l10n.youUpdated(youWhen(l10n, updated)),
              ),
            ),
            if (pending > 0)
              FinnReveal(
                index: 1,
                child: Material(
                  color: const Color(0xFFEADDFF),
                  borderRadius: BorderRadius.circular(FluxRadius.card),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(FluxRadius.card),
                    onTap: () => _push(const YouReviewPage()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: FluxIcon(
                                icon: FluxIcons.magic,
                                size: 22,
                                color: FluxColors.actionOf(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.youReviewTitle(pending),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Text(
                                  l10n.youReviewSub,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF4F378B),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          FluxIcon(
                            icon: FluxIcons.arrowRight01,
                            size: 22,
                            color: FluxColors.mutedOf(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            FinnReveal(
              index: 2,
              child: GridView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 112,
                ),
                children: [
                  for (final category in YouCategory.values)
                    _CategoryCard(
                      category: category,
                      count: _store.inCategory(category).length,
                      onTap: () => _push(YouCategoryPage(category: category)),
                    ),
                ],
              ),
            ),
            InkWell(
              onTap: () => _push(const YouPrivacyPage()),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    const SizedBox(width: 5),
                    FluxIcon(
                      icon: FluxIcons.lock,
                      size: 18,
                      color: FluxColors.actionOf(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.youStoredOnly,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: FluxColors.actionOf(context),
                            ),
                      ),
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

class _Hero extends StatelessWidget {
  const _Hero({required this.caption, required this.text, this.footer});

  final String caption;
  final String text;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    const light = TextStyle(color: Colors.white, fontSize: 14, height: 1.2);
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: SizedBox(
        height: 232,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(FigmaAssets.artworkFinish, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, .65],
                  colors: [Color(0x1A000000), Color(0x8C000000)],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(caption, style: light),
                  const SizedBox(height: 10),
                  Text(
                    text,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: light.copyWith(fontSize: 18, height: 1.22),
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: 10),
                    Text(footer!, style: light),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.count,
    required this.onTap,
  });

  final YouCategory category;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Semantics(
      button: true,
      onTap: onTap,
      label: youCategoryLabel(l10n, category),
      excludeSemantics: true,
      child: FluxPressScale(
        scale: .97,
        child: Material(
          color: FluxColors.controlOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(FluxRadius.card),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FluxIcon(
                    icon: youCategoryIcon(category),
                    size: 22,
                    color: FluxColors.actionOf(context),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        youCategoryLabel(l10n, category),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        l10n.youCount(count),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: FluxColors.actionOf(context),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
