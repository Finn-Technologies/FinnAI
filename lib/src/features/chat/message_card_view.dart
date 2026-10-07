import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/conversations/message_card.dart';
import 'package:finn_ai/src/features/creations/creation_launcher.dart';
import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/creation_palette.dart';
import 'package:finn_ai/src/features/creations/creation_shelf.dart';
import 'package:finn_ai/src/features/creations/creation_store.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/features/creations/widget_preview.dart';
import 'package:finn_ai/src/features/flows/flow_editor_page.dart';
import 'package:finn_ai/src/features/flows/flow_icons.dart';
import 'package:finn_ai/src/features/flows/flow_labels.dart';
import 'package:finn_ai/src/features/flows/flows_actions.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// What a chat card needs from the rest of the app.
class MessageCardHost {
  const MessageCardHost({required this.flowActions});

  final FlowsActions flowActions;
}

/// The card under a reply that made something: a creation to open and put on
/// the home screen, or a flow to check and turn on.
///
/// A card holds only a pointer, so it always shows what the thing is *now* and
/// quietly disappears when the thing was deleted.
class MessageCardView extends StatelessWidget {
  const MessageCardView({super.key, required this.card, required this.host});

  final MessageCard card;
  final MessageCardHost host;

  @override
  Widget build(BuildContext context) => switch (card.kind) {
        MessageCardKind.flow => _FlowCard(id: card.id, host: host),
        MessageCardKind.creation => _CreationCard(id: card.id),
      };
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FluxColors.cardOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.card),
          border: Border.all(color: FluxColors.lineOf(context)),
        ),
        child: child,
      );
}

// ---------------------------------------------------------------------------
// Flows
// ---------------------------------------------------------------------------

class _FlowCard extends StatelessWidget {
  const _FlowCard({required this.id, required this.host});

  final String id;
  final MessageCardHost host;

  @override
  Widget build(BuildContext context) {
    final store = host.flowActions.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final flow = store.flows.where((f) => f.id == id).firstOrNull;
        if (flow == null) return const SizedBox.shrink();
        final l10n = L10n.of(context);
        final theme = Theme.of(context).textTheme;
        final auto = flow.triggers.any((t) => t.isScheduled || t.isEvent);
        final blocks = flow.allBlocks.take(6).toList();
        return _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBDECCB).withValues(
                        alpha: FluxColors.isDark(context) ? .3 : 1,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: FluxIcon(
                        icon: FlowIcons.forTrigger(flow.trigger.kind),
                        size: 20,
                        color: FluxColors.isDark(context)
                            ? Colors.white
                            : const Color(0xFF121212),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flow.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.titleSmall,
                        ),
                        Text(
                          flowTriggerLabel(l10n, flow.trigger),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodySmall?.copyWith(
                            color: FluxColors.mutedOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < blocks.length; i++) ...[
                    if (i > 0)
                      Icon(
                        FluxIcons.arrowRight01,
                        size: 18,
                        color: FluxColors.mutedOf(context),
                      ),
                    Tooltip(
                      message: flowBlockTitle(l10n, blocks[i].kind),
                      child: FluxIcon(
                        icon: FlowIcons.forBlock(blocks[i].kind),
                        size: 20,
                        color: FluxColors.inkOf(context),
                      ),
                    ),
                  ],
                ],
              ),
              if (flow.hasDeviceAction && auto && !flow.granted) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.flowsAutoNeedsAllow,
                  style: theme.labelMedium?.copyWith(
                    color: FluxColors.mutedOf(context),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  if (auto)
                    FluxPillButton(
                      key: Key('flow-card-turn-on-$id'),
                      label: flow.enabled
                          ? l10n.flowsChatIsOn
                          : l10n.flowsChatTurnOn,
                      icon: flow.enabled ? FluxIcons.check : null,
                      compact: true,
                      onTap: flow.enabled
                          ? null
                          : () => unawaited(
                                host.flowActions.turnOn(context, flow),
                              ),
                    ),
                  if (auto) const SizedBox(width: 8),
                  FluxPillButton(
                    key: Key('flow-card-open-$id'),
                    label: l10n.flowsChatOpen,
                    compact: true,
                    onTap: () => Navigator.of(context).push(
                      FinnPageRoute<void>(
                        child: FlowEditorPage(
                          flowId: flow.id,
                          actions: host.flowActions,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Creations
// ---------------------------------------------------------------------------

class _CreationCard extends StatelessWidget {
  const _CreationCard({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: CreationStore.revision,
        builder: (context, _, __) => FutureBuilder<FinnCreation?>(
          future: CreationShelf.instance.find(id),
          builder: (context, snapshot) {
            final creation = snapshot.data;
            if (creation == null) return const SizedBox.shrink();
            return _CreationBody(creation: creation);
          },
        ),
      );
}

class _CreationBody extends StatelessWidget {
  const _CreationBody({required this.creation});

  final FinnCreation creation;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context).textTheme;
    final artifact = creation.artifact;
    final accent = switch (artifact) {
      MiniAppArtifact(:final spec) => CreationPalette.pastel(spec.accent),
      WidgetArtifact(:final spec) => CreationPalette.pastel(spec.accent),
      _ => CreationPalette.tileFor(creation.kind),
    };
    final kindLabel = switch (creation.kind) {
      CreationKind.app => l10n.creationsKindApp,
      CreationKind.widget => l10n.creationsKindWidget,
      CreationKind.presentation => l10n.creationsKindPresentation,
    };
    final emoji = artifact is MiniAppArtifact
        ? artifact.spec.nodes
            .whereType<ImageNode>()
            .map((n) => n.emoji)
            .where((e) => e.isNotEmpty)
            .firstOrNull
        : null;
    final canHome = creation.kind != CreationKind.presentation;
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (artifact is WidgetArtifact)
            HomeWidgetPreview(spec: artifact.spec)
          else
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(
                      alpha: FluxColors.isDark(context) ? .35 : 1,
                    ),
                    borderRadius: BorderRadius.circular(FluxRadius.md),
                  ),
                  child: emoji != null
                      ? Text(emoji, style: const TextStyle(fontSize: 26))
                      : FluxIcon(
                          icon: creation.kind == CreationKind.app
                              ? FluxIcons.canvas
                              : FluxIcons.flows,
                          size: 24,
                          color: const Color(0xFF121212),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        creation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.titleSmall,
                      ),
                      Text(
                        artifact is PresentationArtifact
                            ? '$kindLabel · ${l10n.creationsSlideCount(artifact.spec.slides.length)}'
                            : kindLabel,
                        style: theme.bodySmall?.copyWith(
                          color: FluxColors.mutedOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (artifact is! WidgetArtifact) ...[
                FluxPillButton(
                  key: Key('creation-card-open-${creation.id}'),
                  label: l10n.commonOpen,
                  icon: FluxIcons.arrowRight02,
                  compact: true,
                  onTap: () => unawaited(
                    CreationLauncher.openCreation(context, creation),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (canHome)
                FluxPillButton(
                  key: Key('creation-card-home-${creation.id}'),
                  label: l10n.creationsAddToHomeScreen,
                  compact: true,
                  onTap: () => unawaited(
                    CreationLauncher.addToHome(context, creation),
                  ),
                ),
              if (artifact is PresentationArtifact)
                FluxPillButton(
                  key: Key('creation-card-share-${creation.id}'),
                  label: l10n.creationsMenuShare,
                  compact: true,
                  onTap: () => unawaited(
                    CreationLauncher.exportDeck(
                      context,
                      creation,
                      artifact.spec,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
