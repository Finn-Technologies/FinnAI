import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/voice/tts/tts_voice_catalog.dart';
import 'package:finn_ai/src/features/voice/voice_settings_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/theme/flux_vivid.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The localized name of a speaking speed.
String voiceSpeedLabel(AppLocalizations l10n, VoiceSpeed speed) =>
    switch (speed) {
      VoiceSpeed.slow => l10n.voiceSpeedSlow,
      VoiceSpeed.normal => l10n.voiceSpeedNormal,
      VoiceSpeed.fast => l10n.voiceSpeedFast,
    };

/// The localized name of a Supertonic speaking style (`ttsStyles`).
String ttsStyleLabel(AppLocalizations l10n, String style) => switch (style) {
      'F1' => l10n.voiceStyleF1,
      'M1' => l10n.voiceStyleM1,
      'M2' => l10n.voiceStyleM2,
      _ => l10n.voiceStyleF2,
    };

class SettingsVoicePage extends StatelessWidget {
  const SettingsVoicePage({super.key});

  Future<void> _pickSpeed(BuildContext context) async {
    final l10n = L10n.of(context);
    final store = VoiceSettingsStore.instance;
    await showFinnSheet<void>(
      context,
      title: l10n.voiceSpeed,
      children: (sheetContext) => [
        for (final speed in VoiceSpeed.values) ...[
          FinnTile(
            title: voiceSpeedLabel(l10n, speed),
            trailing: store.speed == speed
                ? FluxIcon(
                    icon: FluxIcons.check,
                    size: 22,
                    color: FluxColors.actionOf(sheetContext),
                  )
                : null,
            onTap: () {
              unawaited(store.setSpeed(speed));
              Navigator.pop(sheetContext);
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Future<void> _pickStyle(BuildContext context) async {
    final l10n = L10n.of(context);
    final store = VoiceSettingsStore.instance;
    await showFinnSheet<void>(
      context,
      title: l10n.voiceStyle,
      children: (sheetContext) => [
        for (final style in ttsStyles) ...[
          FinnTile(
            title: ttsStyleLabel(l10n, style),
            trailing: store.ttsStyle == style
                ? FluxIcon(
                    icon: FluxIcons.check,
                    size: 22,
                    color: FluxColors.actionOf(sheetContext),
                  )
                : null,
            onTap: () {
              unawaited(store.setTtsStyle(style));
              Navigator.pop(sheetContext);
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return ListenableBuilder(
      listenable: VoiceSettingsStore.instance,
      builder: (context, _) {
        final store = VoiceSettingsStore.instance;
        return FinnPage(
          title: l10n.hubVoiceTitle,
          children: [
            FinnReveal(
              child: FinnTile(
                icon: FluxIcons.translate,
                hue: FluxHue.blue,
                title: l10n.voiceLanguage,
                subtitle: l10n.voiceLanguageSub,
              ),
            ),
            FinnReveal(
              index: 1,
              child: FinnTile(
                icon: FluxIcons.voiceId,
                hue: FluxHue.pink,
                title: l10n.voiceStyle,
                subtitle: ttsStyleLabel(l10n, store.ttsStyle),
                onTap: () => unawaited(_pickStyle(context)),
              ),
            ),
            FinnReveal(
              index: 2,
              child: FinnTile(
                icon: FluxIcons.speed,
                hue: FluxHue.orange,
                title: l10n.voiceSpeed,
                subtitle: voiceSpeedLabel(l10n, store.speed),
                onTap: () => unawaited(_pickSpeed(context)),
              ),
            ),
            FinnReveal(
              index: 3,
              child: FinnTile(
                icon: FluxIcons.volume,
                hue: FluxHue.violet,
                title: l10n.voiceReadAloud,
                subtitle: l10n.voiceReadAloudSub,
                trailing: FinnSwitch(
                  value: store.spokenResponses,
                  label: l10n.voiceReadAloud,
                  onChanged: (v) => unawaited(store.setSpokenResponses(v)),
                ),
              ),
            ),
            FinnReveal(
              index: 4,
              child: FinnTile(
                icon: FluxIcons.subtitle,
                hue: FluxHue.teal,
                title: l10n.voiceTranscript,
                subtitle: l10n.voiceTranscriptSub,
                trailing: FinnSwitch(
                  value: store.liveTranscript,
                  label: l10n.voiceTranscript,
                  onChanged: (v) => unawaited(store.setLiveTranscript(v)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
