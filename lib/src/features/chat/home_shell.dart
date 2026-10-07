import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:finn_ai/src/features/chat/chat_options.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/conversations/pinned_chats_store.dart';
import 'package:finn_ai/src/features/conversations/conversation_timestamp.dart';
import 'package:finn_ai/src/features/creations/creation_model.dart';
import 'package:finn_ai/src/features/creations/creation_generator.dart';
import 'package:finn_ai/src/features/creations/creation_launcher.dart';
import 'package:finn_ai/src/features/creations/creation_request.dart';
import 'package:finn_ai/src/features/creations/creation_store.dart';
import 'package:finn_ai/src/features/creations/creations_controller.dart';
import 'package:finn_ai/src/features/creations/creations_page.dart';
import 'package:finn_ai/src/features/creations/home_screen_service.dart';
import 'package:finn_ai/src/features/chat/chat_generation_controller.dart';
import 'package:finn_ai/src/features/chat/tool_activity_indicator.dart';
import 'package:finn_ai/src/features/onboarding/context_consent_store.dart';
import 'package:finn_ai/src/inference/device_profile.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/inference/residency_policy.dart';
import 'package:finn_ai/src/features/reporting/report_dialog.dart';
import 'package:finn_ai/src/features/search/search_agent.dart';
import 'package:finn_ai/src/features/search/search_turn.dart';
import 'package:finn_ai/src/features/search/web_search_service.dart';
import 'package:finn_ai/src/features/actions/action_audit_store.dart';
import 'package:finn_ai/src/features/actions/chat_device_actions.dart';
import 'package:finn_ai/src/features/actions/device_action.dart';
import 'package:finn_ai/src/features/actions/device_action_descriptions.dart';
import 'package:finn_ai/src/features/actions/device_actions_page.dart';
import 'package:finn_ai/src/features/settings/settings_page.dart';
import 'package:finn_ai/src/features/chat/flow_wiring.dart';
import 'package:finn_ai/src/features/chat/message_card_view.dart';
import 'package:finn_ai/src/features/conversations/message_card.dart';
import 'package:finn_ai/src/features/flows/flow_author.dart';
import 'package:finn_ai/src/features/flows/flow_scheduler.dart';
import 'package:finn_ai/src/features/flows/flows_page.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/theme/flux_vivid.dart';
import 'package:finn_ai/src/shared/widgets/flux_motion.dart';
import 'package:finn_ai/src/shared/widgets/finn_thinking.dart';
import 'package:finn_ai/src/shared/widgets/keyboard_fuse.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/app/data_export.dart';
import 'package:finn_ai/src/features/chat/widgets/voice_glow.dart';
import 'package:finn_ai/src/features/chat/widgets/voice_orb.dart';
import 'package:finn_ai/src/features/chat/widgets/voice_morph_bar.dart';
import 'package:finn_ai/src/features/voice/read_aloud.dart';
import 'package:finn_ai/src/features/voice/reply_chunker.dart';
import 'package:finn_ai/src/features/voice/voice_chat_controller.dart';
import 'package:finn_ai/src/features/voice/voice_settings_store.dart';
import 'package:finn_ai/src/features/voice/voice_sheet.dart';
import 'package:finn_ai/src/features/you/you_page.dart';
import 'package:finn_ai/src/features/you/you_add_page.dart';
import 'package:finn_ai/src/features/you/you_memory_store.dart';
import 'package:finn_ai/src/features/you/you_profile_store.dart';
import 'package:finn_ai/src/platform/platform_target.dart';
import 'package:finn_ai/src/shared/layout/finn_layout.dart';
import 'package:finn_ai/src/shared/widgets/desktop_shortcuts.dart';
import 'package:finn_ai/src/shared/widgets/enter_to_send.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/finn_bubble.dart';
import 'package:finn_ai/src/shared/widgets/finn_composer_frame.dart';
import 'package:finn_ai/src/shared/widgets/finn_edge_fade.dart';
import 'package:finn_ai/src/shared/widgets/finn_greeting.dart';
import 'package:finn_ai/src/shared/widgets/finn_shell_header.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/finn_sidebar_parts.dart';
import 'package:finn_ai/src/shared/widgets/finn_sidebar_surface.dart';
import 'package:finn_ai/src/shared/widgets/flux_context_menu.dart';

