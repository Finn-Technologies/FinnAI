import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/settings/settings_about_page.dart';
import 'package:finn_ai/src/features/settings/settings_access_page.dart';
import 'package:finn_ai/src/features/settings/settings_data_page.dart';
import 'package:finn_ai/src/features/settings/settings_model_page.dart';
import 'package:finn_ai/src/features/settings/settings_voice_page.dart';
import 'package:finn_ai/src/features/settings/storage_usage.dart';
import 'package:finn_ai/src/features/voice/voice_settings_store.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// Settings: a short list of destinations, each with a line of live status.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.onBack,
    this.onOpenActions,
    this.onOpenYou,
  });

  final VoidCallback onBack;

  /// Opens the device actions screen. Null when the host has no route to it.
  final VoidCallback? onOpenActions;

  /// Opens the You screen. Null when the host has no route to it.
  final VoidCallback? onOpenYou;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '1.0';
  int? _modelBytes;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    PackageInfo? info;
    try {
      info = await PackageInfo.fromPlatform();
    } catch (_) {}
    final usage = await StorageUsage.measure();
    if (!mounted) return;
    setState(() {
      if (info != null) _version = info.version;
      _modelBytes = usage.model;
    });
  }

  void _push(Widget page) => Navigator.of(context)
      .push(FinnPageRoute<void>(child: page))
      .then((_) => _load());

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final modelBytes = _modelBytes;
    return FinnPage(
      title: l10n.settingsTitle,
      onBack: widget.onBack,
      children: [
        FinnReveal(
          child: FinnTile(
            icon: FluxIcons.chip,
            title: l10n.hubModelTitle,
            subtitle: modelBytes == null || modelBytes == 0
                ? null
                : l10n.hubModelSub(StorageUsage.label(modelBytes)),
            onTap: () => _push(const SettingsModelPage()),
          ),
        ),
        FinnReveal(
          index: 1,
          child: ListenableBuilder(
            listenable: VoiceSettingsStore.instance,
            builder: (context, _) => FinnTile(
              icon: FluxIcons.volume,
              title: l10n.hubVoiceTitle,
              subtitle: l10n.hubVoiceSub(
                voiceSpeedLabel(l10n, VoiceSettingsStore.instance.speed),
                _languageName(context),
              ),
              onTap: () => _push(const SettingsVoicePage()),
            ),
          ),
        ),
        FinnReveal(
          index: 2,
          child: FinnTile(
            icon: FluxIcons.internet,
            title: l10n.hubAccessTitle,
            subtitle: l10n.hubAccessSub,
            onTap: () => _push(
              SettingsAccessPage(onOpenActions: widget.onOpenActions),
            ),
          ),
        ),
        FinnReveal(
          index: 3,
          child: FinnTile(
            icon: FluxIcons.you,
            title: l10n.hubYouTitle,
            subtitle: l10n.hubYouSub,
            onTap: widget.onOpenYou,
          ),
        ),
        FinnReveal(
          index: 4,
          child: FinnTile(
            icon: FluxIcons.lock,
            title: l10n.hubDataTitle,
            subtitle: l10n.hubDataSub,
            onTap: () => _push(const SettingsDataPage()),
          ),
        ),
        FinnReveal(
          index: 5,
          child: FinnTile(
            icon: FluxIcons.info,
            title: l10n.hubAboutTitle,
            subtitle: l10n.hubAboutSub(_version),
            onTap: () => _push(SettingsAboutPage(version: _version)),
          ),
        ),
      ],
    );
  }

  String _languageName(BuildContext context) =>
      switch (Localizations.localeOf(context).languageCode) {
        'de' => 'Deutsch',
        'es' => 'Español',
        'fr' => 'Français',
        'it' => 'Italiano',
        _ => 'English',
      };
}
