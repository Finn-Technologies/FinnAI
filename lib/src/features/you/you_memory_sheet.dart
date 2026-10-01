import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/you/you_add_page.dart';
import 'package:finn_ai/src/features/you/you_labels.dart';
import 'package:finn_ai/src/features/you/you_memory_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// Where one memory came from, with the ways to edit, mute or forget it.
Future<void> showYouMemorySheet(BuildContext context, YouMemory memory) {
  final l10n = L10n.of(context);
  final store = YouMemoryStore.instance;
  return showFinnSheet<void>(
    context,
    title: memory.text,
    subtitle: l10n.youLearnedOn(youWhen(l10n, memory.createdAt)),
    children: (sheetContext) => [
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: FluxColors.controlOf(sheetContext),
          borderRadius: BorderRadius.circular(FluxRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.youSeenInLabel,
              style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: FluxColors.actionOf(sheetContext),
                  ),
            ),
            const SizedBox(height: 8),
            if (memory.sources.isEmpty)
              Text(
                l10n.youAddedByYou,
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              )
            else
              for (final source in memory.sources.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    source,
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      FinnTile(
        icon: FluxIcons.edit,
        title: l10n.youEdit,
        onTap: () {
          Navigator.pop(sheetContext);
          Navigator.of(context).push(
            FinnPageRoute<void>(child: YouAddPage(editing: memory)),
          );
        },
      ),
      const SizedBox(height: 10),
      _MuteTile(memory: memory),
      const SizedBox(height: 10),
      FinnTile(
        icon: FluxIcons.close,
        title: l10n.youForgetThis,
        destructive: true,
        onTap: () async {
          Navigator.pop(sheetContext);
          final ok = await showFinnConfirm(
            context,
            title: l10n.youForgetTitle,
            body: l10n.youForgetBody,
            confirmLabel: l10n.youForgetConfirm,
            destructive: true,
          );
          if (ok == true) unawaited(store.forget(memory.id));
        },
      ),
    ],
  );
}

class _MuteTile extends StatefulWidget {
  const _MuteTile({required this.memory});

  final YouMemory memory;

  @override
  State<_MuteTile> createState() => _MuteTileState();
}

class _MuteTileState extends State<_MuteTile> {
  late bool _muted = !widget.memory.useInChats;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return FinnTile(
      icon: FluxIcons.micOff,
      title: l10n.youDoNotUse,
      trailing: FinnSwitch(
        value: _muted,
        label: l10n.youDoNotUse,
        onChanged: (value) {
          setState(() => _muted = value);
          unawaited(
            YouMemoryStore.instance.update(
              widget.memory.id,
              useInChats: !value,
            ),
          );
        },
      ),
    );
  }
}
