import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/providers/code_provider.dart';
import 'package:finn_ai/src/features/code/settings/code_provider_page.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_text.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// Every place FinnAI Code can get answers from, and whether each is set up.
class CodeProvidersPage extends StatelessWidget {
  const CodeProvidersPage({super.key, required this.services});

  final CodeServices services;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return ListenableBuilder(
      listenable: services.providers,
      builder: (context, _) {
        final store = services.providers;
        return FinnPage(
          title: l10n.codeProvidersTitle,
          children: [
            FinnCaption(l10n.codeProvidersIntro),
            FinnReveal(
              child: FinnTile(
                icon: FluxIcons.chip,
                title: 'FinnAI',
                subtitle: l10n.codeProviderStatusLocal,
                chevron: false,
                trailing: store.active.isLocal
                    ? FluxIcon(
                        icon: FluxIcons.check,
                        size: 22,
                        strokeWidth: 1.5,
                        color: FluxColors.actionOf(context),
                      )
                    : null,
              ),
            ),
            for (final (i, provider) in CodeProvider.remote.indexed)
              FinnReveal(
                index: i + 1,
                child: FinnTile(
                  key: ValueKey('code-provider-${provider.id}'),
                  icon: provider == CodeProvider.custom
                      ? CodeIcons.server
                      : CodeIcons.cloud,
                  title: CodeText.providerName(l10n, provider),
                  subtitle: _status(context, provider),
                  onTap: () => Navigator.of(context).push(
                    FinnPageRoute<void>(
                      child: CodeProviderPage(
                        services: services,
                        provider: provider,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _status(BuildContext context, CodeProvider provider) {
    final l10n = L10n.of(context);
    final settings = services.providers.settingsOf(provider);
    if (services.providers.isConfigured(provider)) {
      return settings.hasKey
          ? l10n.codeProviderStatusConnected(settings.keyHint!)
          : l10n.codeProviderStatusConnectedNoKey;
    }
    return l10n.codeProviderStatusNotSet;
  }
}
