import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/providers/code_provider.dart';
import 'package:finn_ai/src/features/code/settings/code_about_page.dart';
import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/settings/code_agent_page.dart';
import 'package:finn_ai/src/features/code/settings/code_linux_page.dart';
import 'package:finn_ai/src/features/code/settings/code_data_page.dart';
import 'package:finn_ai/src/features/code/settings/code_providers_page.dart';
import 'package:finn_ai/src/features/code/settings/code_workspace_page.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_models_page.dart';
import 'package:finn_ai/src/features/code/ui/code_text.dart';
import 'package:finn_ai/src/shared/theme/flux_vivid.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The settings of FinnAI Code. They are not FinnAI's settings: the two apps
/// keep their own, so changing a provider here never touches the assistant.
class CodeSettingsPage extends StatelessWidget {
  const CodeSettingsPage({super.key, required this.services, this.onBack});

  final CodeServices services;
  final VoidCallback? onBack;

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(FinnPageRoute<void>(child: page));

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        services.providers,
        services.settings,
        services.container.installer,
      ]),
      builder: (context, _) {
        final providers = services.providers;
        final connected = [
          for (final provider in CodeProvider.remote)
            if (providers.isConfigured(provider)) provider,
        ];
        final active = providers.active;
        final activeLabel = active.isLocal
            ? l10n.codeLocalLabel
            : (providers.modelFor(active)?.name ?? active.modelId);
        return FinnPage(
          title: l10n.codeSettingsTitle,
          onBack: onBack,
          children: [
            FinnReveal(
              child: FinnTile(
                icon: CodeIcons.key,
                hue: FluxHue.amber,
                title: l10n.codeSettingsProviders,
                subtitle: connected.isEmpty
                    ? l10n.codeSettingsProvidersSubNone
                    : l10n.codeSettingsProvidersSub('${connected.length}'),
                onTap: () =>
                    _push(context, CodeProvidersPage(services: services)),
              ),
            ),
            FinnReveal(
              index: 1,
              child: FinnTile(
                icon: FluxIcons.chip,
                hue: FluxHue.violet,
                title: l10n.codeSettingsModel,
                subtitle: activeLabel,
                onTap: () => _push(context, CodeModelsPage(services: services)),
              ),
            ),
            FinnReveal(
              index: 2,
              child: FinnTile(
                icon: FluxIcons.robot,
                hue: FluxHue.teal,
                title: l10n.codeSettingsAgent,
                subtitle: CodeText.permission(
                  l10n,
                  services.settings.settings.permissionMode,
                ),
                onTap: () => _push(context, CodeAgentPage(services: services)),
              ),
            ),
            FinnReveal(
              index: 3,
              child: FinnTile(
                key: const ValueKey('code-settings-container'),
                icon: CodeIcons.container,
                title: services.linux.platformSupported
                    ? l10n.codeLinuxTitle
                    : l10n.codeSettingsContainer,
                subtitle: switch (services.runner.environment) {
                  CommandEnvironment.linux => l10n.codeSettingsLinuxSubReady,
                  CommandEnvironment.container =>
                    l10n.codeSettingsContainerSubReady,
                  _ => l10n.codeSettingsContainerSubMissing,
                },
                onTap: () => _push(context, codeLinuxPageFor(services)),
              ),
            ),
            FinnReveal(
              index: 4,
              child: FinnTile(
                icon: CodeIcons.folder,
                hue: FluxHue.sky,
                title: l10n.codeSettingsWorkspace,
                onTap: () =>
                    _push(context, CodeWorkspacePage(services: services)),
              ),
            ),
            FinnReveal(
              index: 5,
              child: FinnTile(
                icon: FluxIcons.lock,
                hue: FluxHue.green,
                title: l10n.codeSettingsData,
                subtitle: l10n.codeSettingsDataSub,
                onTap: () => _push(context, CodeDataPage(services: services)),
              ),
            ),
            FinnReveal(
              index: 6,
              child: FinnTile(
                icon: FluxIcons.info,
                hue: FluxHue.graphite,
                title: l10n.codeSettingsAbout,
                onTap: () => _push(context, const CodeAboutPage()),
              ),
            ),
          ],
        );
      },
    );
  }
}
