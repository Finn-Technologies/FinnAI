import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/container/container_host.dart';
import 'package:finn_ai/src/features/code/container/container_installer.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_text.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The Linux container: what it is, whether it is downloaded, and whether
/// commands use it.
class CodeContainerPage extends StatefulWidget {
  const CodeContainerPage({super.key, required this.services});

  final CodeServices services;

  @override
  State<CodeContainerPage> createState() => _CodeContainerPageState();
}

class _CodeContainerPageState extends State<CodeContainerPage> {
  ContainerInstaller get _installer => widget.services.container.installer;

  @override
  void initState() {
    super.initState();
    unawaited(_installer.refresh());
  }

  Future<void> _remove() async {
    final l10n = L10n.of(context);
    final confirmed = await showFinnConfirm(
      context,
      title: l10n.codeContainerRemoveTitle,
      body: l10n.codeContainerRemoveBody,
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (confirmed != true) return;
    await widget.services.container.stop();
    await _installer.deleteStorage();
  }

  String _status(AppLocalizations l10n) {
    if (!widget.services.container.platformSupported) {
      return l10n.codeContainerUnsupported;
    }
    final size = CodeText.bytes(_installer.totalBytes);
    return switch (_installer.state) {
      ContainerInstallState.installed => switch (
            widget.services.container.host.phase) {
          ContainerPhase.ready => l10n.codeContainerStatusRunning,
          ContainerPhase.starting => l10n.codeContainerStatusStarting,
          _ => l10n.codeContainerStatusReady,
        },
      ContainerInstallState.downloading => l10n.codeContainerStatusDownloading(
          '${(_installer.progress * 100).round()}'),
      ContainerInstallState.failed => switch (_installer.error) {
          ContainerInstallError.verification =>
            l10n.codeContainerErrorVerification,
          ContainerInstallError.storage => l10n.codeContainerErrorStorage,
          _ => l10n.codeContainerErrorNetwork,
        },
      _ => l10n.codeContainerStatusMissing(size),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final services = widget.services;
    return ListenableBuilder(
      listenable: Listenable.merge(
          [_installer, services.settings, services.container.host]),
      builder: (context, _) {
        final supported = services.container.platformSupported;
        final state = _installer.state;
        final size = CodeText.bytes(_installer.totalBytes);
        final downloading = state == ContainerInstallState.downloading;
        return FinnPage(
          title: l10n.codeContainerTitle,
          children: [
            FinnCaption(l10n.codeContainerIntro),
            FinnReveal(
              child: FinnTile(
                key: const ValueKey('code-container-status'),
                icon: state == ContainerInstallState.failed
                    ? CodeIcons.warning
                    : CodeIcons.container,
                title: l10n.codeContainerTitle,
                subtitle: _status(l10n),
                chevron: false,
                trailing: downloading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: _installer.progress == 0
                              ? null
                              : _installer.progress,
                          color: FluxColors.actionOf(context),
                        ),
                      )
                    : null,
              ),
            ),
            if (supported && state != ContainerInstallState.installed)
              FinnReveal(
                index: 1,
                child: FinnTile(
                  key: const ValueKey('code-container-download'),
                  icon: downloading ? FluxIcons.close : FluxIcons.download,
                  title: downloading
                      ? l10n.codeContainerCancel
                      : l10n.codeContainerDownload(size),
                  chevron: false,
                  onTap: downloading
                      ? _installer.cancel
                      : () => unawaited(_installer.install()),
                ),
              ),
            if (supported && state == ContainerInstallState.installed) ...[
              FinnReveal(
                index: 1,
                child: FinnTile(
                  key: const ValueKey('code-container-switch'),
                  icon: CodeIcons.terminal,
                  title: l10n.codeContainerUse,
                  subtitle: l10n.codeContainerUseSub,
                  chevron: false,
                  trailing: FinnSwitch(
                    value: services.settings.settings.useContainer,
                    label: l10n.codeContainerUse,
                    onChanged: (value) => services.settings
                        .update((s) => s.copyWith(useContainer: value)),
                  ),
                ),
              ),
              if (services.container.host.phase == ContainerPhase.ready)
                FinnReveal(
                  index: 2,
                  child: FinnTile(
                    icon: FluxIcons.refresh,
                    title: l10n.codeContainerRestart,
                    subtitle: l10n.codeContainerRestartSub,
                    chevron: false,
                    onTap: () => unawaited(services.container.host.restart()),
                  ),
                ),
              FinnReveal(
                index: 3,
                child: FinnTile(
                  key: const ValueKey('code-container-remove'),
                  icon: CodeIcons.trash,
                  title: l10n.codeContainerRemove,
                  destructive: true,
                  chevron: false,
                  onTap: _remove,
                ),
              ),
            ],
            FinnCaption(l10n.codeContainerLicence),
          ],
        );
      },
    );
  }
}
