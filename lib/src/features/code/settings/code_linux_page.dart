import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/linux/linux_installer.dart';
import 'package:finn_ai/src/features/code/settings/code_container_page.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_text.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The page for wherever commands run: the native Linux sandbox where this
/// device can run it, the emulated container elsewhere.
Widget codeLinuxPageFor(CodeServices services) =>
    services.linux.platformSupported
        ? CodeLinuxPage(services: services)
        : CodeContainerPage(services: services);

/// The Linux sandbox: what it is, whether it is set up, and whether commands
/// use it.
class CodeLinuxPage extends StatefulWidget {
  const CodeLinuxPage({super.key, required this.services});

  final CodeServices services;

  @override
  State<CodeLinuxPage> createState() => _CodeLinuxPageState();
}

class _CodeLinuxPageState extends State<CodeLinuxPage> {
  LinuxInstaller get _installer => widget.services.linux.installer;

  @override
  void initState() {
    super.initState();
    unawaited(_installer.refresh());
  }

  Future<void> _remove() async {
    final l10n = L10n.of(context);
    final confirmed = await showFinnConfirm(
      context,
      title: l10n.codeLinuxRemoveTitle,
      body: l10n.codeLinuxRemoveBody,
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (confirmed != true) return;
    await _installer.deleteStorage();
  }

  String _status(AppLocalizations l10n) {
    final size = CodeText.bytes(_installer.totalBytes);
    return switch (_installer.state) {
      LinuxInstallState.installed =>
        l10n.codeLinuxStatusReady(LinuxImage.version),
      LinuxInstallState.downloading => l10n.codeContainerStatusDownloading(
          '${(_installer.progress * 100).round()}'),
      LinuxInstallState.preparing => l10n.codeLinuxStatusPreparing,
      LinuxInstallState.failed => switch (_installer.error) {
          LinuxInstallError.verification => l10n.codeContainerErrorVerification,
          LinuxInstallError.storage => l10n.codeContainerErrorStorage,
          _ => l10n.codeContainerErrorNetwork,
        },
      _ => l10n.codeLinuxStatusMissing(size),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final services = widget.services;
    return ListenableBuilder(
      listenable: Listenable.merge([_installer, services.settings]),
      builder: (context, _) {
        final state = _installer.state;
        final busy = state == LinuxInstallState.downloading ||
            state == LinuxInstallState.preparing;
        final installed = state == LinuxInstallState.installed;
        return FinnPage(
          title: l10n.codeLinuxTitle,
          children: [
            FinnCaption(l10n.codeLinuxIntro),
            FinnReveal(
              child: FinnTile(
                key: const ValueKey('code-linux-status'),
                icon: state == LinuxInstallState.failed
                    ? CodeIcons.warning
                    : CodeIcons.terminal,
                title: l10n.codeLinuxTitle,
                subtitle: _status(l10n),
                chevron: false,
                trailing: busy
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: state == LinuxInstallState.downloading &&
                                  _installer.progress > 0
                              ? _installer.progress
                              : null,
                          color: FluxColors.actionOf(context),
                        ),
                      )
                    : null,
              ),
            ),
            if (!installed)
              FinnReveal(
                index: 1,
                child: FinnTile(
                  key: const ValueKey('code-linux-set-up'),
                  icon: busy ? FluxIcons.close : FluxIcons.download,
                  title: busy
                      ? l10n.codeContainerCancel
                      : l10n.codeLinuxSetUp(
                          CodeText.bytes(_installer.totalBytes)),
                  chevron: false,
                  onTap: state == LinuxInstallState.preparing
                      ? null
                      : busy
                          ? _installer.cancel
                          : () => unawaited(_installer.install()),
                ),
              ),
            if (installed) ...[
              FinnReveal(
                index: 1,
                child: FinnTile(
                  key: const ValueKey('code-linux-switch'),
                  icon: CodeIcons.terminal,
                  title: l10n.codeLinuxUse,
                  subtitle: l10n.codeContainerUseSub,
                  chevron: false,
                  trailing: FinnSwitch(
                    value: services.settings.settings.useContainer,
                    label: l10n.codeLinuxUse,
                    onChanged: (value) => services.settings
                        .update((s) => s.copyWith(useContainer: value)),
                  ),
                ),
              ),
              FinnReveal(
                index: 2,
                child: FinnTile(
                  key: const ValueKey('code-linux-remove'),
                  icon: CodeIcons.trash,
                  title: l10n.codeLinuxRemove,
                  destructive: true,
                  chevron: false,
                  onTap: _remove,
                ),
              ),
            ],
            FinnCaption(l10n.codeLinuxLicence),
          ],
        );
      },
    );
  }
}