export 'package:finn_ai/src/shared/widgets/finn_page_route.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/safe_markdown_text.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';

part 'shell/attachments.dart';
part 'shell/lifecycle.dart';
part 'shell/device_actions.dart';
part 'shell/sidebar_surface.dart';
part 'shell/send.dart';
part 'shell/voice.dart';
part 'shell/navigation.dart';
part 'shell/flows.dart';
part 'shell/selected_text.dart';
part 'shell/shortcuts.dart';
part 'shell/make.dart';
part 'widgets/header_and_fade.dart';
part 'widgets/conversation.dart';
part 'widgets/bubbles.dart';
part 'widgets/replies.dart';
part 'widgets/sources.dart';
part 'widgets/dialogs.dart';
part 'widgets/plus_sheet.dart';
part 'widgets/composer.dart';
part 'widgets/composer_attachment.dart';
part 'widgets/sidebar.dart';
part 'widgets/sidebar_tiles.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.generationController,
    this.deviceActions,
    this.conversationStore,
    this.inference,
    this.initializeServices = true,
    this.webSearch,
    this.voiceController,
  });

  final ChatGenerationController? generationController;
  final ChatDeviceActions? deviceActions;
  final ConversationStore? conversationStore;
  final FinnInference? inference;
  @visibleForTesting
  final bool initializeServices;
  final WebSearchService? webSearch;
  final VoiceChatController? voiceController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

