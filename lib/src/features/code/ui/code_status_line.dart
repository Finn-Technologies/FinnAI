import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/agent/code_agent.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_style.dart';
import 'package:finn_ai/src/features/code/ui/code_text.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// One line under the input: which model answers, where commands run, what
/// the agent may do, and what it is doing now. Model and mode are tappable.
class CodeStatusLine extends StatelessWidget {
  const CodeStatusLine({
    super.key,
    required this.modelLabel,
    required this.modelIsLocal,
    required this.environment,
    required this.permission,
    required this.phase,
    required this.onModel,
    required this.onPermission,
    this.onTerminal,
  });

  final String modelLabel;
  final bool modelIsLocal;
  final CommandEnvironment environment;
  final CodePermissionMode permission;
  final CodeAgentPhase phase;
  final VoidCallback onModel;
  final ValueChanged<CodePermissionMode> onPermission;

  /// Opens the terminal panel; null hides the control.
  final VoidCallback? onTerminal;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final muted = FluxColors.mutedOf(context);
    final (String state, Color dot) = switch (phase) {
      CodeAgentPhase.idle => (l10n.codeStatusIdle, muted),
      CodeAgentPhase.thinking => (
          l10n.codeStatusThinking,
          FluxColors.infoOf(context)
        ),
      CodeAgentPhase.running => (
          l10n.codeStatusRunning,
          FluxColors.successOf(context)
        ),
      CodeAgentPhase.awaitingApproval => (
          l10n.codeStatusWaiting,
          FluxColors.warningOf(context)
        ),
    };
    final environmentLabel = switch (environment) {
      CommandEnvironment.linux ||
      CommandEnvironment.container =>
        l10n.codeEnvLinux,
      CommandEnvironment.device => l10n.codeEnvDevice,
      CommandEnvironment.none => l10n.codeEnvNone,
    };
    final style = CodeStyle.meta(context);
    final separator = Text(' · ', style: style);

    return SizedBox(
      height: 26,
      child: Row(
        children: [
          AnimatedContainer(
            duration: CodeStyle.motion(context),
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: _Segment(
                    key: const ValueKey('code-model-chip'),
                    icon: modelIsLocal ? FluxIcons.chip : CodeIcons.cloud,
                    label: modelLabel,
                    semanticLabel: l10n.codeModelChipSemantic(modelLabel),
                    onTap: onModel,
                  ),
                ),
                // While the agent works its state needs the room more than
                // the environment does.
                if (phase == CodeAgentPhase.idle) ...[
                  separator,
                  Text(
                    environmentLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ],
                separator,
                Builder(
                  builder: (anchorContext) {
                    final label = CodeText.permission(l10n, permission);
                    return _Segment(
                      key: const ValueKey('code-permission-chip'),
                      label: label,
                      semanticLabel: l10n.codePermissionSemantic(label),
                      onTap: () => showFinnMenu(
                        context,
                        anchor: finnAnchorOf(anchorContext),
                        items: [
                          for (final mode in CodePermissionMode.values)
                            FinnMenuItem(
                              label: CodeText.permission(l10n, mode),
                              icon: switch (mode) {
                                CodePermissionMode.askEveryTime =>
                                  CodeIcons.shield,
                                CodePermissionMode.acceptEdits =>
                                  CodeIcons.fileEdit,
                                CodePermissionMode.autoRun => CodeIcons.play,
                              },
                              selected: mode == permission,
                              onTap: () => onPermission(mode),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                // Idle says nothing: the grey dot already does.
                if (phase != CodeAgentPhase.idle) ...[
                  separator,
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: CodeStyle.motion(context, CodeStyle.fast),
                      child: Text(
                        state,
                        key: ValueKey(phase),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(
                          color: phase == CodeAgentPhase.idle ? muted : dot,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTerminal != null)
            Semantics(
              button: true,
              label: l10n.codeTerminalShow,
              excludeSemantics: true,
              child: InkResponse(
                key: const ValueKey('code-terminal-toggle'),
                onTap: onTerminal,
                radius: 18,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: FluxIcon(
                      icon: CodeIcons.terminal, size: 15, color: muted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.icon,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style =
        CodeStyle.meta(context, color: FluxColors.secondaryInkOf(context));
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                FluxIcon(icon: icon!, size: 12, color: style.color),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
