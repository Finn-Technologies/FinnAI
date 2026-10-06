import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/settings/code_container_page.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_style.dart';
import 'package:finn_ai/src/features/code/ui/code_terminal.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
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
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: FluxColors.tileOf(context),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          SizedBox(height: top + 8),
          CodeTerminalBar(
            title: l10n.codeTerminalTitle,
            leading: CodeBarButton(
              key: const ValueKey('terminal-back'),
              icon: CodeIcons.back,
              label: l10n.commonBack,
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            log: services.terminal,
          ),
          Expanded(
            child: CodeTerminalView(
              log: services.terminal,
              autofocus: true,
              header: CodeTerminalIntro(services: services),
              padding: EdgeInsets.fromLTRB(14, 8, 14, 10 + bottom),
            ),
          ),
        ],
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
        height: 40,
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

/// A 36dp icon control for Code's compact bars.
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
          width: CodeStyle.control,
          height: CodeStyle.control,
        ),
        padding: EdgeInsets.zero,
        icon: FluxIcon(
          icon: icon,
          size: 17,
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
    final offerContainer = container.platformSupported &&
        !container.installer.installed &&
        services.settings.settings.useContainer;
    final text = switch (environment) {
      CommandEnvironment.none => l10n.codeTerminalUnsupported,
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
                child: CodeContainerPage(services: services),
              )),
              icon: FluxIcon(icon: CodeIcons.container, size: 14),
              label: Text(
                l10n.codeTerminalSetUpContainer,
                style: CodeStyle.label(context),
              ),
            ),
        ],
      ),
    );
  }
}
