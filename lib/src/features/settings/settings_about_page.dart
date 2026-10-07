import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/shared/config/legal_config.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/theme/flux_vivid.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

class SettingsAboutPage extends StatelessWidget {
  const SettingsAboutPage({super.key, required this.version});

  final String version;

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            L10n.of(context).settingsPrivacyPolicyLaunchFailed(url),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return FinnPage(
      title: l10n.hubAboutTitle,
      children: [
        FinnReveal(
          child: Container(
            decoration: BoxDecoration(
              color: FluxColors.controlOf(context),
              borderRadius: BorderRadius.circular(FluxRadius.card),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.appBrandFinnAI,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.aboutBlurb,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: FluxColors.actionOf(context),
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.modelVersion(version),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: FluxColors.secondaryInkOf(context),
                      ),
                ),
              ],
            ),
          ),
        ),
        if (LegalConfig.hasPrivacyPolicyUrl)
          FinnReveal(
            index: 1,
            child: FinnTile(
              icon: FluxIcons.lock,
              hue: FluxHue.green,
              title: l10n.aboutPrivacy,
              onTap: () => unawaited(
                _open(context, LegalConfig.privacyPolicyUrl),
              ),
            ),
          ),
        if (LegalConfig.hasTermsUrl)
          FinnReveal(
            index: 2,
            child: FinnTile(
              icon: FluxIcons.note,
              hue: FluxHue.blue,
              title: l10n.aboutTerms,
              onTap: () => unawaited(_open(context, LegalConfig.termsUrl)),
            ),
          ),
        FinnReveal(
          index: 3,
          child: FinnTile(
            icon: FluxIcons.sourceCode,
            hue: FluxHue.graphite,
            title: l10n.aboutLicences,
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appBrandFinnAI,
              applicationVersion: version,
              applicationLegalese:
                  'Created using LFM2.5-VL 1.6B by Liquid AI, Inc. under the '
                  'LFM Open License v1.0.\nPowered by llama.cpp and Flutter.',
            ),
          ),
        ),
        FinnReveal(
          index: 4,
          child: FinnTile(
            icon: FluxIcons.feedback,
            hue: FluxHue.orange,
            title: l10n.aboutFeedback,
            onTap: () => unawaited(
              _open(
                context,
                LegalConfig.hasSupportEmail
                    ? 'mailto:${LegalConfig.resolvedSupportEmail}'
                    : LegalConfig.resolvedSupportUrl,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
