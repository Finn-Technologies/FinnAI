import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/settings/code_container_page.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/ui/code_action_card.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_motion.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/flux_surfaces.dart';

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
  final _scroll = ScrollController();

  /// Commands run on this visit, oldest first. Not stored: a terminal's
  /// scrollback is not part of the project.
  final List<CodeAction> _log = [];
  bool _running = false;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final command = _input.text.trim();
    if (command.isEmpty || _running) return;
    // A terminal with no session yet starts one: its folder is where the
    // command runs, and where the agent will find what it made.
    final sessions = widget.services.sessions;
    final session = sessions.activeOrLatest ?? sessions.create();
    _input.clear();
    final pending =
        CodeAction.shell(command).copyWith(status: CodeActionStatus.running);
    setState(() {
      _running = true;
      _log.add(pending);
    });
    _followLatest();
    final result =
        await widget.services.runner.run(session.id, CodeAction.shell(command));
    if (!mounted) return;
    setState(() {
      _running = false;
      _log[_log.length - 1] = result;
    });
    _followLatest();
    // Ready for the next command without another tap.
    _focus.requestFocus();
  }

  /// Keeps the newest command and its output in view, as a terminal does.
  void _followLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final environment = widget.services.runner.environment;
    final supported = environment != CommandEnvironment.none;
    final container = widget.services.container;
    // On a device that could host the container but has not got it, say so
    // where commands are typed: that is where its absence matters.
    final offerContainer = container.platformSupported &&
        !container.installer.installed &&
        widget.services.settings.settings.useContainer;
    final usable = supported;
    // The same shape as every other composer: a pill to type in, and the
    // send control as its own circle beside it, never inside the field.
    final footer = usable
        ? ValueListenableBuilder<TextEditingValue>(
            valueListenable: _input,
            builder: (context, value, _) {
              final canRun = !_running && value.text.trim().isNotEmpty;
              return Row(
                children: [
                  Expanded(
                    child: FluxPillField(
                      fieldKey: const ValueKey('terminal-input'),
                      controller: _input,
                      focusNode: _focus,
                      hint: l10n.codeTerminalHint,
                      monospace: true,
                      fontSize: 15,
                      maxLength: 2000,
                      enabled: !_running,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _run(),
                      leading: Text(
                        r'$',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          color: FluxColors.mutedOf(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FluxSwap(
                    swapKey: canRun,
                    child: FinnCircleButton.icon(
                      key: const ValueKey('terminal-run-button'),
                      icon: FluxIcons.arrowUp02,
                      label: l10n.codeActionRun,
                      onTap: canRun ? _run : null,
                      dark: true,
                      dimmed: !canRun,
                    ),
                  ),
                ],
              );
            },
          )
        : null;
    return FinnPage(
      title: l10n.codeTerminalTitle,
      onBack: widget.onBack,
      controller: _scroll,
      footer: footer,
      children: [
        FinnCaption(
          !supported
              ? l10n.codeTerminalUnsupported
              : (environment == CommandEnvironment.container
                  ? l10n.codeTerminalIntroContainer
                  : l10n.codeTerminalIntro),
        ),
        if (offerContainer)
          FinnTile(
            key: const ValueKey('terminal-set-up-container'),
            icon: CodeIcons.container,
            title: l10n.codeTerminalSetUpContainer,
            subtitle: l10n.codeTerminalSetUpContainerSub,
            onTap: () async {
              await Navigator.of(context).push(FinnPageRoute<void>(
                child: CodeContainerPage(services: widget.services),
              ));
              if (mounted) setState(() {});
            },
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
