import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/agent/live_output.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/sessions/code_session_store.dart';
import 'package:finn_ai/src/features/code/ui/code_blocks.dart';
import 'package:finn_ai/src/features/code/ui/code_style.dart';
import 'package:finn_ai/src/features/code/ui/code_text.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The user's own terminal: commands they run in the session's project
/// folder, through the agent's runner (same sandbox, same rules), and the
/// scrollback. Shared by the panel and the full page so switching between
/// them keeps the history. Not saved: a terminal's scrollback is not part of
/// the project.
class CodeTerminalLog extends ChangeNotifier {
  CodeTerminalLog({required this.sessions, required this.runner});

  final CodeSessionStore sessions;
  final CodeActionRunner runner;

  final List<CodeAction> _entries = [];
  final List<String> _history = [];
  bool _running = false;

  List<CodeAction> get entries => List.unmodifiable(_entries);
  bool get running => _running;

  /// Commands run so far, oldest first, for ↑ / ↓.
  List<String> get history => List.unmodifiable(_history);

  /// Runs [command] in the active session's folder, starting a session when
  /// there is none (its folder is where the agent will look next).
  Future<void> run(String command) async {
    final text = command.trim();
    if (text.isEmpty || _running) return;
    final session = sessions.activeOrLatest ?? sessions.create();
    if (_history.isEmpty || _history.last != text) _history.add(text);
    _running = true;
    _entries.add(CodeAction.shell(text).copyWith(
      status: CodeActionStatus.running,
    ));
    notifyListeners();
    final live = LiveOutput(
      (text) {
        if (!_running) return;
        _entries[_entries.length - 1] = _entries.last.copyWith(output: text);
        notifyListeners();
      },
      interval: const Duration(milliseconds: 100),
    );
    final result = await runner.run(
      session.id,
      CodeAction.shell(text),
      onOutput: live.add,
    );
    live.close();
    _entries[_entries.length - 1] = result;
    _running = false;
    notifyListeners();
  }

  void clear() {
    if (_running) return;
    _entries.clear();
    notifyListeners();
  }
}

/// The scrollback and the prompt, at Code's density. Used by the panel and
/// the page.
class CodeTerminalView extends StatefulWidget {
  const CodeTerminalView({
    super.key,
    required this.log,
    this.autofocus = false,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(14, 8, 14, 10),
  });

  final CodeTerminalLog log;
  final bool autofocus;

  /// Shown above the scrollback (the intro, or a set-up tile).
  final Widget? header;
  final EdgeInsets padding;

  @override
  State<CodeTerminalView> createState() => _CodeTerminalViewState();
}

class _CodeTerminalViewState extends State<CodeTerminalView> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  /// Position in the history while ↑ / ↓ browse it; null when typing.
  int? _browsing;

  @override
  void initState() {
    super.initState();
    widget.log.addListener(_changed);
    _focus.onKeyEvent = _onKey;
  }

  @override
  void dispose() {
    widget.log.removeListener(_changed);
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    // Keep the newest output in view, as a terminal does.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: CodeStyle.motion(context),
        curve: CodeStyle.curve,
      );
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final history = widget.log.history;
    if (history.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final next = _browsing == null
          ? history.length - 1
          : (_browsing! - 1).clamp(0, history.length - 1);
      _recall(next);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && _browsing != null) {
      final next = _browsing! + 1;
      if (next >= history.length) {
        _browsing = null;
        _input.clear();
      } else {
        _recall(next);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _recall(int index) {
    _browsing = index;
    final text = widget.log.history[index];
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _run() async {
    final command = _input.text;
    if (command.trim().isEmpty || widget.log.running) return;
    _input.clear();
    _browsing = null;
    HapticFeedback.selectionClick();
    await widget.log.run(command);
    if (mounted) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final entries = widget.log.entries;
    final muted = FluxColors.mutedOf(context);
    final style = CodeStyle.code(context);
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            key: const ValueKey('terminal-scrollback'),
            controller: _scroll,
            padding: widget.padding.copyWith(bottom: 6),
            itemCount: entries.length + (widget.header == null ? 0 : 1),
            itemBuilder: (context, index) {
              if (widget.header != null) {
                if (index == 0) return widget.header!;
                index--;
              }
              final entry = entries[index];
              return Padding(
                key: ValueKey('terminal-entry-$index'),
                padding: const EdgeInsets.only(bottom: 6),
                child: entry.status == CodeActionStatus.running
                    ? Stack(
                        children: [
                          CodeOutputBlock(
                            command: entry.command,
                            output: entry.output.trimRight(),
                            maxLines: 40,
                            tail: true,
                          ),
                          Positioned(
                            top: 9,
                            right: 10,
                            child: SizedBox.square(
                              dimension: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: muted,
                              ),
                            ),
                          ),
                        ],
                      )
                    : CodeOutputBlock(
                        command: entry.command,
                        output: entry.status == CodeActionStatus.denied
                            ? CodeText.denied(l10n, entry)
                            : entry.output.trimRight(),
                        truncated: entry.truncated,
                        maxLines: 40,
                        exitCode: entry.status == CodeActionStatus.failed
                            ? entry.exitCode
                            : null,
                        timedOut: entry.timedOut,
                      ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            widget.padding.left,
            0,
            widget.padding.right,
            widget.padding.bottom,
          ),
          // 48dp, and the whole well focuses the prompt, not only its line.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _focus.requestFocus,
            excludeFromSemantics: true,
            child: Container(
              height: FluxMotion.minTapTarget,
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                color: CodeStyle.wellOf(context),
                borderRadius: BorderRadius.circular(CodeStyle.radius),
              ),
              child: Row(
                children: [
                  Text(r'$', style: style.copyWith(color: muted)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('terminal-input'),
                      controller: _input,
                      focusNode: _focus,
                      autofocus: widget.autofocus,
                      enabled: !widget.log.running,
                      style: style,
                      cursorColor: FluxColors.inkOf(context),
                      cursorWidth: 7,
                      cursorRadius: const Radius.circular(1),
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      // Android keyboards drop autocorrect for this type;
                      // HarmonyOS treats it as a password and blacks out
                      // screen capture, so there it stays plain text.
                      keyboardType: Platform.isAndroid
                          ? TextInputType.visiblePassword
                          : TextInputType.text,
                      textInputAction: TextInputAction.go,
                      inputFormatters: [LengthLimitingTextInputFormatter(2000)],
                      onSubmitted: (_) => _run(),
                      decoration: InputDecoration.collapsed(
                        hintText: l10n.codeTerminalHint,
                        hintStyle: style.copyWith(color: muted),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _input,
                    builder: (context, value, _) {
                      final canRun =
                          !widget.log.running && value.text.trim().isNotEmpty;
                      return IconButton(
                        key: const ValueKey('terminal-run-button'),
                        tooltip: l10n.codeActionRun,
                        onPressed: canRun ? _run : null,
                        icon: FluxIcon(
                          icon: FluxIcons.arrowRight02,
                          size: 16,
                          color: canRun ? FluxColors.inkOf(context) : muted,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