/// The keyboard's height in logical pixels, from the physical view: a
/// Scaffold that resizes for it hides it from its body's MediaQuery.
double _keyboardHeight(BuildContext context) {
  final view = View.of(context);
  return view.viewInsets.bottom / view.devicePixelRatio;
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _composer = TextEditingController();
  final _focusNode = FocusNode();
  final ScrollController _chatScrollController = ScrollController();
  final ValueNotifier<bool> _chatScrolledAway = ValueNotifier<bool>(false);
  late final _inference = widget.inference ?? FinnInference.instance;
  late final _conversations =
      widget.conversationStore ?? ConversationStore.instance;
  late final _generation =
      widget.generationController ?? ChatGenerationController.instance;
  late final _webSearch = widget.webSearch ?? WebSearchService();
  late final _flows = FlowHost(
    conversations: _conversations,
    webSearch: _webSearch,
  );
  Timer? _flowSyncTimer;
  bool _flowRunInProgress = false;
  Future<void> _flowQueue = Future<void>.value();
  final _searchPlanner = const SearchPlanner();
  late final _searchTurn =
      SearchTurn(agent: SearchAgent(searchService: _webSearch));
  late final _deviceActions = widget.deviceActions ?? const ChatDeviceActions();
  late final _voice = widget.voiceController ?? VoiceChatController.instance;
  String? _voiceReplyGenerationId;
  String? _voiceCappedGenerationId;

  /// True while the composer is listening for voice input inline, and what it
  /// has heard so far.
  bool _voiceListening = false;

  /// True while a turn that was spoken is being sent, so the model is asked
  /// for an answer that reads well aloud.
  bool _spokenTurn = false;
  Timer? _memoryReleaseTimer;
  static const MethodChannel _memoryPressureChannel = MethodChannel(
    'finn_ai/memory.pressure',
  );
  static const MethodChannel _processTextChannel = MethodChannel(
    'finn_ai/process_text',
  );
  Timer? _prewarmTimer;
  bool _sidebar = false;
  bool _sidebarEverOpened = false;

  /// Panel position the current drag started from, so the finger tracks from
  /// wherever the animation already was rather than snapping to an end.
  double _sidebarDragBase = 0;
  bool _preparing = false;
  bool _dismissedSearchNotice = false;

  /// True when this turn's one search got no answer, so the notice shows.
  bool _upfrontSearchFailed = false;

  /// True when the conversation store could not be opened, so replies only
  /// live in memory. The chat still works; the notice says why history is not
  /// being kept.
  bool _historyUnavailable = false;
  bool _dismissedHistoryNotice = false;

  String? _attachedImagePath;
  Uint8List? _attachedImageBytes;
  bool _attachmentMenuOpen = false;

  /// The composer's "+" button, which the "+" sheet grows out of.
  final _plusKey = GlobalKey();
  late bool _storesReady = !widget.initializeServices;

  /// 0 = closed, 1 = open. It is read directly (no easing curve) so a drag
  /// tracks the finger one-to-one; releases and taps settle it with a spring.
  late final AnimationController _sidebarController = AnimationController(
    vsync: this,
  );

  bool get _busy => _preparing || _generation.busy;

  /// A picker failure used to be invisible: the menu closed and nothing
  /// happened, so the tap looked ignored. Always tell the user.
  @override
  void initState() {
    super.initState();
    _generation.addListener(_generationChanged);
    _voice.addListener(_onVoiceChanged);
    _conversations.addListener(_conversationChanged);
    _chatScrollController.addListener(_onChatScroll);
    _startFlowScheduling();
    _listenForShortcuts();
    _focusComposerOnDesktop();
    WidgetsBinding.instance.addObserver(this);
    // Cap decoded image bytes retained in the widget image cache.
    // 20 MiB bounds RSS from chat + composer previews; pressure
    // and paused paths still clear eagerly.
    PaintingBinding.instance.imageCache.maximumSizeBytes = 20 << 20;
    _memoryPressureChannel.setMethodCallHandler((call) async {
      if (call.method == 'onTrimMemory') {
        _prewarmTimer?.cancel();
        _memoryReleaseTimer?.cancel();
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        if (!_generation.busy) {
          unawaited(_inference.handleMemoryPressure());
        }
      }
      return null;
    });
    _processTextChannel.setMethodCallHandler((call) async {
      if (call.method == 'onProcessText') {
        final text = (call.arguments as Map?)?['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          _handleIncomingProcessText(text.trim());
        }
      }
      return null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkPendingProcessText());
    });
    if (widget.initializeServices) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_initializeStores());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
    // `inactive` is a phone call or a notification shade, not a real
    // backgrounding, and stopping the mic there would be wrong: the user is
    // still looking at the screen.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _stopVoiceForLifecycle();
    }
    final residencyAction = residencyActionFor(switch (state) {
      AppLifecycleState.detached => ResidencyLifecycleEvent.detached,
      AppLifecycleState.paused => ResidencyLifecycleEvent.paused,
      AppLifecycleState.resumed => ResidencyLifecycleEvent.resumed,
      _ => ResidencyLifecycleEvent.inactive,
    });
    if (residencyAction == ResidencyLifecycleAction.releaseNow) {
      _memoryReleaseTimer?.cancel();
      _prewarmTimer?.cancel();
      unawaited(_generation.flushActive());
      unawaited(_inference.releaseMemory());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _prewarmTimer?.cancel();
      unawaited(_generation.flushActive());
      if (residencyAction !=
          ResidencyLifecycleAction.scheduleBackgroundRelease) {
        return;
      }
      _memoryReleaseTimer?.cancel();
      final profile = _inference.deviceProfile;
      final constrained = profile?.lowMemory == true ||
          (profile?.availableRamBytes ?? 1 << 40) < 1800 * 1024 * 1024 ||
          (profile != null && DeviceProfiler.isLowEnd(profile));
      _memoryReleaseTimer = Timer(
        Duration(seconds: constrained ? 1 : 20),
        _releaseMemoryWhenIdle,
      );
    } else if (state == AppLifecycleState.resumed) {
      _memoryReleaseTimer?.cancel();
      _schedulePrewarm();
    }
  }

  /// Voice is foreground-only, and the lifecycle is what enforces it.
  ///
  /// Without this the microphone stayed hot when the app was backgrounded:
  /// Android's recognition service kept recording, TTS kept speaking into the
  /// background, and the controller sat in `listening` with the orb frozen
  /// mid-animation — so on return the sheet looked stuck. There is no
  /// background mic service by design; this is the boundary that makes that
  /// true.
  @override
  void didHaveMemoryPressure() {
    _prewarmTimer?.cancel();
    _memoryReleaseTimer?.cancel();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (!_generation.busy) {
      unawaited(_inference.handleMemoryPressure());
    }
  }

  @override
  void dispose() {
    _generation.removeListener(_generationChanged);
    _voice.removeListener(_onVoiceChanged);
    _conversations.removeListener(_conversationChanged);
    _chatScrollController.removeListener(_onChatScroll);
    _stopFlowScheduling();
    _stopListeningForShortcuts();
    _chatScrollController.dispose();
    _chatScrolledAway.dispose();
    _memoryPressureChannel.setMethodCallHandler(null);
    _processTextChannel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    _memoryReleaseTimer?.cancel();
    _prewarmTimer?.cancel();
    _sidebarController.dispose();
    unawaited(_generation.flushActive());
    if (widget.webSearch == null) _webSearch.close();
    _composer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// How far (in pixels) the user must scroll away from the newest message
  /// before the composer collapses to its compact size.
  static const _chatBottomThreshold = 140.0;

  /// Discrete (non-token) generation state the shell's layout depends on.
  /// Token growth only changes [ChatGenerationJob.responseText], which the
  /// streaming bubble tracks itself, so the shell does not rebuild at ~20 Hz
  /// while tokens stream in.
  String? _lastGenerationSignature;

  /// Runs a recognised device command and writes the turn it produces.
  ///
  /// Navigation runs immediately; anything that changes device state is written
  /// as a proposal and waits for the user to tap.
  /// Decides, and if needed runs, the one web search this turn gets.
  ///
  /// The model never decides to search (ADR 0001): [SearchPlanner] is a pure
  /// function of the prompt, and [SearchTurn] runs at most one time-boxed
  /// round. The step is recorded before the search so the reply carries what
  /// it came from, and an unreachable web is flagged for the offline notice.
  /// Re-runs the model on the same user turn, replacing the last assistant
  /// reply in place. The search decision runs again so a weak answer can be
  /// re-grounded.
  /// Replaces a user message and drops everything after it, then answers the
  /// edited turn in the same conversation.
  /// Mirrors what the microphone hears into the composer while listening, so
  /// the draft is visible and editable before it is sent.
  /// Ends inline listening and sends what was heard.
  /// Hands the microphone over to the full-screen voice mode, which keeps the
  /// orb and the spoken replies.
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sidebar,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _sidebar) _setSidebar(false);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final sy = FinnLayout.shellScaleY(constraints.maxHeight,
                constraints.maxWidth, _keyboardHeight(context));
            final safeBottom = FluxBottomInset.bottomOf(context);
            // Clear of the navigation bar; with the keyboard up on a phone
            // (the physical view's: the Scaffold hides it from this
            // MediaQuery) just above it, fused taller (ChatComposer).
            final keyboardUp =
                !isDesktop && View.of(context).viewInsets.bottom > 0;
            final composerBottom = keyboardUp ? 6.0 : safeBottom + 13;
            final fusedExtra = keyboardUp ? 52.0 : 0.0;
            final horizontalGutter = constraints.maxWidth < 380 ? 20.0 : 25.0;
            final docked = FinnLayout.isDocked(constraints.maxWidth);
            final bodyWidth = FinnLayout.bodyWidth(constraints.maxWidth);
            final contentWidth =
                math.min(760.0, bodyWidth - horizontalGutter * 2);
            final contentLeft = (bodyWidth - contentWidth) / 2;
            final activeConversation = _conversations.active;
            final activeMessages =
                activeConversation?.messages ?? const <ConversationMessage>[];
            final homeLayer = RepaintBoundary(
              child: ColoredBox(
                color: FluxColors.tileOf(context),
                child: Stack(
                  children: [
                    if (activeMessages.isEmpty)
                      _AmbientWash(height: constraints.maxHeight * 400 / 912),
                    // Voice mode's colour, rising from the bottom edge.
                    Positioned.fill(
                      child: VoiceGlow(voice: _voice, active: _voiceListening),
                    ),
                    // 0. The scrolling chat list, full-bleed so content can
                    // slide beneath the glass regions at the very top and
                    // very bottom.
                    Positioned(
                      left: contentLeft,
                      width: contentWidth,
                      top: 0,
                      bottom: 0,
                      child: _Conversation(
                        messages: activeMessages,
                        activeConversationId: activeConversation?.id,
                        generation: _generation,
                        conversations: _conversations,
                        onStop: _stopReply,
                        onContinue: _continueReply,
                        onRegenerate: _regenerateReply,
                        onRunAction: _runPendingAction,
                        onDismissAction: _dismissPendingAction,
                        onActions: _openDeviceActions,
                        onEdit: _editUserMessage,
                        onOpenConversation: _activateConversation,
                        cards: MessageCardHost(flowActions: _flows.actions),
                        receded: _voiceListening,
                        preparing: _preparing,
                        greeting: _voiceListening
                            ? L10n.of(context).voiceGreeting
                            : L10n.of(context).chatGreeting,
                        // First message starts below the header; newest
                        // message sits above the composer.
                        topInset: 125 * sy,
                        bottomInset: composerBottom + 52 + fusedExtra,
                        scrollController: _chatScrollController,
                        // The notice belongs to the turn that failed to reach
                        // the web, so it renders with that reply instead of
                        // floating over the whole conversation.
                        searchFailed: _upfrontSearchFailed &&
                            !_dismissedSearchNotice &&
                            !_generation.busy,
                        onDismissSearchNotice: () =>
                            setState(() => _dismissedSearchNotice = true),
                        historyUnavailable:
                            _historyUnavailable && !_dismissedHistoryNotice,
                        onDismissHistoryNotice: () =>
                            setState(() => _dismissedHistoryNotice = true),
                      ),
                    ),
                    // Voice mode's glass orb, dropped from the top.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 70 * sy + 96,
                      child: Center(
                        child: VoiceOrb(voice: _voice, active: _voiceListening),
                      ),
                    ),
                    // 4. Header and composer are the topmost layers: crisp over
                    // the glass and always tappable. Browser steps are not
                    // floated here — they belong to the reply that made them.
                    Positioned(
                      left: contentLeft,
                      width: contentWidth,
                      top: 70 * sy,
                      child: _HomeHeader(
                        showMenuSlot: !docked,
                        // The design titles a conversation once it has
                        // messages, and hides the title again while listening.
                        title: activeMessages.isEmpty || _voiceListening
                            ? null
                            : activeConversation?.title,
                        onNewChat:
                            activeMessages.isEmpty ? null : _newConversation,
                        onTitleTap: activeConversation == null
                            ? null
                            : () =>
                                showChatOptions(context, activeConversation),
                      ),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: _chatScrolledAway,
                      // Not animated: it follows the keyboard frame by frame;
                      // an implicit animation left it trailing the keyboard.
                      builder: (context, scrolledAway, _) => Positioned(
                        left: contentLeft,
                        // Rests just above the navigation bar, per [FluxBottomInset.bottomOf].
                        bottom: composerBottom,
                        child: ChatComposer(
                          controller: _composer,
                          focusNode: _focusNode,
                          blocked: _preparing || !_storesReady,
                          preparing: _preparing,
                          // A turn being prepared has no job yet, but it is
                          // already uncancellable from the composer without
                          // this: the same stop control must be reachable from
                          // the first tap until tokens arrive.
                          busy: _generation.busy || _preparing,
                          compact: scrolledAway,
                          attachmentPath: _attachedImagePath,
                          isAttachmentMenuOpen: _attachmentMenuOpen,
                          plusKey: _plusKey,
                          onPickAttachment: _toggleAttachmentMenu,
                          onRemoveAttachment: _removeAttachment,
                          onReturnToLatest: () {
                            _closeAttachmentMenu();
                            _returnToLatest();
                          },
                          width: contentWidth,
                          onSend: _send,
                          onStop: _stopReply,
                          voiceEnabled: voiceSupportedOnPlatform,
                          onMic: _openVoiceMode,
                          voiceListening: _voiceListening,
                          onVoiceToggle: _endVoiceListening,
                          onVoiceTap: _tapVoice,
                          voice: _voice,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: _PlusSheet(
                        open: _attachmentMenuOpen,
                        onClose: _closeAttachmentMenu,
                        onSelectCamera: _pickFromCamera,
                        onSelectPhoto: _pickFromGallery,
                        onSelectFile: _pickFromFileSystem,
                        onCreate: _startCreate,
                        originKey: _plusKey,
                        maxWidth: math.max(560, contentWidth + 50),
                      ),
                    ),
                  ],
                ),
              ),
            );
            return _sidebarSurface(
              constraints: constraints,
              homeLayer: homeLayer,
              contentLeft: contentLeft,
              sy: sy,
              docked: docked,
            );
          },
        ),
      ),
    );
  }
}
