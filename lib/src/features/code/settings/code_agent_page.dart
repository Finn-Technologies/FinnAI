import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// How much the agent may do before it asks, how long it may go on, and
/// whether its commands may reach the network.
class CodeAgentPage extends StatelessWidget {
  const CodeAgentPage({super.key, required this.services});

  final CodeServices services;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final store = services.settings;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final settings = store.settings;
        final modes =
            <(CodePermissionMode, String, String, List<List<dynamic>>)>[
          (
            CodePermissionMode.askEveryTime,
            l10n.codeAgentAsk,
            l10n.codeAgentAskSub,
            CodeIcons.shield,
          ),
          (
            CodePermissionMode.acceptEdits,
            l10n.codeAgentEdits,
            l10n.codeAgentEditsSub,
            CodeIcons.file,
          ),
          (
            CodePermissionMode.autoRun,
            l10n.codeAgentAuto,
            l10n.codeAgentAutoSub,
            CodeIcons.play,
          ),
        ];
        return FinnPage(
          title: l10n.codeAgentTitle,
          children: [
            FluxSectionLabel(l10n.codeAgentPermissionTitle),
            for (final (i, (mode, title, subtitle, icon)) in modes.indexed)
              FinnReveal(
                index: i,
                child: FinnTile(
                  key: ValueKey('code-permission-${mode.name}'),
                  icon: icon,
                  title: title,
                  subtitle: subtitle,
                  chevron: false,
                  trailing: settings.permissionMode == mode
                      ? FluxIcon(
                          icon: FluxIcons.check,
                          size: 22,
                          strokeWidth: 1.5,
                          color: FluxColors.actionOf(context),
                        )
                      : null,
                  onTap: () => store.update(
                    (s) => s.copyWith(permissionMode: mode),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            FinnReveal(
              index: 3,
              child: _Choices<int?>(
                title: l10n.codeAgentSteps,
                subtitle: l10n.codeAgentStepsSub,
                value: settings.maxSteps,
                choices: [
                  (null, l10n.codeAgentStepsAuto),
                  for (final n in CodeSettings.stepChoices)
                    (n, l10n.codeAgentStepsValue('$n')),
                ],
                onChanged: (value) =>
                    store.update((s) => s.copyWith(maxSteps: () => value)),
              ),
            ),
            FinnReveal(
              index: 4,
              child: _Choices<int>(
                title: l10n.codeAgentTimeout,
                value: settings.commandTimeoutSeconds,
                choices: [
                  for (final n in CodeSettings.timeoutChoices)
                    (n, l10n.codeAgentTimeoutValue('$n')),
                ],
                onChanged: (value) => store.update(
                  (s) => s.copyWith(commandTimeoutSeconds: value),
                ),
              ),
            ),
            FinnReveal(
              index: 5,
              child: FinnTile(
                key: const ValueKey('code-network-switch'),
                icon: FluxIcons.internet,
                title: l10n.codeAgentNetwork,
                subtitle: l10n.codeAgentNetworkSub,
                trailing: FinnSwitch(
                  value: settings.allowNetwork,
                  label: l10n.codeAgentNetwork,
                  onChanged: (value) =>
                      store.update((s) => s.copyWith(allowNetwork: value)),
                ),
              ),
            ),
            FinnCaption(l10n.codeSandboxNote),
          ],
        );
      },
    );
  }
}

/// A card with a title and a row of pills, one of which is chosen.
class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.title,
    required this.value,
    required this.choices,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final T value;
  final List<(T, String)> choices;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      decoration: BoxDecoration(
        color: FluxColors.controlOf(context),
        borderRadius: BorderRadius.circular(FluxRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.bodyMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: theme.bodySmall?.copyWith(
                color: FluxColors.secondaryInkOf(context),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (choice, label) in choices)
                FluxChip(
                  label: label,
                  dense: true,
                  selected: choice == value,
                  onTap: () => onChanged(choice),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
