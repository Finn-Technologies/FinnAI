import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/app/bootstrap.dart';
import 'package:finn_ai/src/features/onboarding/context_consent_store.dart';
import 'package:finn_ai/src/features/settings/storage_usage.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/shared/theme/flux_vivid.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The on-device model: what it is, what it costs in storage, and the choices
/// that govern it.
class SettingsModelPage extends StatefulWidget {
  const SettingsModelPage({super.key});

  @override
  State<SettingsModelPage> createState() => _SettingsModelPageState();
}

class _SettingsModelPageState extends State<SettingsModelPage> {
  int _bytes = 0;
  DateTime? _installedAt;
  String _version = '1.0';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    String? version;
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}
    final usage = await StorageUsage.measure();
    final date = await StorageUsage.modelInstalledAt();
    if (!mounted) return;
    setState(() {
      _bytes = usage.model;
      _installedAt = date;
      if (version != null) _version = version;
      _loaded = true;
    });
  }

  Future<void> _remove() async {
    final l10n = L10n.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showFinnConfirm(
      context,
      title: l10n.modelRemoveTitle,
      body: l10n.modelRemoveBody,
      confirmLabel: l10n.modelRemoveConfirm,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await FinnInference.instance.removeAllModels();
    } catch (_) {}
    if (!mounted) return;
    unawaited(
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const FinnBootstrap()),
        (route) => false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final consent = ContextConsentStore.instance;
    final size = StorageUsage.label(_bytes);
    final date = _installedAt;
    return ListenableBuilder(
      listenable: consent,
      builder: (context, _) => FinnPage(
        title: l10n.hubModelTitle,
        children: [
          FinnReveal(
            child: FinnTile(
              icon: FluxIcons.chip,
              hue: FluxHue.violet,
              title: l10n.hubModelTitle,
              subtitle: [
                l10n.modelVersion(_version),
                if (_loaded)
                  _bytes == 0
                      ? l10n.modelNotInstalled
                      : date == null
                          ? l10n.modelStoredNoDate(size)
                          : l10n.modelStored(
                              size,
                              DateFormat.MMMd(l10n.localeName).format(date),
                            ),
              ].join('\n'),
            ),
          ),
          FinnReveal(
            index: 1,
            child: FinnTile(
              icon: FluxIcons.cloudOff,
              hue: FluxHue.teal,
              title: l10n.modelOffline,
              subtitle: l10n.modelOfflineSub,
            ),
          ),
          FinnReveal(
            index: 2,
            child: FinnTile(
              icon: FluxIcons.internet,
              hue: FluxHue.blue,
              title: l10n.modelLookups,
              subtitle: l10n.modelLookupsSub,
              trailing: FinnSwitch(
                value: consent.webLookups,
                label: l10n.modelLookups,
                onChanged: (v) => unawaited(consent.setWebLookups(v)),
              ),
            ),
          ),
          FinnReveal(
            index: 3,
            child: FinnTile(
              icon: FluxIcons.check,
              hue: FluxHue.green,
              title: l10n.modelUpdates,
              subtitle: l10n.modelUpToDate,
            ),
          ),
          if (_bytes > 0)
            FinnReveal(
              index: 4,
              child: FinnTile(
                icon: FluxIcons.delete,
                title: l10n.modelRemove,
                subtitle: l10n.modelRemoveSub(size),
                destructive: true,
                onTap: () => unawaited(_remove()),
              ),
            ),
        ],
      ),
    );
  }
}
