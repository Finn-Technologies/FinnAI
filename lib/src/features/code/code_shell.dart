import 'dart:async';
import 'dart:math' as math;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/code/code_services.dart';
import 'package:finn_ai/src/features/code/sessions/code_session.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_page.dart';
import 'package:finn_ai/src/features/code/ui/code_composer.dart';
import 'package:finn_ai/src/features/code/ui/code_conversation.dart';
import 'package:finn_ai/src/features/code/ui/code_files_page.dart';
import 'package:finn_ai/src/features/code/ui/code_models_page.dart';
import 'package:finn_ai/src/features/code/ui/code_session_options.dart';
import 'package:finn_ai/src/features/code/ui/code_sidebar.dart';
import 'package:finn_ai/src/features/code/ui/code_terminal_page.dart';
import 'package:finn_ai/src/features/code/ui/code_terminal_panel.dart';
import 'package:finn_ai/src/features/code/ui/code_icons.dart';
import 'package:finn_ai/src/features/code/ui/code_status_line.dart';
import 'package:finn_ai/src/features/code/ui/code_style.dart';
import 'package:finn_ai/src/features/code/ui/code_suggestions.dart';
import 'package:finn_ai/src/features/code/agent/code_agent.dart';
import 'package:finn_ai/src/features/code/settings/code_agent_page.dart';
import 'package:finn_ai/src/inference/model_catalog.dart';
import 'package:finn_ai/src/platform/platform_target.dart';
import 'package:finn_ai/src/shared/layout/finn_layout.dart';
import 'package:finn_ai/src/shared/widgets/desktop_shortcuts.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_sidebar_surface.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// FinnAI Code: a coding agent in FinnAI's design language.
///
/// It is its own app inside the app. It has its own sessions, its own
/// settings and its own providers; it shares only the on-device model with
/// FinnAI. The shell mirrors the chat shell — a sliding sidebar, a header, a
/// transcript, a composer — so moving between the two feels like one product.
class CodeShell extends StatefulWidget {
  const CodeShell({super.key, this.services, this.initializeServices = true});

  /// Overridable for tests; the real app uses [CodeServices.instance].
  final CodeServices? services;

  /// False in tests that hand over services that are already set up.
  final bool initializeServices;

  @override
  State<CodeShell> createState() => _CodeShellState();
}

