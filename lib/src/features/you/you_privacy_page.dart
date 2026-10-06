import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/app/data_export.dart';
import 'package:finn_ai/src/features/you/you_labels.dart';
import 'package:finn_ai/src/features/you/you_memory_store.dart';
import 'package:finn_ai/src/features/you/you_profile_page.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// How You is stored, used and learned, plus export and erase.
class YouPrivacyPage extends StatelessWidget {
  const YouPrivacyPage({super.key});

  Future<void> _export(BuildContext context) async {
    final store = YouMemoryStore.instance;
    final data = {
      'you': [for (final item in store.kept) item.toJson()],
    };
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/finnai-you.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    final shared = await shareLocalFile(file.path, 'application/json', 'You');
    if (!shared && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.of(context).dataExportFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final store = YouMemoryStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => FinnPage(
        title: l10n.youPrivacyTitle,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFEADDFF),
              borderRadius: BorderRadius.circular(FluxRadius.card),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FluxIcon(
                  icon: FluxIcons.lock,
                  size: 22,
                  color: Color(0xFF4F378B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.youPrivacyNote,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF4F378B),
                        ),
                  ),
                ),
              ],
            ),
          ),
          FinnTile(
            title: l10n.youLearn,
            subtitle: l10n.youLearnSub,
            trailing: FinnSwitch(
              value: store.learn,
              label: l10n.youLearn,
              onChanged: (v) => unawaited(store.setLearn(v)),
            ),
          ),
          FinnTile(
            title: l10n.youUseInChats,
            subtitle: l10n.youUseInChatsSub,
            trailing: FinnSwitch(
              value: store.useInNewChats,
              label: l10n.youUseInChats,
              onChanged: (v) => unawaited(store.setUseInNewChats(v)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.youLearnAbout,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          GridView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 56,
            ),
            children: [
              for (final category in YouCategory.values)
                Container(
                  padding: const EdgeInsets.only(left: 15, right: 5),
                  decoration: BoxDecoration(
                    color: FluxColors.controlOf(context),
                    borderRadius: BorderRadius.circular(FluxRadius.card),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          youCategoryLabel(l10n, category),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      FinnSwitch(
                        value: store.learnsAbout(category),
                        label: youCategoryLabel(l10n, category),
                        onChanged: (v) =>
                            unawaited(store.setLearnAbout(category, v)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          FinnTile(
            icon: FluxIcons.edit,
            title: l10n.youPersonalise,
            subtitle: l10n.youPersonaliseSub,
            onTap: () => Navigator.of(context).push(
              FinnPageRoute<void>(
                child: YouProfilePage(
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          FinnTile(
            icon: FluxIcons.download,
            title: l10n.youExport,
            subtitle: l10n.youExportSub,
            onTap: () => unawaited(_export(context)),
          ),
          FinnTile(
            icon: FluxIcons.security,
            title: l10n.youErase,
            subtitle: l10n.youEraseSub(store.keptCount + store.pending.length),
            destructive: true,
            onTap: () async {
              final ok = await showFinnConfirm(
                context,
                title: l10n.youEraseTitle,
                body: l10n.youEraseBody,
                confirmLabel: l10n.youEraseConfirm,
                destructive: true,
              );
              if (ok == true) unawaited(store.eraseAll());
            },
          ),
        ],
      ),
    );
  }
}
