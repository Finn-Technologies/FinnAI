import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/ui/code_action_card.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// A shell in the session's project folder, for the user.
///
/// It goes through the same runner as the agent, so the same rules apply: the
/// project folder, the policy, the time limit. What you run here is what the
/// agent will find next time it looks.
class CodeTerminalPage extends StatefulWidget {
  const CodeTerminalPage({super.key, required this.services, this.onBack});

  final CodeServices services;
  final VoidCallback? onBack;

  @override
  State<CodeTerminalPage> createState() => _CodeTerminalPageState();
}

class _CodeTerminalPageState extends State<CodeTerminalPage> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  /// Commands run on this visit, oldest first. Not stored: a terminal's
  /// scrollback is not part of the project.
  final List<CodeAction> _log = [];
  bool _running = false;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final session = widget.services.sessions.activeOrLatest;
    final command = _input.text.trim();
    if (session == null || command.isEmpty || _running) return;
    _input.clear();
    final pending =
        CodeAction.shell(command).copyWith(status: CodeActionStatus.running);
    setState(() {
      _running = true;
      _log.add(pending);
    });
    final result =
        await widget.services.runner.run(session.id, CodeAction.shell(command));
    if (!mounted) return;
    setState(() {
      _running = false;
      _log[_log.length - 1] = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final session = widget.services.sessions.activeOrLatest;
    final supported = widget.services.runner.canRunCommands;
    final usable = session != null && supported;
    final footer = usable
        ? Container(
            padding: const EdgeInsets.fromLTRB(17, 1, 4, 1),
            constraints: const BoxConstraints(minHeight: 50),
            decoration: BoxDecoration(
              color: FluxColors.controlOf(context),
              borderRadius: BorderRadius.circular(FluxRadius.pill),
            ),
            child: Row(
              children: [
                Text(
                  r'$ ',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    color: FluxColors.mutedOf(context),
                  ),
                ),
                Expanded(
                  child: TextField(
                    key: const ValueKey('terminal-input'),
                    controller: _input,
                    focusNode: _focus,
                    enabled: !_running,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _run(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 15,
                      color: FluxColors.inkOf(context),
                    ),
                    cursorColor: FluxColors.inkOf(context),
                    decoration: InputDecoration.collapsed(
                      hintText: l10n.codeTerminalHint,
                      hintStyle: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        color: FluxColors.inkOf(context).withValues(alpha: .5),
                      ),
                    ),
                  ),
                ),
                FinnCircleButton.icon(
                  icon: FluxIcons.arrowUp02,
                  label: l10n.codeActionRun,
                  onTap: _running ? null : _run,
                  dark: true,
                ),
              ],
            ),
          )
        : null;
    return FinnPage(
      title: l10n.codeTerminalTitle,
      onBack: widget.onBack,
      footer: footer,
      children: [
        FinnCaption(
          !supported
              ? l10n.codeTerminalUnsupported
              : (session == null
                  ? l10n.codeFilesNoSession
                  : l10n.codeTerminalIntro),
        ),
        for (final (i, action) in _log.indexed)
          FinnReveal(
            key: ValueKey('terminal-entry-$i'),
            child: CodeActionCard(action: action),
          ),
      ],
    );
  }
}
