import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/settings/code_linux_page.dart';
import 'package:finn_ai/src/features/code/ui/code_text.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_style.dart';
import 'package:finn_ai/src/features/code/ui/code_terminal.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_header.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The terminal as a page of its own, for long sessions. It shares its
/// scrollback with the panel inside FinnAI Code ([CodeServices.terminal]).
class CodeTerminalPage extends StatelessWidget {
  const CodeTerminalPage({super.key, required this.services, this.onBack});

  final CodeServices services;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: FluxColors.tileOf(context),
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // FinnAI's page header, as every other Code page has it.
          final metrics = FinnPageHeaderMetrics.forHeight(
            constraints.maxHeight,
            constraints.maxWidth,
          );
          return Stack(
            children: [
              Positioned.fill(
                top: metrics.contentTop - 10,
                child: CodeTerminalView(
                  log: services.terminal,
                  autofocus: true,
                  header: CodeTerminalIntro(services: services),
                  padding: EdgeInsets.fromLTRB(25, 8, 25, 10 + bottom),
                ),
              ),
              FinnPageHeader(
                title: l10n.codeTerminalTitle,
                onBack: onBack ?? () => Navigator.of(context).maybePop(),
                metrics: metrics,
                scrollOffset: const RestingHeaderOffset(),
                actions: [
                  ListenableBuilder(
                    listenable: services.terminal,
                    builder: (context, _) {
                      final log = services.terminal;
                      return FinnCircleButton.icon(
                        key: const ValueKey('terminal-clear'),
                        icon: CodeIcons.clear,
                        label: l10n.codeTerminalClear,
                        onTap: log.entries.isEmpty || log.running
                            ? null
                            : log.clear,
                      );
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The terminal's title row: [leading], the title, and clear.
class CodeTerminalBar extends StatelessWidget {
  const CodeTerminalBar({
    super.key,
    required this.title,
    required this.log,
    this.leading,
    this.trailing = const [],
  });

  final String title;
  final CodeTerminalLog log;
  final Widget? leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 4)],
            FluxIcon(
              icon: CodeIcons.terminal,
              size: 15,
              color: FluxColors.mutedOf(context),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(title, style: CodeStyle.label(context)),
            ),
            ListenableBuilder(
              listenable: log,
              builder: (context, _) => CodeBarButton(
                key: const ValueKey('terminal-clear'),
                icon: CodeIcons.clear,
                label: l10n.codeTerminalClear,
                onTap: log.entries.isEmpty || log.running ? null : log.clear,
              ),
            ),
            ...trailing,
          ],
        ),
      ),
    );
  }
}

/// An icon control for the terminal panel's bar: a 48dp target.
class CodeBarButton extends StatelessWidget {
  const CodeBarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: label,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(
          width: FluxMotion.minTapTarget,
          height: FluxMotion.minTapTarget,
        ),
        padding: EdgeInsets.zero,
        icon: FluxIcon(
          icon: icon,
          size: 20,
          color: onTap == null
              ? FluxColors.mutedOf(context).withValues(alpha: .5)
              : FluxColors.inkOf(context),
        ),
      );
}

/// What the terminal runs in, and the way to the Linux sandbox when it is
/// not set up yet.
class CodeTerminalIntro extends StatelessWidget {
  const CodeTerminalIntro({super.key, required this.services});

  final CodeServices services;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final environment = services.runner.environment;
    final container = services.container;
    final linux = services.linux;
    final offerContainer = services.settings.settings.useContainer &&
        (linux.platformSupported
            ? !linux.installer.installed
            : container.platformSupported && !container.installer.installed);
    final text = switch (environment) {
      CommandEnvironment.none => l10n.codeTerminalUnsupported,
      CommandEnvironment.linux => l10n.codeTerminalIntroLinux,
      CommandEnvironment.container => l10n.codeTerminalIntroContainer,
      CommandEnvironment.device => l10n.codeTerminalIntro,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: CodeStyle.meta(context)),
          if (offerContainer)
            TextButton.icon(
              key: const ValueKey('terminal-set-up-container'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => Navigator.of(context).push(FinnPageRoute<void>(
                child: codeLinuxPageFor(services),
              )),
              icon: FluxIcon(icon: CodeIcons.container, size: 14),
              label: Text(
                linux.platformSupported
                    ? l10n.codeLinuxSetUp(
                        CodeText.bytes(linux.installer.totalBytes))
                    : l10n.codeTerminalSetUpContainer,
                style: CodeStyle.label(context),
              ),
            ),
        ],
      ),
    );
  }
}