class _CodeShellState extends State<CodeShell>
    with SingleTickerProviderStateMixin {
  late final CodeServices _services = widget.services ?? CodeServices.instance;
  final _composer = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  late final FinnSidebarMotion _sidebar = FinnSidebarMotion(
    vsync: this,
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  @override
  void initState() {
    super.initState();
    if (widget.initializeServices) {
      unawaited(_services.initialize().then((_) => _warmContainer()));
    }
    _services.agent.addListener(_focusComposerOnDesktop);
    _focusComposerOnDesktop();
  }

  /// With a keyboard in front of them the user expects to type at once, and the
  /// window shortcuts only work while focus is inside the shell: take focus
  /// back whenever nothing else holds it (at start, when a turn ends, when a
  /// page closes). A phone keeps its keyboard down until the field is tapped.
  void _focusComposerOnDesktop() {
    if (!isDesktop) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _sidebar.open || _services.agent.busy) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      final holder = FocusManager.instance.primaryFocus?.context;
      if (holder?.findAncestorWidgetOfExactType<EditableText>() != null) return;
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _services.agent.removeListener(_focusComposerOnDesktop);
    // Leaving FinnAI Code ends a request in progress: a command waiting for a
    // tap would otherwise wait for a screen that is gone, and a running model
    // would hold the engine against FinnAI's chat.
    unawaited(_services.agent.stop());
    // The Linux container is ~150 MB of emulated machine; chat has no use
    // for it.
    unawaited(_services.container.stop());
    _scrollController.dispose();
    _composer.dispose();
    _focusNode.dispose();
    _sidebar.dispose();
    super.dispose();
  }

  /// Boots the Linux container in the background when Code opens, so the
  /// first command does not wait for a cold boot (seconds on a phone). It is
  /// stopped again when Code closes.
  void _warmContainer() {
    if (!mounted) return;
    final container = _services.container;
    if (!container.ready || !_services.settings.settings.useContainer) return;
    unawaited(container.host.start().catchError((Object _) {
      // A failed warm-up is retried by the first command, which reports it.
    }));
  }

  /// Files picked for the next message; copied into the project folder when
  /// it is sent.
  final List<File> _attachments = [];

  Future<void> _attach() async {
    try {
      final result = await FilePicker.pickFiles(allowMultiple: true);
      if (result == null || !mounted) return;
      setState(() {
        for (final picked in result.files) {
          final path = picked.path;
          if (path != null) _attachments.add(File(path));
        }
      });
    } catch (_) {
      // The picker could not open (no file provider); nothing was chosen.
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );

  Future<void> _send() async {
    final text = _composer.text.trim();
    if ((text.isEmpty && _attachments.isEmpty) || _services.agent.busy) {
      return;
    }
    HapticFeedback.lightImpact();
    final attachments = List<File>.of(_attachments);
    final failedMessage = L10n.of(context).codeAttachFailed;
    _composer.clear();
    setState(_attachments.clear);
    // Sending hands the screen to the transcript: the keyboard goes away on
    // a phone instead of covering the agent's first action.
    if (!FinnLayout.isDocked(MediaQuery.sizeOf(context).width)) {
      _focusNode.unfocus();
    }
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    final failed = await _services.agent.send(text, attachments: attachments);
    if (failed.isNotEmpty && mounted) _snack(failedMessage(failed.join(', ')));
  }

  void _newSession() {
    _services.sessions.clearActive();
    _sidebar.set(context, false);
  }

  void _openSession(String id) {
    _services.sessions.activate(id);
    _sidebar.set(context, false);
  }

  /// Pushes [page] from a sidebar destination, closing the panel behind it
  /// once the page has settled: one motion from the panel to the page.
  Future<void> _pushFromSidebar(Widget page) => Navigator.of(context)
      .push(
        FinnPageRoute<void>(child: page, onSettled: _sidebar.snapClosed),
      )
      .whenComplete(_focusComposerOnDesktop);

  Future<void> _push(Widget page) => Navigator.of(context)
      .push(FinnPageRoute<void>(child: page))
      .whenComplete(_focusComposerOnDesktop);

  Future<void> _openFiles({bool fromSidebar = true}) {
    final page = CodeFilesPage(
      services: _services,
      onBack: () => Navigator.of(context).pop(),
    );
    return fromSidebar ? _pushFromSidebar(page) : _push(page);
  }

  Future<void> _openTerminal() => _pushFromSidebar(
        CodeTerminalPage(
          services: _services,
          onBack: () => Navigator.of(context).pop(),
        ),
      );

  Future<void> _openModels({bool fromSidebar = false}) {
    final page = CodeModelsPage(
      services: _services,
      onBack: () => Navigator.of(context).pop(),
    );
    return fromSidebar ? _pushFromSidebar(page) : _push(page);
  }

  Future<void> _openSettings() => _pushFromSidebar(
        CodeSettingsPage(
          services: _services,
          onBack: () => Navigator.of(context).pop(),
        ),
      );

  void _sessionOptions(CodeSession session) => showCodeSessionOptions(
        context,
        session: session,
        services: _services,
        onOpenFiles: () {
          _services.sessions.activate(session.id);
          _openFiles(fromSidebar: false);
        },
      );

  String _modelLabel(BuildContext context) {
    final ref = _services.providers.active;
    if (ref.isLocal) return L10n.of(context).codeLocalLabel;
    return _services.providers.modelFor(ref)?.name ?? ref.modelId;
  }

  bool _terminalOpen = false;

  void _setTerminal(bool open) {
    if (open == _terminalOpen) return;
    HapticFeedback.selectionClick();
    if (open) _focusNode.unfocus();
    setState(() => _terminalOpen = open);
  }

  Future<void> _expandTerminal() async {
    setState(() => _terminalOpen = false);
    await _push(CodeTerminalPage(
      services: _services,
      onBack: () => Navigator.of(context).pop(),
    ));
  }

  List<CodeSlashCommand> _commands(BuildContext context) {
    final l10n = L10n.of(context);
    return [
      CodeSlashCommand(
        name: 'new',
        description: l10n.codeSlashNewDesc,
        icon: FluxIcons.add,
        run: _newSession,
      ),
      CodeSlashCommand(
        name: 'files',
        description: l10n.codeSlashFilesDesc,
        icon: CodeIcons.folder,
        run: () => _openFiles(fromSidebar: false),
      ),
      CodeSlashCommand(
        name: 'terminal',
        description: l10n.codeSlashTerminalDesc,
        icon: CodeIcons.terminal,
        run: () => _setTerminal(true),
      ),
      CodeSlashCommand(
        name: 'model',
        description: l10n.codeSlashModelDesc,
        icon: FluxIcons.chip,
        run: _openModels,
      ),
      CodeSlashCommand(
        name: 'mode',
        description: l10n.codeSlashModeDesc,
        icon: CodeIcons.shield,
        run: () => _push(CodeAgentPage(services: _services)),
      ),
      CodeSlashCommand(
        name: 'retry',
        description: l10n.codeSlashRetryDesc,
        icon: CodeIcons.retry,
        run: () => unawaited(_services.agent.resume()),
      ),
      CodeSlashCommand(
        name: 'settings',
        description: l10n.codeSlashSettingsDesc,
        icon: FluxIcons.settings,
        run: () => _push(CodeSettingsPage(
          services: _services,
          onBack: () => Navigator.of(context).pop(),
        )),
      ),
    ];
  }

  Future<List<String>> _projectFiles() async {
    final session = _services.sessions.active;
    if (session == null) return const [];
    try {
      return await (await _services.sessions.workspaceOf(session.id))
          .allFiles(limit: 300);
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sidebar.open && !_terminalOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_terminalOpen) {
          _setTerminal(false);
        } else if (_sidebar.open) {
          _sidebar.set(context, false);
        }
      },
      child: DesktopShortcuts(
        onNew: _newSession,
        onToggleSidebar: () => _sidebar.set(context, !_sidebar.open),
        onSettings: _openSettings,
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final safeTop = MediaQuery.paddingOf(context).top;
              final safeBottom = FluxBottomInset.bottomOf(context);
              final gutter = constraints.maxWidth < 380 ? 12.0 : 16.0;
              final docked = FinnLayout.isDocked(constraints.maxWidth);
              final bodyWidth = FinnLayout.bodyWidth(constraints.maxWidth);
              final contentWidth = math.min(820.0, bodyWidth - gutter * 2);
              final contentLeft = (bodyWidth - contentWidth) / 2;
              final sidebarWidth =
                  FinnLayout.sidebarWidth(constraints.maxWidth);
              final headerTop = safeTop + 8;
              final panelHeight = math.min(
                constraints.maxHeight * .48,
                460.0 + safeBottom,
              );

              final home = RepaintBoundary(
                child: ColoredBox(
                  color: FluxColors.tileOf(context),
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      _services.sessions,
                      _services.agent,
                      _services.providers,
                      _services.settings,
                    ]),
                    builder: (context, _) {
                      final session = _services.sessions.active;
                      final empty = session == null || session.messages.isEmpty;
                      final agent = _services.agent;
                      final status = CodeStatusLine(
                        // The chip icon already says "on this device"; the
                        // line names the model itself.
                        modelLabel: _services.providers.active.isLocal
                            ? finnModels.single.name
                            : _modelLabel(context),
                        modelIsLocal: _services.providers.active.isLocal,
                        environment: _services.runner.environment,
                        permission: _services.settings.settings.permissionMode,
                        phase: agent.runningSessionId == null ||
                                agent.runningSessionId == session?.id
                            ? agent.phase
                            : CodeAgentPhase.idle,
                        onModel: _openModels,
                        onPermission: (mode) => _services.settings
                            .update((s) => s.copyWith(permissionMode: mode)),
                        onTerminal: () => _setTerminal(!_terminalOpen),
                      );
                      return Stack(
                        children: [
                          Positioned(
                            left: contentLeft,
                            width: contentWidth,
                            top: 0,
                            bottom: 0,
                            child: CodeConversation(
                              session: session,
                              agent: agent,
                              topInset: headerTop + CodeStyle.control + 14,
                              // The field and the status line under it.
                              bottomInset: safeBottom + 10 + 44 + 30,
                              scrollController: _scrollController,
                            ),
                          ),
                          Positioned(
                            left: contentLeft,
                            width: contentWidth,
                            top: headerTop,
                            child: _Header(
                              showMenuSlot: !docked,
                              title: empty ? null : session.title,
                              onNewSession: empty ? null : _newSession,
                              onTitleTap: session == null
                                  ? null
                                  : () => _sessionOptions(session),
                            ),
                          ),
                          Positioned(
                            left: contentLeft,
                            width: contentWidth,
                            bottom: safeBottom + 4,
                            child: CodeComposer(
                              controller: _composer,
                              focusNode: _focusNode,
                              busy: agent.busy,
                              onSend: _send,
                              onStop: agent.stop,
                              status: status,
                              commands: _commands(context),
                              files: _projectFiles,
                              width: contentWidth,
                              attachments: [
                                for (final file in _attachments)
                                  file.uri.pathSegments.last,
                              ],
                              onAttach: _attach,
                              onRemoveAttachment: (i) =>
                                  setState(() => _attachments.removeAt(i)),
                            ),
                          ),
                          Positioned(
                            left: docked ? contentLeft : 0,
                            right: docked
                                ? bodyWidth - contentLeft - contentWidth
                                : 0,
                            bottom: 0,
                            child: CodeTerminalSlot(
                              open: _terminalOpen,
                              height: panelHeight,
                              panel: CodeTerminalPanel(
                                services: _services,
                                bottomInset: safeBottom,
                                onClose: () => _setTerminal(false),
                                onExpand: _expandTerminal,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );

              final sidebar = !_sidebar.everOpened && !docked
                  ? const SizedBox.shrink()
                  : RepaintBoundary(
                      child: SizedBox(
                        width: sidebarWidth,
                        child: ListenableBuilder(
                          listenable: _services.sessions,
                          builder: (context, _) => CodeSidebar(
                            sessions: _services.sessions.sessions,
                            activeSessionId: _services.sessions.activeId,
                            onSession: _openSession,
                            onSessionOptions: _sessionOptions,
                            onNewSession: _newSession,
                            onFiles: _openFiles,
                            onTerminal: _openTerminal,
                            onModels: () => _openModels(fromSidebar: true),
                            onSettings: _openSettings,
                          ),
                        ),
                      ),
                    );

              return AnimatedBuilder(
                animation: _sidebar.controller,
                builder: (context, _) => FinnSidebarSurface(
                  docked: docked,
                  home: home,
                  sidebar: sidebar,
                  sidebarWidth: sidebarWidth,
                  progress: _sidebar.controller.value,
                  sidebarOpen: _sidebar.open,
                  toggleLeft: contentLeft,
                  toggleTop: headerTop,
                  toggleDimension: CodeStyle.control + 4,
                  onToggle: () => _sidebar.set(context, !_sidebar.open),
                  onDragStart: _sidebar.dragStart,
                  onDragUpdate: (d) => _sidebar.dragUpdate(d, sidebarWidth),
                  onDragEnd: (d) => _sidebar.dragEnd(context, d, sidebarWidth),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The top row: the toggle's slot, the session's name, and a new-session
/// button once there is a session on screen. 40dp, a step down from the
/// chat app's 50.
class _Header extends StatelessWidget {
  const _Header({
    this.title,
    this.onNewSession,
    this.onTitleTap,
    this.showMenuSlot = true,
  });

  /// False when the sidebar is docked: there is no toggle to leave room for.
  final bool showMenuSlot;
  final String? title;
  final VoidCallback? onNewSession;
  final VoidCallback? onTitleTap;

  static const double _size = CodeStyle.control + 4;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return SizedBox(
      height: _size,
      child: Row(
        children: [
          if (showMenuSlot) const SizedBox(width: _size),
          if (title != null && title.isNotEmpty) ...[
            if (showMenuSlot) const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                button: onTitleTap != null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTitleTap,
                  child: Text(
                    title,
                    key: const ValueKey('code-session-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: CodeStyle.sans,
                      fontSize: 15,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            if (onNewSession != null) const SizedBox(width: 10),
          ] else
            const Spacer(),
          if (onNewSession != null)
            Semantics(
              button: true,
              label: L10n.of(context).codeNewSession,
              onTap: onNewSession,
              excludeSemantics: true,
              child: FluxPressScale(
                child: Material(
                  color: FluxColors.controlOf(context),
                  shape: const CircleBorder(),
                  child: SizedBox.square(
                    key: const ValueKey('code-new-session-button'),
                    dimension: _size,
                    child: InkWell(
                      onTap: onNewSession,
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: FluxIcon(
                          icon: FluxIcons.edit,
                          size: 18,
                          color: FluxColors.inkOf(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
