import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/app/app_state_store.dart';
import 'package:finn_ai/src/app/bootstrap.dart';
import 'package:finn_ai/src/app/data_export.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/settings/storage_usage.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// What FinnAI stores, and the ways to take it out or wipe it.
class SettingsDataPage extends StatefulWidget {
  const SettingsDataPage({super.key});

  @override
  State<SettingsDataPage> createState() => _SettingsDataPageState();
}

class _SettingsDataPageState extends State<SettingsDataPage> {
  StorageUsage _usage = const StorageUsage();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final usage = await StorageUsage.measure();
    if (mounted) setState(() => _usage = usage);
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );

  Future<void> _export() async {
    final shared = await exportEverything();
    if (!shared && mounted) _snack(L10n.of(context).dataExportFailed);
  }

  Future<void> _deleteChats() async {
    final l10n = L10n.of(context);
    final ok = await showFinnConfirm(
      context,
      title: l10n.settingsClearHistoryTitle,
      body: l10n.settingsClearHistoryBody,
      confirmLabel: l10n.commonClearAll,
      destructive: true,
    );
    if (ok != true || !mounted) return;
    bool cleared;
    try {
      cleared = await ConversationStore.instance.clearAllAndFlush();
    } catch (_) {
      cleared = false;
    }
    if (!mounted) return;
    _snack(
      cleared
          ? l10n.settingsClearHistorySuccess
          : l10n.settingsClearHistoryFailure,
    );
    unawaited(_load());
  }

  Future<void> _erase() async {
    final l10n = L10n.of(context);
    final navigator = Navigator.of(context);
    final ok = await showFinnConfirm(
      context,
      title: l10n.settingsDeleteAllDataTitle,
      body: l10n.settingsDeleteAllDataBody,
      confirmLabel: l10n.commonDeleteEverything,
      destructive: true,
    );
    if (ok != true || !mounted) return;
    DeletionResult result;
    try {
      result = await AppStateStore.instance.deleteAllData();
    } catch (e) {
      result = DeletionResult(
        deletedItems: const [],
        nonExistentItems: const [],
        failedItems: ['All local data ($e)'],
      );
    }
    if (!mounted) return;
    if (result.isSuccess) {
      _snack(l10n.settingsDeleteAllDataSuccess);
      unawaited(
        navigator.pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const FinnBootstrap()),
          (route) => false,
        ),
      );
    } else {
      _snack(
        l10n.settingsDeleteAllDataPartialFailure(result.failedItems.join(', ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final rows = [
      (l10n.dataChats, _usage.chats),
      (l10n.dataCreations, _usage.creations),
      (l10n.dataYou, _usage.you),
      (l10n.dataModel, _usage.model),
    ];
    return FinnPage(
      title: l10n.hubDataTitle,
      children: [
        FinnCaption(l10n.dataStoredHere),
        FinnReveal(
          child: Container(
            decoration: BoxDecoration(
              color: FluxColors.controlOf(context),
              borderRadius: BorderRadius.circular(FluxRadius.card),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      border: i == rows.length - 1
                          ? null
                          : Border(
                              bottom: BorderSide(
                                color: FluxColors.lineOf(context),
                              ),
                            ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          rows[i].$1,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          StorageUsage.label(rows[i].$2),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        FinnReveal(
          index: 1,
          child: FinnTile(
            icon: FluxIcons.download,
            title: l10n.dataExport,
            subtitle: l10n.dataExportSub,
            onTap: () => unawaited(_export()),
          ),
        ),
        FinnReveal(
          index: 2,
          child: FinnTile(
            icon: FluxIcons.refresh,
            title: l10n.dataDeleteChats,
            subtitle: l10n.dataDeleteChatsSub,
            destructive: true,
            onTap: () => unawaited(_deleteChats()),
          ),
        ),
        FinnReveal(
          index: 3,
          child: FinnTile(
            icon: FluxIcons.security,
            title: l10n.dataErase,
            subtitle: l10n.dataEraseSub,
            destructive: true,
            onTap: () => unawaited(_erase()),
          ),
        ),
      ],
    );
  }
}
