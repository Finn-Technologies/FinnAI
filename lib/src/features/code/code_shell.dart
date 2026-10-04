import 'dart:async';
import 'dart:math' as math;

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
  final _scrolledAway = ValueNotifier<bool>(false);
  late final FinnSidebarMotion _sidebar = FinnSidebarMotion(
    vsync: this,
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  /// How far from the newest message the transcript must scroll before the
  /// composer shrinks.
  static const _awayThreshold = 140.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.initializeServices) unawaited(_services.initialize());
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
    _scrollController.removeListener(_onScroll);
    _services.agent.removeListener(_focusComposerOnDesktop);
    // Leaving FinnAI Code ends a request in progress: a command waiting for a
    // tap would otherwise wait for a screen that is gone, and a running model
    // would hold the engine against FinnAI's chat.
    unawaited(_services.agent.stop());
    _scrollController.dispose();
    _scrolledAway.dispose();
    _composer.dispose();
    _focusNode.dispose();
    _sidebar.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _scrolledAway.value = _scrollController.offset > _awayThreshold;
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _services.agent.busy) return;
    HapticFeedback.lightImpact();
    _composer.clear();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    await _services.agent.send(text);
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sidebar.open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _sidebar.open) _sidebar.set(context, false);
      },
      child: DesktopShortcuts(
        onNew: _newSession,
        onToggleSidebar: () => _sidebar.set(context, !_sidebar.open),
        onSettings: _openSettings,
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final sy = FinnLayout.scaleY(
                  constraints.maxHeight, constraints.maxWidth);
              final safeBottom = FluxBottomInset.bottomOf(context);
              const composerLift = 10.0;
              final gutter = constraints.maxWidth < 380 ? 20.0 : 25.0;
              final docked = FinnLayout.isDocked(constraints.maxWidth);
              final bodyWidth = FinnLayout.bodyWidth(constraints.maxWidth);
              final contentWidth = math.min(760.0, bodyWidth - gutter * 2);
              final contentLeft = (bodyWidth - contentWidth) / 2;
              final sidebarWidth =
                  FinnLayout.sidebarWidth(constraints.maxWidth);

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
                      return Stack(
                        children: [
                          if (empty)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: constraints.maxHeight * 400 / 912,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: FluxColors.ambientWashOf(context),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            left: contentLeft,
                            width: contentWidth,
                            top: 0,
                            bottom: 0,
                            child: CodeConversation(
                              session: session,
                              agent: _services.agent,
                              topInset: 125 * sy,
                              // The chips sit above the composer, so the newest
                              // message clears both.
                              bottomInset: safeBottom + composerLift + 65 + 46,
                              scrollController: _scrollController,
                            ),
                          ),
                          Positioned(
                            left: contentLeft,
                            width: contentWidth,
                            top: 70 * sy,
                            child: _Header(
                              showMenuSlot: !docked,
                              title: empty ? null : session.title,
                              onNewSession: empty ? null : _newSession,
                              onTitleTap: session == null
                                  ? null
                                  : () => _sessionOptions(session),
                            ),
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable: _scrolledAway,
                            builder: (context, away, _) => Positioned(
                              left: contentLeft,
                              bottom: safeBottom + composerLift + 3,
                              child: CodeComposer(
                                controller: _composer,
                                focusNode: _focusNode,
                                busy: _services.agent.busy,
                                onSend: _send,
                                onStop: _services.agent.stop,
                                modelLabel: _modelLabel(context),
                                modelIsLocal:
                                    _services.providers.active.isLocal,
                                permission:
                                    _services.settings.settings.permissionMode,
                                onModel: _openModels,
                                onPermission: (mode) => _services.settings
                                    .update((s) =>
                                        s.copyWith(permissionMode: mode)),
                                width: contentWidth,
                                compact: away,
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
                  toggleTop: 70 * sy,
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

/// The top row: the control slot, the session's name, and a new-session
/// button once there is a session on screen.
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

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          if (showMenuSlot)
            const SizedBox(width: FinnSidebarToggleButton.dimension),
          if (title != null && title.isNotEmpty) ...[
            if (showMenuSlot) const SizedBox(width: 20),
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
                      fontFamily: 'InstrumentSans',
                      fontSize: 18,
                      height: 1.2,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
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
                    dimension: 50,
                    child: InkWell(
                      onTap: onNewSession,
                      customBorder: const CircleBorder(),
                      child: const Center(
                        child: FigmaSvg(
                          asset: FigmaAssets.appNewChat,
                          width: 25,
                          height: 25,
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
