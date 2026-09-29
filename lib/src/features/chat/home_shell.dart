import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/conversations/conversation_timestamp.dart';
import 'package:finn_ai/src/features/creations/creations_page.dart';
import 'package:finn_ai/src/features/chat/chat_generation_controller.dart';
import 'package:finn_ai/src/features/chat/tool_activity_indicator.dart';
import 'package:finn_ai/src/features/onboarding/context_consent_store.dart';
import 'package:finn_ai/src/inference/device_profile.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/inference/residency_policy.dart';
import 'package:finn_ai/src/features/reporting/report_dialog.dart';
import 'package:finn_ai/src/features/search/search_agent.dart';
import 'package:finn_ai/src/features/search/web_search_service.dart';
import 'package:finn_ai/src/features/actions/chat_device_actions.dart';
import 'package:finn_ai/src/features/actions/device_action.dart';
import 'package:finn_ai/src/features/actions/device_action_descriptions.dart';
import 'package:finn_ai/src/features/actions/device_actions_page.dart';
import 'package:finn_ai/src/features/settings/settings_page.dart';
import 'package:finn_ai/src/features/flows/flows_page.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/features/voice/voice_chat_controller.dart';
import 'package:finn_ai/src/features/voice/voice_settings_store.dart';
import 'package:finn_ai/src/features/voice/voice_sheet.dart';
import 'package:finn_ai/src/features/you/you_page.dart';
import 'package:finn_ai/src/features/you/you_profile_store.dart';
import 'package:finn_ai/src/shared/widgets/flux_context_menu.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/safe_markdown_text.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';

bool _isImageAttachmentPath(String path) {
  final extension = path.split('.').last.toLowerCase();
  return const {'jpg', 'jpeg', 'png', 'webp', 'heic'}.contains(extension);
}

/// Turns a text selection shared through "Ask Finn AI" into a prompt.
///
/// A bare topic ("quantum entanglement") reads better wrapped as a question,
/// but a selection that is already a question or an instruction has to be sent
/// verbatim: wrapping it produced malformed prompts such as
/// "What is Explain gravity in one sentence?".
String selectedTextPrompt(String text) {
  final value = text.trim();
  if (value.isEmpty) return value;
  if (value.endsWith('?') ||
      value.contains('\n') ||
      _selectedTextRequestOpener.hasMatch(value)) {
    return value;
  }
  return 'What is $value?';
}

final RegExp _selectedTextRequestOpener = RegExp(
  r'^(?:what|why|how|who|where|when|which|whose|can|could|should|would|will|'
  r'is|are|was|were|do|does|did|explain|summari[sz]e|translate|write|tell|'
  r'describe|compare|list|give|help|make|create|draft|fix|review|analy[sz]e)\b',
  caseSensitive: false,
);

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
  late final _deviceActions = widget.deviceActions ?? const ChatDeviceActions();
  late final _voice = widget.voiceController ?? VoiceChatController.instance;
  String? _voiceReplyGenerationId;

  /// True while the composer is listening for voice input inline, and what it
  /// has heard so far.
  bool _voiceListening = false;
  String _voiceDraft = '';
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
  bool _preparing = false;
  bool _dismissedSearchNotice = false;

  /// True when this turn's policy-driven search could not reach the web.
  /// The engine reports the model-driven equivalent through
  /// [FinnInference.lastSearchFailed]; the notice is shown for either.
  bool _upfrontSearchFailed = false;

  /// True when the conversation store could not be opened, so replies only
  /// live in memory. The chat still works; the notice says why history is not
  /// being kept.
  bool _historyUnavailable = false;
  bool _dismissedHistoryNotice = false;

  String? _attachedImagePath;
  Uint8List? _attachedImageBytes;
  bool _attachmentMenuOpen = false;
  late bool _storesReady = !widget.initializeServices;
  late final AnimationController _sidebarController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    reverseDuration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _sidebarAnimation = CurvedAnimation(
    parent: _sidebarController,
    curve: Curves.easeInOutCubicEmphasized,
    reverseCurve: Curves.easeInCubic,
  );

  bool get _busy => _preparing || _generation.busy;

  void _removeAttachment() {
    setState(() {
      _attachedImagePath = null;
      _attachedImageBytes = null;
    });
  }

  void _toggleAttachmentMenu() {
    HapticFeedback.selectionClick();
    setState(() {
      _attachmentMenuOpen = !_attachmentMenuOpen;
    });
  }

  void _closeAttachmentMenu() {
    if (_attachmentMenuOpen) {
      setState(() {
        _attachmentMenuOpen = false;
      });
    }
  }

  Future<void> _pickFromCamera() async {
    _closeAttachmentMenu();
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (photo != null && mounted) {
        final bytes = await photo.readAsBytes();
        // HEIC check: picker should return JPEG but guard anyway
        final isHeic = photo.path.toLowerCase().endsWith('.heic') ||
            photo.path.toLowerCase().endsWith('.heif');
        if (isHeic) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text(L10n.of(context).chatHeicNotSupported),
                  behavior: SnackBarBehavior.floating,
                ),
              );
          }
          return;
        }
        setState(() {
          _attachedImagePath = photo.path;
          _attachedImageBytes = bytes;
        });
        // Warn if multimodal not loaded
        _warnIfMultimodalMissing(photo.path);
      }
    } catch (e) {
      debugPrint('Camera capture error: $e');
      _showAttachmentFailure();
    }
  }

  /// A picker failure used to be invisible: the menu closed and nothing
  /// happened, so the tap looked ignored. Always tell the user.
  void _showAttachmentFailure() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(L10n.of(context).chatAttachmentPickFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _pickFromGallery() async {
    _closeAttachmentMenu();
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image != null && mounted) {
        final isHeic = image.path.toLowerCase().endsWith('.heic') ||
            image.path.toLowerCase().endsWith('.heif');
        if (isHeic) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text(L10n.of(context).chatHeicNotSupported),
                  behavior: SnackBarBehavior.floating,
                ),
              );
          }
          return;
        }
        final bytes = await image.readAsBytes();
        setState(() {
          _attachedImagePath = image.path;
          _attachedImageBytes = bytes;
        });
        _warnIfMultimodalMissing(image.path);
      }
    } catch (e) {
      debugPrint('Gallery picker error: $e');
      _showAttachmentFailure();
    }
  }

  Future<void> _pickFromFileSystem() async {
    _closeAttachmentMenu();
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'heic',
          'txt',
          'md',
          'json',
          'csv',
        ],
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null && mounted) {
        final path = result.files.single.path!;
        final isHeic = path.toLowerCase().endsWith('.heic') ||
            path.toLowerCase().endsWith('.heif');
        if (isHeic) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text(L10n.of(context).chatHeicNotSupported),
                  behavior: SnackBarBehavior.floating,
                ),
              );
          }
          return;
        }
        setState(() {
          _attachedImagePath = path;
          _attachedImageBytes = result.files.single.bytes;
        });
        if (_isImageAttachmentPath(path)) {
          _warnIfMultimodalMissing(path);
        }
      }
    } catch (e) {
      debugPrint('File picker error: $e');
      _showAttachmentFailure();
    }
  }

  @override
  void initState() {
    super.initState();
    _generation.addListener(_generationChanged);
    _conversations.addListener(_conversationChanged);
    _chatScrollController.addListener(_onChatScroll);
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
    // Narrate browsing live: the engine reports each tool call as it happens.
    _inference.onToolActivity = (activity) {
      if (!mounted) return;
      _generation.noteToolActivity(activity);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkPendingProcessText());
    });
    if (widget.initializeServices) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_initializeStores());
      });
    }
  }

  Future<void> _checkPendingProcessText() async {
    try {
      final text = await _processTextChannel.invokeMethod<String>(
        'getPendingText',
      );
      if (text != null && text.trim().isNotEmpty) {
        _handleIncomingProcessText(text.trim());
      }
    } catch (_) {}
  }

  void _handleIncomingProcessText(String text) {
    if (!mounted) return;
    _newConversation();
    _composer.text = selectedTextPrompt(text);
    unawaited(_send());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
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

  Future<void> _initializeStores() async {
    final started = DateTime.now();
    // This future is what unlocks the composer, so a store that throws must
    // not be allowed to leave the field permanently disabled with no
    // explanation: each initializer is isolated, the gate is always released,
    // and a failure is reported instead of swallowed.
    final failed = <String>[];
    Future<void> guard(String name, Future<void> Function() initialize) async {
      try {
        await initialize();
      } catch (error, stack) {
        failed.add(name);
        debugPrint('FINN_STORES_ERROR $name $error');
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'finn stores',
            context: ErrorDescription('initializing the $name store'),
          ),
        );
      }
    }

    await Future.wait([
      guard('conversations', _conversations.initialize),
      guard('you', YouProfileStore.instance.initialize),
      guard('flows', FlowsStore.instance.initialize),
      guard('voice', VoiceSettingsStore.instance.initialize),
      guard('consent', ContextConsentStore.instance.initialize),
    ]);
    debugPrint(
      'FINN_STORES_READY ms=${DateTime.now().difference(started).inMilliseconds} '
      'failed=${failed.isEmpty ? 'none' : failed.join(',')}',
    );
    if (!mounted) return;
    // Every cold start lands on the welcome slate instead of dropping the
    // user back into the last conversation. History stays in the sidebar;
    // tapping a past chat re-activates it.
    _conversations.clearActive();
    setState(() {
      _storesReady = true;
      // Chatting still works when the history file cannot be opened — replies
      // just live in memory — but the user has to be told that.
      _historyUnavailable =
          failed.contains('conversations') || _conversations.storageError;
    });
    _schedulePrewarm();
  }

  void _releaseMemoryWhenIdle() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (_inference.isGeneratingReply) {
      _memoryReleaseTimer = Timer(
        const Duration(seconds: 10),
        _releaseMemoryWhenIdle,
      );
      return;
    }
    unawaited(_inference.releaseMemory());
  }

  void _conversationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _generation.removeListener(_generationChanged);
    _conversations.removeListener(_conversationChanged);
    _chatScrollController.removeListener(_onChatScroll);
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
    _inference.onToolActivity = null;
    _composer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// How far (in pixels) the user must scroll away from the newest message
  /// before the composer collapses to its compact size.
  static const _chatBottomThreshold = 140.0;

  void _onChatScroll() {
    if (!_chatScrollController.hasClients) return;
    final position = _chatScrollController.position;
    _chatScrolledAway.value =
        position.hasContentDimensions && position.pixels > _chatBottomThreshold;
  }

  void _returnToLatest() {
    if (!_chatScrollController.hasClients || !_chatScrolledAway.value) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _chatScrollController.jumpTo(0);
    } else {
      unawaited(
        _chatScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void _schedulePrewarm() {
    _prewarmTimer?.cancel();
    final profile = _inference.deviceProfile;
    if (profile != null && DeviceProfiler.isLowEnd(profile)) {
      return;
    }
    _prewarmTimer = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_inference.prewarm()),
    );
  }

  /// Discrete (non-token) generation state the shell's layout depends on.
  /// Token growth only changes [ChatGenerationJob.responseText], which the
  /// streaming bubble tracks itself, so the shell does not rebuild at ~20 Hz
  /// while tokens stream in.
  String? _lastGenerationSignature;

  String _generationSignature() {
    final job = _generation.job;
    return '${job?.generationId}|${job?.state.name}|${job?.sources.length}|'
        '${_generation.toolActivities.length}|${_generation.busy}';
  }

  void _generationChanged() {
    if (!mounted) return;
    final signature = _generationSignature();
    if (signature != _lastGenerationSignature) {
      _lastGenerationSignature = signature;
      setState(() {});
    }
    _pumpVoiceReply();
    final trace = _generation.activeTrace;
    if (trace?.hasUiPaintScheduled == true &&
        trace?.hasUiPaintCompleted == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _generation.markFirstVisiblePaintCompleted();
      });
    }
  }

  void _warnIfMultimodalMissing(String path) {
    // Fire-and-forget check: if user attached an image but mmproj is absent,
    // surface a toast immediately so expectation is set.
    if (!_isImageAttachmentPath(path)) return;
    // Best-effort: FinnInference mirrors FinnAccelerator; check via inference
    // without importing engine internals. Use a microtask to avoid build-time.
    Future.microtask(() async {
      try {
        // FinnAccelerator exposes multimodalLoaded via engine; check via isMmprojInstalled
        // as a lightweight file probe does not need the engine to be warm.
        final hasMmproj = await _inference.hasMmprojFile();
        if (!hasMmproj && mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(L10n.of(context).chatImageAnalysisUnavailable),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      } catch (_) {}
    });
  }

  /// Runs a recognised device command and writes the turn it produces.
  ///
  /// Navigation runs immediately; anything that changes device state is written
  /// as a proposal and waits for the user to tap.
  Future<void> _handleDeviceAction(
    DeviceActionInvocation invocation,
    String prompt,
  ) async {
    final conversation = _conversations.active ?? _conversations.startNew();
    final assistant = _conversations.beginExchangeInConversation(
      conversation.id,
      prompt,
    );
    final description = DeviceActionDescriptions.describe(context, invocation);

    if (!ChatDeviceActions.runsWithoutAsking(invocation)) {
      _composer.clear();
      _conversations.updateMessageInConversation(
        conversation.id,
        assistant.id,
        description,
        pendingAction: invocation,
        status: ConversationMessageStatus.complete,
        persistSoon: true,
      );
      return;
    }

    _composer.clear();
    _conversations.updateMessageInConversation(
      conversation.id,
      assistant.id,
      description,
      status: ConversationMessageStatus.complete,
    );
    final result = await _deviceActions.run(invocation);
    if (!mounted) return;
    _conversations.updateMessageInConversation(
      conversation.id,
      assistant.id,
      DeviceActionDescriptions.resultLine(context, result),
      clearPendingAction: true,
      status: ConversationMessageStatus.complete,
      persistSoon: true,
    );
  }

  Future<void> _runPendingAction(ConversationMessage message) async {
    final invocation = message.pendingAction;
    final conversation = _conversations.active;
    if (invocation == null || conversation == null) return;
    final result = await _deviceActions.run(invocation);
    if (!mounted) return;
    _conversations.updateMessageInConversation(
      conversation.id,
      message.id,
      DeviceActionDescriptions.resultLine(context, result),
      clearPendingAction: true,
      status: ConversationMessageStatus.complete,
      persistSoon: true,
    );
  }

  void _dismissPendingAction(ConversationMessage message) {
    final conversation = _conversations.active;
    if (conversation == null) return;
    _conversations.updateMessageInConversation(
      conversation.id,
      message.id,
      L10n.of(context).deviceActionsDismissed,
      clearPendingAction: true,
      status: ConversationMessageStatus.complete,
      persistSoon: true,
    );
  }

  Future<void> _send() async {
    final value = _composer.text.trim();
    final attached = _attachedImagePath;
    if ((value.isEmpty && attached == null) || _busy) return;
    if (_inference.isGeneratingReply) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(L10n.of(context).chatFinishingTask),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    // The turn is committed at this point, so the tick belongs here rather
    // than on the tap: a blocked or refused send stays silent.
    HapticFeedback.lightImpact();
    final timing = _generation.createTtftTrace(
      _conversations.active?.id ?? 'new-conversation',
    );
    _prewarmTimer?.cancel();

    setState(() {
      _preparing = true;
    });
    debugPrint('FINN_SEND preparing started');
    try {
      if (!_storesReady) {
        final initialization = Future.wait([
          _conversations.initialize(),
          YouProfileStore.instance.initialize(),
          FlowsStore.instance.initialize(),
        ]).timeout(
          const Duration(seconds: 12),
          onTimeout: () {
            debugPrint(
              'FINN_SEND store init timeout — proceeding with available stores',
            );
            return <void>[];
          },
        );
        await initialization;
        if (!mounted) return;
        _storesReady = true;
      }
      final systemContext = [
        YouProfileStore.instance.promptContext,
        FlowsStore.instance.promptContextFor(value),
      ].where((item) => item.trim().isNotEmpty).join('\n\n');

      // A device command is answered from the catalog, not the model: it is
      // instant, it works before the model is installed, and it cannot be
      // talked into a different action.
      if (attached == null) {
        final deviceAction = await _deviceActions.resolve(value);
        if (deviceAction != null) {
          if (!mounted) return;
          await _handleDeviceAction(deviceAction, value);
          return;
        }
      }

      final missing = <FinnModelSpec>[];
      for (final model in _inference.requiredModels) {
        if (!await _inference.isInstalled(model)) missing.add(model);
      }
      if (missing.isNotEmpty && mounted) {
        final bytes = missing.fold<int>(
          0,
          (total, model) => total + model.expectedBytes,
        );
        final size = bytes >= 1000 * 1000 * 1000
            ? '${(bytes / 1000 / 1000 / 1000).toStringAsFixed(2)} GB'
            : '${(bytes / 1000 / 1000).round()} MB';
        final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: FluxColors.cardOf(context),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FluxRadius.sheet),
            ),
            title: Text(
              L10n.of(context).chatDownloadModelTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w400),
            ),
            content: Text(L10n.of(context).chatDownloadModelBody(size)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(L10n.of(context).commonNotNow),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(L10n.of(context).commonDownload),
              ),
            ],
          ),
        );
        if (accepted != true) {
          return;
        }
      }
      if (!mounted) return;

      final effectivePrompt = value.isNotEmpty
          ? value
          : attached != null && _isImageAttachmentPath(attached)
              ? L10n.of(context).chatImagePromptDefault
              : L10n.of(context).chatFilePromptDefault;
      final conversation = _conversations.active ?? _conversations.startNew();
      final attachedBytes = _attachedImageBytes;
      final history = [
        for (final message in conversation.messages)
          if (message.text.trim().isNotEmpty)
            LocalChatTurn(
              role: message.role.name,
              content: message.text,
              imagePath: message.imagePath,
            ),
      ];
      // Append image bytes to the new turn when available (picker bytes skip temp file)
      final sendHistory =
          attachedBytes != null && _isImageAttachmentPath(attached ?? '')
              ? [
                  ...history,
                  LocalChatTurn(
                    role: 'user',
                    content: effectivePrompt,
                    imagePath: attached,
                    imageBytes: attachedBytes,
                  ),
                ]
              : history;

      _focusNode.unfocus();
      _composer.clear();
      if (mounted) {
        setState(() {
          _attachedImagePath = null;
          _attachedImageBytes = null;
          _dismissedSearchNotice = false;
          _upfrontSearchFailed = false;
        });
      }
      String upfrontGroundedContext = '';
      List<WebSource> upfrontSources = const [];
      if (_webSearch.policy.shouldSearch(effectivePrompt) && attached == null) {
        // Recorded before generation so the reply carries the search it came
        // from: the policy path never reaches the model's tool loop, and
        // without this the turn would look like it answered from nowhere.
        _generation.noteToolActivity(
          ToolActivity(kind: ToolActivityKind.search, label: effectivePrompt),
        );
        try {
          final agent = SearchAgent(searchService: _webSearch);
          final grounded = await agent.searchAndFetch(effectivePrompt).timeout(
                const Duration(milliseconds: 3000),
                onTimeout: () => null,
              );
          if (grounded != null) {
            upfrontGroundedContext = grounded.groundedContext;
            upfrontSources = grounded.search.sources;
          } else {
            // The model-driven path marks this in the engine; the policy path
            // has to mark it here so an unreachable web is reported the same
            // way whichever path asked for it.
            _upfrontSearchFailed = true;
          }
        } catch (e) {
          debugPrint('FINN_UPFRONT_SEARCH error: $e');
        }
      }

      // Pass imagePath for persistence (store), but also ensure the history
      // carries bytes when present so the engine can use imageBytes without file I/O.
      await _generation.start(
        conversationId: conversation.id,
        prompt: effectivePrompt,
        imagePath: attached,
        history: attachedBytes != null ? sendHistory : history,
        systemContext: systemContext,
        groundedContext: upfrontGroundedContext,
        sources: upfrontSources,
        trace: timing,
      );
    } catch (e) {
      debugPrint('FINN_SEND error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(L10n.of(context).chatCouldNotPrepare),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
      debugPrint('FINN_SEND preparing cleared');
    }
  }

  Future<void> _continueReply(ConversationMessage assistant) async {
    if (_busy ||
        assistant.status != ConversationMessageStatus.tokenLimited ||
        assistant.continuationCount >= 1) {
      return;
    }
    final conversation = _conversations.active;
    if (conversation == null) return;
    final assistantIndex = conversation.messages.indexWhere(
      (message) => message.id == assistant.id,
    );
    if (assistantIndex <= 0) return;
    final latestUser = conversation.messages
        .take(assistantIndex)
        .toList(growable: false)
        .reversed
        .where((message) => message.role == ConversationRole.user)
        .firstOrNull;
    if (latestUser == null) return;
    final history = [
      for (final message in conversation.messages)
        if (message.text.trim().isNotEmpty)
          LocalChatTurn(role: message.role.name, content: message.text),
    ];
    final systemContext = [
      YouProfileStore.instance.promptContext,
      FlowsStore.instance.promptContextFor(latestUser.text),
    ].where((item) => item.trim().isNotEmpty).join('\n\n');
    // Continuations reuse the original turn's sources; the decision pass is
    // disabled for the continuation prompt itself.
    GroundedSearchResult? continuationGrounded;
    if (assistant.sources.isNotEmpty &&
        _webSearch.policy.shouldSearch(latestUser.text)) {
      continuationGrounded = await SearchAgent(searchService: _webSearch)
          .searchAndFetch(latestUser.text)
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
    }
    // Keep continuations grounded even when the original model-driven search
    // was not triggered by the deterministic freshness policy. Persisted
    // source excerpts are enough to continue offline; a fresh lookup is only
    // attempted for requests that clearly need current information.
    final continuationSources =
        continuationGrounded?.search.sources ?? assistant.sources;
    final groundedContext = continuationGrounded?.groundedContext ??
        SearchAgent.groundedContextForSources(continuationSources);
    await _generation.continueResponse(
      conversationId: conversation.id,
      assistantMessageId: assistant.id,
      originalPrompt: latestUser.text,
      history: history,
      systemContext: systemContext,
      groundedContext: groundedContext,
      sources: continuationSources,
    );
  }

  /// Re-runs the model on the same user turn, replacing the last assistant
  /// reply in place. The search decision runs again so a weak answer can be
  /// re-grounded.
  Future<void> _regenerateReply(ConversationMessage assistant) async {
    if (_busy || _inference.isGeneratingReply) return;
    final conversation = _conversations.active;
    if (conversation == null) return;
    final assistantIndex = conversation.messages.indexWhere(
      (message) => message.id == assistant.id,
    );
    if (assistantIndex <= 0) return;
    final latestUser = conversation.messages
        .take(assistantIndex)
        .toList(growable: false)
        .reversed
        .where((message) => message.role == ConversationRole.user)
        .firstOrNull;
    if (latestUser == null) return;
    final history = [
      for (final message in conversation.messages.take(assistantIndex))
        if (message.text.trim().isNotEmpty)
          LocalChatTurn(role: message.role.name, content: message.text),
    ];
    final systemContext = [
      YouProfileStore.instance.promptContext,
      FlowsStore.instance.promptContextFor(latestUser.text),
    ].where((item) => item.trim().isNotEmpty).join('\n\n');
    if (mounted) setState(() => _dismissedSearchNotice = false);
    await _generation.regenerate(
      conversationId: conversation.id,
      assistantMessageId: assistant.id,
      originalPrompt: latestUser.text,
      history: history,
      systemContext: systemContext,
    );
  }

  /// Replaces a user message and drops everything after it, then answers the
  /// edited turn in the same conversation.
  Future<void> _editUserMessage(ConversationMessage message) async {
    if (_busy || _inference.isGeneratingReply) return;
    final conversation = _conversations.active;
    if (conversation == null) return;
    final edited = await showDialog<String>(
      context: context,
      builder: (_) => _EditMessageDialog(initialText: message.text),
    );
    if (edited == null) return;
    final trimmed = edited.trim();
    if (trimmed.isEmpty || trimmed == message.text) return;
    final ok = _conversations.editUserMessage(
      conversationId: conversation.id,
      messageId: message.id,
      newText: trimmed,
    );
    if (!ok || !mounted) return;
    final updated = _conversations.conversationById(conversation.id);
    if (updated == null) return;
    final history = [
      for (final message in updated.messages)
        if (message.text.trim().isNotEmpty)
          LocalChatTurn(role: message.role.name, content: message.text),
    ];
    final systemContext = [
      YouProfileStore.instance.promptContext,
      FlowsStore.instance.promptContextFor(trimmed),
    ].where((item) => item.trim().isNotEmpty).join('\n\n');
    if (mounted) setState(() => _dismissedSearchNotice = false);
    await _generation.replyToExisting(
      conversationId: conversation.id,
      prompt: trimmed,
      history: history,
      systemContext: systemContext,
    );
  }

  Future<void> _openVoiceMode() async {
    if (!voiceSupportedOnPlatform || _busy) return;
    _voice.setSpokenResponses(VoiceSettingsStore.instance.spokenResponses);
    _voice.onTranscript = _onInlineTranscript;
    setState(() {
      _voiceListening = true;
      _voiceDraft = '';
    });
    await _voice.startListening();
    if (!mounted) return;
    if (_voice.error != VoiceChatError.none) {
      _voice.onTranscript = null;
      setState(() => _voiceListening = false);
      _showVoiceFailure();
    }
  }

  /// Mirrors what the microphone hears into the composer while listening, so
  /// the draft is visible and editable before it is sent.
  void _onInlineTranscript(String text) {
    if (!mounted || !_voiceListening) return;
    setState(() => _voiceDraft = text);
    _composer.text = text;
    _composer.selection = TextSelection.collapsed(offset: text.length);
  }

  /// Ends inline listening and sends what was heard.
  Future<void> _endVoiceListening() async {
    if (!_voiceListening) return;
    setState(() => _voiceListening = false);
    _voice.onTranscript = null;
    await _voice.stopListening();
    if (!mounted) return;
    final heard = _voiceDraft.trim();
    _voiceDraft = '';
    if (heard.isEmpty) return;
    await _sendVoiceTranscript(heard);
  }

  /// Hands the microphone over to the full-screen voice mode, which keeps the
  /// orb and the spoken replies.
  Future<void> _expandVoiceMode() async {
    if (!_voiceListening) return;
    setState(() => _voiceListening = false);
    _voice.onTranscript = null;
    await _voice.stopListening();
    if (!mounted) return;
    _voiceDraft = '';
    await openVoiceSheet(
      context: context,
      voice: _voice,
      onSendTranscript: _sendVoiceTranscript,
      onStopGeneration: _stopReply,
    );
  }

  void _showVoiceFailure() {
    final message = _voice.error == VoiceChatError.micDenied
        ? L10n.of(context).voiceMicDenied
        : L10n.of(context).voiceUnavailable;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendVoiceTranscript(String transcript) async {
    final text = transcript.trim();
    if (text.isEmpty || _busy || !mounted) return;
    _voice.beginThinking();
    _composer.text = text;
    _composer.selection = TextSelection.collapsed(offset: text.length);
    await _send();
    final job = _generation.job;
    if (job != null && job.busy) {
      _voiceReplyGenerationId = job.generationId;
      _voice.speakReplyChunk(job.responseText);
    } else {
      _voiceReplyGenerationId = null;
      _voice.finishReply('');
    }
  }

  void _pumpVoiceReply() {
    final replyId = _voiceReplyGenerationId;
    if (replyId == null) return;
    final job = _generation.job;
    if (job == null || job.generationId != replyId) {
      _voiceReplyGenerationId = null;
      return;
    }
    if (job.busy) {
      _voice.speakReplyChunk(job.responseText);
    } else {
      _voiceReplyGenerationId = null;
      _voice.finishReply(job.responseText);
    }
  }

  void _stopReply() {
    HapticFeedback.mediumImpact();
    if (_preparing) {
      setState(() => _preparing = false);
      debugPrint('FINN_SEND cancelled during preparing');
    }
    unawaited(_voice.interrupt());
    unawaited(_generation.stop());
  }

  void _activateConversation(String id) {
    unawaited(_generation.flushActive());
    _conversations.activate(id);
    _setSidebar(false);
    setState(() {});
  }

  void _newConversation() {
    unawaited(_generation.flushActive());
    // Compose just shows the blank slate — no conversation is created until
    // the user actually sends a first message.
    _conversations.clearActive();
    _setSidebar(false);
    setState(() {});
  }

  Future<void> _openCreations() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(FinnPageRoute<void>(child: const CreationsPage()));
  }

  Future<void> _openYou() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    Navigator.of(context).push(
      FinnPageRoute<void>(
        child: YouPage(onBack: () => Navigator.of(context).pop()),
      ),
    );
  }

  Future<void> _openSkills() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    Navigator.of(context).push(
      FinnPageRoute<void>(
        child: FlowsPage(onBack: () => Navigator.of(context).pop()),
      ),
    );
  }

  Future<void> _openSettings() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    Navigator.of(context).push(
      FinnPageRoute<void>(
        child: SettingsPage(
          onBack: () => Navigator.of(context).pop(),
          onOpenActions: _openDeviceActions,
        ),
      ),
    );
  }

  Future<void> _openDeviceActions() async {
    if (!mounted) return;
    Navigator.of(context).push(
      FinnPageRoute<void>(
        child: DeviceActionsPage(onBack: () => Navigator.of(context).pop()),
      ),
    );
  }

  Future<void> _openDeviceActionsFromSidebar() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    await _openDeviceActions();
  }

  void _setSidebar(bool open) {
    if (_sidebar == open) return;
    HapticFeedback.selectionClick();
    setState(() {
      _sidebar = open;
      if (open) _sidebarEverOpened = true;
    });
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      _sidebarController.value = open ? 1 : 0;
    } else if (open) {
      _sidebarController.forward();
    } else {
      _sidebarController.reverse();
    }
  }

  Future<void> _closeSidebarForNavigation() async {
    if (!_sidebar) return;
    setState(() {
      _sidebar = false;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _sidebarController.value = 0;
    } else {
      await _sidebarController.reverse();
    }
  }

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
            final sy = (constraints.maxHeight / 912).clamp(.72, 1.2);
            final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
            final horizontalGutter = constraints.maxWidth < 380 ? 20.0 : 25.0;
            final contentWidth = math.min(
              760.0,
              constraints.maxWidth - horizontalGutter * 2,
            );
            final contentLeft = (constraints.maxWidth - contentWidth) / 2;
            final activeConversation = _conversations.active;
            final activeMessages =
                activeConversation?.messages ?? const <ConversationMessage>[];
            final homeLayer = RepaintBoundary(
              child: ColoredBox(
                color: FluxColors.tileOf(context),
                child: Stack(
                  children: [
                    // The ambient green wash is part of the empty state only:
                    // once a conversation has messages the canvas is flat, as
                    // in the design's chat screens.
                    if (activeMessages.isEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: constraints.maxHeight * 400 / 912,
                        child: const IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x00FFFFFF), Color(0x4092FF86)],
                              ),
                            ),
                          ),
                        ),
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
                        preparing: _preparing,
                        greeting: _voiceListening
                            ? L10n.of(context).voiceGreeting
                            : L10n.of(context).chatGreeting,
                        // First message starts below the header; newest
                        // message sits above the composer.
                        topInset: 125 * sy,
                        bottomInset: safeBottom + 65,
                        scrollController: _chatScrollController,
                        // The notice belongs to the turn that failed to reach
                        // the web, so it renders with that reply instead of
                        // floating over the whole conversation.
                        searchFailed: (_inference.lastSearchFailed ||
                                _upfrontSearchFailed) &&
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
                    // 4. Header and composer are the topmost layers: crisp over
                    // the glass and always tappable. Browser steps are not
                    // floated here — they belong to the reply that made them.
                    Positioned(
                      left: contentLeft,
                      width: contentWidth,
                      top: 70 * sy,
                      child: _HomeHeader(
                        onMenu: () => _setSidebar(true),
                        // The design titles a conversation once it has
                        // messages, and hides the title again while listening.
                        title: activeMessages.isEmpty || _voiceListening
                            ? null
                            : activeConversation?.title,
                        onNewChat:
                            activeMessages.isEmpty ? null : _newConversation,
                      ),
                    ),
                    if (_attachmentMenuOpen) ...[
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _closeAttachmentMenu,
                          child: const SizedBox.expand(),
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _chatScrolledAway,
                        builder: (context, scrolledAway, _) =>
                            AnimatedPositioned(
                          left: contentLeft,
                          bottom: safeBottom + 63,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: _FadeRise(
                            rise: 8,
                            child: _IMessageAttachmentMenu(
                              onSelectCamera: _pickFromCamera,
                              onSelectPhoto: _pickFromGallery,
                              onSelectFile: _pickFromFileSystem,
                            ),
                          ),
                        ),
                      ),
                    ],

                    ValueListenableBuilder<bool>(
                      valueListenable: _chatScrolledAway,
                      builder: (context, scrolledAway, _) => AnimatedPositioned(
                        left: contentLeft,
                        // The design rests the composer just above the home
                        // indicator; the safe-area inset already covers the
                        // gesture bar, so only the design's own 3px of
                        // breathing room is left over.
                        bottom: safeBottom + 3,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
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
                          onVoiceExpand: _expandVoiceMode,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
            // The panel covers three quarters of the screen; the home screen
            // stays visible beside it, rounded and lifted, as in the design.
            final sidebarWidth = constraints.maxWidth * .76;
            final sidebarLayer = !_sidebarEverOpened
                ? const SizedBox.shrink()
                : RepaintBoundary(
                    child: SizedBox(
                      width: sidebarWidth,
                      child: _Sidebar(
                        onClose: () => _setSidebar(false),
                        onNewConversation: _newConversation,
                        onConversation: _activateConversation,
                        conversations: _conversations.conversations,
                        activeConversationId: _conversations.active?.id,
                        onCreations: _openCreations,
                        onYou: _openYou,
                        onFlows: _openSkills,
                        onActions: _openDeviceActionsFromSidebar,
                        onSettings: _openSettings,
                      ),
                    ),
                  );
            return AnimatedBuilder(
              animation: _sidebarAnimation,
              builder: (context, _) {
                final motion = _sidebarAnimation.value;
                final radius = BorderRadius.circular(50 * motion);
                return Stack(
                  children: [
                    ExcludeSemantics(
                      excluding: _sidebar,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          boxShadow: [
                            if (motion > 0)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .10),
                                blurRadius: 55,
                                offset: const Offset(-10, 0),
                              ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: radius,
                          child: Transform.translate(
                            offset: Offset(sidebarWidth * motion, 0),
                            child: homeLayer,
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      ignoring: !_sidebar,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _setSidebar(false),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    IgnorePointer(
                      ignoring: !_sidebar,
                      child: ExcludeSemantics(
                        excluding: !_sidebar,
                        child: FractionalTranslation(
                          translation: Offset(-1 + motion, 0),
                          child: sidebarLayer,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// The screen's top row: the menu (and close) control on the left, the
/// conversation title beside it, and the new-chat control on the right while a
/// conversation is on screen — exactly the arrangement in the design.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.onMenu,
    this.title,
    this.onNewChat,
  });

  final VoidCallback onMenu;

  /// Conversation title; null on the empty screen and while listening.
  final String? title;

  /// Starts a new conversation; null hides the control.
  final VoidCallback? onNewChat;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          Tooltip(
            message: L10n.of(context).chatOpenMenuTooltip,
            child: Semantics(
              button: true,
              label: L10n.of(context).chatOpenMenuTooltip,
              onTap: onMenu,
              excludeSemantics: true,
              child: FluxPressScale(
                child: Material(
                  color: FluxColors.controlOf(context),
                  shape: const CircleBorder(),
                  child: SizedBox.square(
                    key: const ValueKey('home-menu-button'),
                    dimension: 50,
                    child: InkWell(
                      onTap: onMenu,
                      customBorder: const CircleBorder(),
                      child: const Center(
                        child: FigmaSvg(
                          asset: FigmaAssets.appMenu,
                          width: 25,
                          height: 25,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (title != null && title.isNotEmpty) ...[
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
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
          ] else
            const Spacer(),
          if (onNewChat != null)
            Semantics(
              button: true,
              label: L10n.of(context).chatNewChat,
              onTap: onNewChat,
              excludeSemantics: true,
              child: FluxPressScale(
                child: Material(
                  color: FluxColors.controlOf(context),
                  shape: const CircleBorder(),
                  child: SizedBox.square(
                    key: const ValueKey('home-new-chat-button'),
                    dimension: 50,
                    child: InkWell(
                      onTap: onNewChat,
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

/// Height of the chat's top scroll-fade band, in logical pixels.
///
/// Declared once because the gradient's opaque stretch is a fraction of it:
/// the band and the gradient stops have to stay in step.
const double _chatTopFadeHeight = 210;

/// Depth of the fully opaque stretch at the top of the fade band.
///
/// The brand row must stay readable while messages scroll beneath it, so the
/// fade is opaque wherever the header can sit. `_HomeHeader` is 50 tall at
/// `top: 71 * sy`, and `sy` is clamped to 1.08, so its bottom edge reaches
/// (71 + 50) * 1.08 ≈ 130.7.
const double _chatTopFadeOpaqueDepth = 134;

/// A static soft-edge fade that sits over the scrolling chat list so messages
/// appear to slide beneath the header at the top and fade into the very bottom
/// edge of the screen below the composer. It replaces the old progressive
/// backdrop blur with a plain gradient — effectively free per scroll frame.
/// The header and composer are drawn above these fades in the shell Stack, so
/// they stay crisp and tappable.
///
/// The top band is *fully* opaque across the brand row and only then ramps to
/// transparent. At anything less than opaque, scrolled message text stays
/// legible straight through the app title, which reads as a rendering fault
/// rather than as depth. The bottom band has no content drawn over it, so it
/// keeps the softer profile that lets the last row dissolve into the composer.
class _ChatEdgeFade extends StatelessWidget {
  const _ChatEdgeFade({super.key, required this.top});

  /// True for the fade under the header at the top of the screen, false for
  /// the fade hugging the very bottom edge of the screen.
  final bool top;

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    final color = isDark ? FluxColors.darkCanvas : FluxColors.canvas;
    final stops = top
        ? const <double>[
            0.0,
            _chatTopFadeOpaqueDepth / _chatTopFadeHeight,
            0.80,
            1.0,
          ]
        : const <double>[0.0, 0.35, 0.7, 1.0];
    final colors = top
        ? <Color>[
            // Opaque across the brand row; the ramp starts below it.
            color,
            color,
            color.withValues(alpha: 0.42),
            color.withValues(alpha: 0.0),
          ]
        : <Color>[
            color.withValues(alpha: 0.93),
            color.withValues(alpha: 0.64),
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.0),
          ];
    return DecoratedBox(
      decoration: BoxDecoration(
        // Progressive: mostly transparent across the band and easing smoothly
        // to near-opaque only at the screen edge, so there is no hard line.
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          stops: stops,
          colors: colors,
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Cold-start welcome shown when the active conversation has no messages yet:
/// the greeting alone, centred on the screen — no chips, no brand mark.
class _ConversationEmpty extends StatelessWidget {
  const _ConversationEmpty({required this.greeting});

  /// The design greets a listening session differently from a typed one.
  final String greeting;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Text(
            greeting,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'InstrumentSans',
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
}

class _Conversation extends StatefulWidget {
  const _Conversation({
    required this.messages,
    required this.activeConversationId,
    required this.generation,
    required this.conversations,
    required this.onStop,
    required this.onContinue,
    required this.onRegenerate,
    required this.onRunAction,
    required this.onDismissAction,
    required this.onActions,
    required this.onEdit,
    required this.onOpenConversation,
    required this.preparing,
    required this.topInset,
    required this.bottomInset,
    required this.scrollController,
    required this.greeting,
    this.searchFailed = false,
    this.onDismissSearchNotice,
    this.historyUnavailable = false,
    this.onDismissHistoryNotice,
  });
  final List<ConversationMessage> messages;
  final String? activeConversationId;
  final ChatGenerationController generation;
  final ConversationStore conversations;
  final VoidCallback onStop;
  final ValueChanged<ConversationMessage> onContinue;
  final ValueChanged<ConversationMessage> onRegenerate;
  final ValueChanged<ConversationMessage> onRunAction;
  final ValueChanged<ConversationMessage> onDismissAction;
  final VoidCallback onActions;
  final ValueChanged<ConversationMessage> onEdit;
  final ValueChanged<String> onOpenConversation;
  final bool preparing;

  /// Greeting shown on the empty slate; the design greets a listening session
  /// with a different line than a typed one.
  final String greeting;

  /// True when the conversation store could not be opened, so the notice
  /// explaining that history is not being kept should be shown.
  final bool historyUnavailable;
  final VoidCallback? onDismissHistoryNotice;

  /// Vertical insets so the first message clears the header and the newest
  /// message clears the composer, while the list still bleeds beneath both
  /// for the soft edge fade.
  final double topInset;
  final double bottomInset;

  /// Scroll controller owned by the shell so it can observe the scroll
  /// position (to collapse the composer) and jump back to the latest message.
  final ScrollController scrollController;

  /// True when the last turn wanted the web and could not reach it. Rendered
  /// with the reply that failed rather than as a banner over the app.
  final bool searchFailed;

  /// Dismisses [searchFailed] for the rest of this turn.
  final VoidCallback? onDismissSearchNotice;

  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation> {
  Timer? _scrollSettleTimer;

  /// (conversationId, messageCount, jobId, responseLength, state, preparing)
  /// — the layout-relevant generation inputs. A change that only moves the
  /// response length is a token event: the streaming bubble repaints itself
  /// and the list only re-anchors the scroll, without a full rebuild.
  late (String, int, String?, int, String?, bool) _contentSignature;

  @override
  void initState() {
    super.initState();
    _contentSignature = _signature();
    widget.generation.addListener(_generationChanged);
  }

  @override
  void didUpdateWidget(covariant _Conversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSignature(rebuild: false);
  }

  (String, int, String?, int, String?, bool) _signature() {
    final active = widget.generation.activeJob;
    return (
      widget.activeConversationId ?? '',
      widget.messages.length,
      active?.conversationId,
      active?.responseText.length ?? 0,
      active?.state.name,
      widget.preparing,
    );
  }

  void _generationChanged() {
    if (!mounted) return;
    _syncSignature(rebuild: true);
  }

  void _syncSignature({required bool rebuild}) {
    final nextSignature = _signature();
    if (nextSignature == _contentSignature) return;
    final previous = _contentSignature;
    _contentSignature = nextSignature;
    final textOnlyGrew = previous.$1 == nextSignature.$1 &&
        previous.$2 == nextSignature.$2 &&
        previous.$3 == nextSignature.$3 &&
        previous.$5 == nextSignature.$5 &&
        previous.$6 == nextSignature.$6;
    if (rebuild && !textOnlyGrew) {
      setState(() {});
    }
    _queueLatestAlignment();
  }

  void _queueLatestAlignment() {
    _scrollSettleTimer?.cancel();
    _scrollSettleTimer = Timer(const Duration(milliseconds: 70), () {
      if (!mounted || !widget.scrollController.hasClients) return;
      final position = widget.scrollController.position;
      // Reverse lists place the latest response at offset zero. Follow new
      // output only while the user is already near it; never pull someone
      // away from an older message they are reading.
      if (position.pixels > 140 || position.pixels <= .5) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        widget.scrollController.jumpTo(0);
      } else {
        unawaited(
          widget.scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutQuart,
          ),
        );
      }
    });
  }

  /// Counter-balances the reverse list's bottom anchor while a sources list
  /// grows: expanding the message pushes the content above it up by [delta],
  /// so the scroll position is nudged by the same amount to keep the answer
  /// anchored while the actions below the sources slide down.
  void _compensateSourcesGrowth(double delta) {
    if (!widget.scrollController.hasClients || delta == 0) return;
    final position = widget.scrollController.position;
    final target = (position.pixels + delta).clamp(
      0.0,
      position.maxScrollExtent,
    );
    if (target != position.pixels) {
      widget.scrollController.jumpTo(target);
    }
  }

  @override
  void dispose() {
    widget.generation.removeListener(_generationChanged);
    _scrollSettleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeJob = widget.generation.activeJob;
    final ownsGeneration = activeJob != null &&
        activeJob.conversationId == widget.activeConversationId;
    final terminalJob = widget.generation.job;
    final visibleError =
        terminalJob?.conversationId == widget.activeConversationId &&
                terminalJob?.state == ChatGenerationState.error
            ? terminalJob?.errorMessage
            : null;
    // A turn that failed before emitting any token is persisted with empty
    // text, so it never reaches the message list and its Regenerate action is
    // unreachable. Surface a retry on the error bubble itself.
    final failedTurn = visibleError == null
        ? null
        : widget.messages
            .where((message) => message.id == terminalJob?.assistantMessageId)
            .firstOrNull;
    if (widget.messages.isEmpty &&
        activeJob == null &&
        visibleError == null &&
        !widget.preparing) {
      return _FadeRise(child: _ConversationEmpty(greeting: widget.greeting));
    }
    final streamingMessageId =
        ownsGeneration ? activeJob.assistantMessageId : null;
    final visibleMessages = widget.messages
        .where(
          (message) =>
              message.text.isNotEmpty && message.id != streamingMessageId,
        )
        .toList(growable: false);
    return Stack(
      key: const ValueKey('chat-edge-fade'),
      children: [
        ListView.builder(
          key: const ValueKey('chat-scroll-view'),
          controller: widget.scrollController,
          reverse: true,
          // Content bleeds into the soft edge fades so messages fade out as
          // they reach the top edge and fade into the bottom screen edge
          // beneath the composer. The top inset parks the oldest message below
          // the header instead of against the status bar; the bottom inset
          // keeps the newest message close above the composer.
          padding: EdgeInsets.fromLTRB(
            0,
            widget.topInset,
            0,
            widget.bottomInset + 20,
          ),
          // ignore: deprecated_member_use (OHOS fork 3.27 lacks scrollCacheExtent)
          cacheExtent: 700.0,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const FluxBouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: visibleMessages.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.searchFailed) ...[
                    _OfflineSearchNotice(
                      onDismiss: widget.onDismissSearchNotice,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (widget.historyUnavailable) ...[
                    _HistoryUnavailableNotice(
                      onDismiss: widget.onDismissHistoryNotice,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (ownsGeneration)
                    _StreamingReply(
                      generation: widget.generation,
                      text: activeJob.responseText,
                    )
                  else if (widget.preparing)
                    _StreamingReply(generation: widget.generation, text: '')
                  else if (activeJob != null)
                    OtherChatGenerationNotice(
                      title: widget.conversations
                              .conversationById(activeJob.conversationId)
                              ?.title ??
                          L10n.of(context).chatAnotherChatFallback,
                      onOpen: () =>
                          widget.onOpenConversation(activeJob.conversationId),
                      onStop: widget.onStop,
                    )
                  else if (visibleError != null)
                    _ErrorReply(
                      key: const ValueKey('error'),
                      text: visibleError,
                      onRetry: failedTurn == null
                          ? null
                          : () => widget.onRegenerate(failedTurn),
                    ),
                  if (visibleMessages.isNotEmpty) const SizedBox(height: 14),
                ],
              );
            }
            final message = visibleMessages[visibleMessages.length - index];
            return Padding(
              key: ValueKey('chat-message-${message.id}'),
              padding: const EdgeInsets.only(bottom: 14),
              child: _AnimatedIn(
                child: message.role == ConversationRole.user
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: _Bubble(
                          text: message.text,
                          imagePath: message.imagePath,
                          user: true,
                          modelTier: 'User message',
                          onEdit: () => widget.onEdit(message),
                        ),
                      )
                    : _CompleteReply(
                        text: message.text,
                        userPrompt: (visibleMessages.length - index - 1 >= 0 &&
                                visibleMessages[
                                            visibleMessages.length - index - 1]
                                        .role ==
                                    ConversationRole.user)
                            ? visibleMessages[
                                    visibleMessages.length - index - 1]
                                .text
                            : null,
                        modelTier: message.modelTier,
                        status: message.status,
                        sources: message.sources,
                        toolActivities: message.toolActivities,
                        pendingAction: message.pendingAction,
                        onRunAction: message.pendingAction == null
                            ? null
                            : () => widget.onRunAction(message),
                        onDismissAction: message.pendingAction == null
                            ? null
                            : () => widget.onDismissAction(message),
                        onSourcesHeightDelta: _compensateSourcesGrowth,
                        showActions: true,
                        onContinue: message.status ==
                                    ConversationMessageStatus.tokenLimited &&
                                message.continuationCount < 1
                            ? () => widget.onContinue(message)
                            : null,
                        onRegenerate:
                            message.id == widget.messages.lastOrNull?.id
                                ? () => widget.onRegenerate(message)
                                : null,
                      ),
              ),
            );
          },
        ),
        // Fixed overlay bands (Positioned, not Align) so they are anchored to
        // the real top and bottom edges of the viewport. The top band is tall
        // enough to hide the header completely and still ramp out below it; the
        // bottom band fades content into the very bottom edge of the screen and
        // completes exactly at the composer's top edge, so messages stay crisp
        // right up to the input.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _chatTopFadeHeight,
          child: IgnorePointer(
            child: const _ChatEdgeFade(
              key: ValueKey('chat-fade-top'),
              top: true,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: widget.bottomInset,
          child: IgnorePointer(
            child: const _ChatEdgeFade(
              key: ValueKey('chat-fade-bottom'),
              top: false,
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    this.imagePath,
    this.user = false,
    this.modelTier = 'FinnAI',
    this.onEdit,
  });

  final String text;
  final String? imagePath;
  final bool user;
  final String modelTier;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return _MessageBubble(
      text: text,
      user: user,
      modelTier: modelTier,
      onEdit: onEdit,
      childBuilder: (selecting) {
        // 16px on a 1.25 line box, the size and rhythm of the design's
        // messages in both bubbles.
        final style = TextStyle(
          fontFamily: 'InstrumentSans',
          fontSize: 16,
          height: 1.25,
          fontWeight: FontWeight.w400,
          color: user ? FluxColors.inkOf(context) : null,
        );
        final hasImage = imagePath != null && imagePath!.isNotEmpty;
        bool imageExists = false;
        try {
          imageExists = hasImage && File(imagePath!).existsSync();
        } catch (_) {
          imageExists = false;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasImage) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(FluxRadius.sm),
                  child: imageExists
                      ? Image.file(
                          File(imagePath!),
                          width: 200,
                          height: 140,
                          cacheWidth: 400,
                          filterQuality: FilterQuality.low,
                          gaplessPlayback: true,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: 160,
                            padding: const EdgeInsets.all(8),
                            color: FluxColors.cardOf(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const FluxIcon(
                                  icon: FluxIcons.image,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    imagePath!
                                        .split(Platform.pathSeparator)
                                        .last,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          width: 160,
                          padding: const EdgeInsets.all(8),
                          color: FluxColors.cardOf(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const FluxIcon(icon: FluxIcons.image, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  imagePath!.split(Platform.pathSeparator).last,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
            if (text.isNotEmpty)
              selecting
                  ? SelectableText(text, style: style)
                  : Text(text, style: style),
          ],
        );
      },
    );
  }
}

/// A gentle entrance for a single element: fades in while rising a few pixels.
///
/// Where [_AnimatedIn] travels a fraction of the viewport — right for a message
/// row — this moves a fixed handful of pixels, so the empty-state greeting and
/// the reply action row settle in place rather than sliding.
class _FadeRise extends StatefulWidget {
  const _FadeRise({required this.child, this.rise = 10});

  final Widget child;
  final double rise;

  @override
  State<_FadeRise> createState() => _FadeRiseState();
}

class _FadeRiseState extends State<_FadeRise>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.rise * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Entrance animation for a freshly mounted chat message: a gentle rise
/// with a fade, so new messages arrive instead of snapping into place.
class _AnimatedIn extends StatefulWidget {
  const _AnimatedIn({required this.child});

  final Widget child;

  @override
  State<_AnimatedIn> createState() => _AnimatedInState();
}

class _AnimatedInState extends State<_AnimatedIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .06),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.text,
    required this.user,
    required this.modelTier,
    required this.childBuilder,
    this.onEdit,
  });

  final String text;
  final bool user;
  final String modelTier;
  final Widget Function(bool selecting) childBuilder;
  final VoidCallback? onEdit;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  final GlobalKey _bubbleKey = GlobalKey();
  bool _selecting = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(L10n.of(context).commonCopiedToClipboard),
          duration: Duration(milliseconds: 900),
        ),
      );
  }

  void _openContextMenu() {
    if (_selecting) return;
    final borderRadius = widget.user
        ? BorderRadius.circular(FluxRadius.pill)
        : BorderRadius.only(
            topLeft: const Radius.circular(19),
            topRight: const Radius.circular(19),
            bottomLeft: const Radius.circular(19),
            bottomRight: const Radius.circular(5),
          );

    final preview = Container(
      constraints: BoxConstraints(
        maxWidth: math.min(MediaQuery.sizeOf(context).width * .82, 620),
      ),
      padding: widget.user
          ? const EdgeInsets.symmetric(horizontal: 20, vertical: 15)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.user
            ? FluxColors.controlOf(context)
            : FluxColors.cardOf(context),
        borderRadius: borderRadius,
        border: widget.user
            ? null
            : Border.all(
                color: FluxColors.lineOf(context).withValues(alpha: 0.06),
              ),
      ),
      child: widget.childBuilder(false),
    );

    final items = <FluxContextMenuItem>[
      if (widget.onEdit != null)
        FluxContextMenuItem(
          icon: FluxIcons.edit,
          label: L10n.of(context).commonEdit,
          onTap: () => widget.onEdit?.call(),
        ),
      FluxContextMenuItem(
        icon: FluxIcons.copy,
        label: L10n.of(context).chatCopy,
        onTap: _copy,
      ),
      FluxContextMenuItem(
        icon: FluxIcons.canvas,
        label: L10n.of(context).chatSelectText,
        onTap: () => setState(() => _selecting = true),
      ),
      if (!widget.user)
        FluxContextMenuItem(
          icon: FluxIcons.flag,
          label: L10n.of(context).chatReportAction,
          onTap: () {
            ReportDialog.show(
              context,
              assistantResponse: widget.text,
              userPrompt: null,
              modelTier: widget.modelTier,
            );
          },
        ),
    ];

    showFluxContextMenu<void>(
      context: context,
      targetKey: _bubbleKey,
      previewWidget: preview,
      items: items,
      targetBorderRadius: borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    // A user message is a solid pill of its own; the assistant keeps the
    // softly-cornered surface so an error or notice still reads as a card.
    final borderRadius = widget.user
        ? BorderRadius.circular(FluxRadius.pill)
        : BorderRadius.only(
            topLeft: const Radius.circular(19),
            topRight: const Radius.circular(19),
            bottomLeft: const Radius.circular(19),
            bottomRight: const Radius.circular(5),
          );

    final bubble = Container(
      key: _bubbleKey,
      constraints: BoxConstraints(
        maxWidth: math.min(MediaQuery.sizeOf(context).width * .82, 620),
      ),
      padding: widget.user
          ? const EdgeInsets.symmetric(horizontal: 20, vertical: 15)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.user
            ? FluxColors.controlOf(context)
            : FluxColors.cardOf(context),
        borderRadius: borderRadius,
        boxShadow: widget.user
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? .28 : .04),
                  blurRadius: isDark ? 12 : 9,
                  offset: const Offset(0, 3),
                ),
              ],
        border: null,
      ),
      child: widget.childBuilder(_selecting),
    );

    return Semantics(
      button: !_selecting,
      hint: _selecting ? null : L10n.of(context).chatMessageActionsHint,
      child: FluxSpringPressable(
        enabled: !_selecting,
        onLongPress: _openContextMenu,
        child: bubble,
      ),
    );
  }
}

/// The live AI response while it is being generated: the streaming text (if
/// any) followed by a softly blinking caret. Replaces the old "Finn is
/// typing…" bar and its stop affordance with an animated caret and smooth streaming.
///
/// The shell only rebuilds this subtree on discrete generation transitions;
/// the widget listens to the generation controller itself so per-token growth
/// repaints the bubble without re-laying-out the whole chat shell.
class _StreamingReply extends StatefulWidget {
  const _StreamingReply({required this.generation, required this.text});

  /// Controller to follow for token growth while this reply streams.
  final ChatGenerationController generation;

  /// Fallback text used when no generation job is active (the preparing
  /// placeholder); superseded by the job's response text whenever one runs.
  final String text;

  @override
  State<_StreamingReply> createState() => _StreamingReplyState();
}

class _StreamingReplyState extends State<_StreamingReply>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  late String _text = widget.generation.activeJob?.responseText ?? widget.text;
  late int _activityCount = widget.generation.toolActivities.length;

  @override
  void initState() {
    super.initState();
    // The pulse is only drawn by the empty-text "Finn is generating" row; once
    // tokens arrive it would tick vsync forever for nothing.
    if (_text.isEmpty && _activityCount == 0) _pulse.repeat(reverse: true);
    widget.generation.addListener(_onGenerationChanged);
  }

  void _setPulse(bool visible) {
    if (visible) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void didUpdateWidget(covariant _StreamingReply oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncText();
  }

  void _onGenerationChanged() {
    if (!mounted) return;
    _syncText();
  }

  void _syncText() {
    final next = widget.generation.activeJob?.responseText ?? widget.text;
    final nextActivities = widget.generation.toolActivities.length;
    if (next == _text && nextActivities == _activityCount) return;
    setState(() {
      _text = next;
      _activityCount = nextActivities;
    });
    _setPulse(next.isEmpty && nextActivities == 0);
  }

  @override
  void dispose() {
    widget.generation.removeListener(_onGenerationChanged);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fullText = _text;
    final activities = widget.generation.toolActivities;
    // Answer tokens only start once the browsing is over, so the moment text
    // arrives the steps stop being "in progress" and become the settled record
    // — the same line the finished reply keeps.
    final stillBrowsing = fullText.isEmpty;
    final searchIndicator = ToolActivityIndicator(
      activities: activities,
      busy: stillBrowsing,
    );

    if (fullText.isEmpty) {
      // While a search runs, the search itself is the placeholder: it says
      // more than "Finn is generating", and it is the same line that stays
      // under the answer once the turn finishes.
      if (activities.isNotEmpty) return searchIndicator;
      return Semantics(
        liveRegion: true,
        label: L10n.of(context).chatFinnGenerating,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: FluxColors.inkOf(
                      context,
                    ).withValues(alpha: .3 + .5 * _pulse.value),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                L10n.of(context).chatFinnGenerating,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: FluxColors.mutedOf(context),
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final activeSources = widget.generation.activeJob?.sources ?? const [];
    final imageUrls = activeSources
        .map((s) => s.imageUrl)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageUrls.isNotEmpty) ...[
          _ArticlePhotoSlideshow(imageUrls: imageUrls),
          const SizedBox(height: 12),
        ],
        Semantics(liveRegion: true, child: SafeMarkdownText(text: fullText)),
        // Below the answer, in the same slot the finished reply uses, so the
        // pill never jumps position when the turn completes — and it stays on
        // screen while a long answer streams past it.
        if (activities.isNotEmpty) ...[
          const SizedBox(height: 6),
          searchIndicator,
        ],
        if (activeSources.isNotEmpty) ...[
          const SizedBox(height: 6),
          _SourceList(sources: activeSources, onHeightDelta: (_) {}),
        ],
      ],
    );
  }
}

@visibleForTesting
class OtherChatGenerationNotice extends StatelessWidget {
  const OtherChatGenerationNotice({
    super.key,
    required this.title,
    required this.onOpen,
    required this.onStop,
  });

  final String title;
  final VoidCallback onOpen;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: L10n.of(context).chatGeneratingInOtherChat,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          decoration: BoxDecoration(
            color: FluxColors.cardOf(context).withValues(alpha: .78),
            borderRadius: BorderRadius.circular(FluxRadius.md),
            border: Border.all(color: FluxColors.lineOf(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  L10n.of(context).chatGeneratingIn(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              TextButton(
                onPressed: onOpen,
                child: Text(L10n.of(context).commonOpen),
              ),
              TextButton(
                onPressed: onStop,
                child: Text(L10n.of(context).commonStop),
              ),
            ],
          ),
        ),
      );
}

/// The turn wanted the web and could not reach it.
///
/// Sits inline with the reply it belongs to — the same slot the browser steps
/// use — so a failed fetch reads as part of the answer instead of a banner
/// floating over the app.
class _OfflineSearchNotice extends StatelessWidget {
  const _OfflineSearchNotice({this.onDismiss});

  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(13, 10, 6, 10),
        decoration: BoxDecoration(
          color: FluxColors.cardOf(context).withValues(alpha: .78),
          borderRadius: BorderRadius.circular(FluxRadius.md),
          border: Border.all(color: FluxColors.lineOf(context)),
        ),
        child: Row(
          children: [
            FluxIcon(
              icon: FluxIcons.cloudOff,
              size: 16,
              color: FluxColors.mutedOf(context),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                L10n.of(context).chatOfflineNotice,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: FluxColors.mutedOf(context),
                    ),
              ),
            ),
            if (onDismiss != null)
              _ReplyActionButton(
                icon: FluxIcons.close,
                tooltip: L10n.of(context).commonDismiss,
                onTap: onDismiss!,
              ),
          ],
        ),
      );
}

/// Shown when the conversation file could not be opened, so replies are only
/// kept in memory. Chatting is still possible — this notice exists so a silent
/// loss of history never happens.
class _HistoryUnavailableNotice extends StatelessWidget {
  const _HistoryUnavailableNotice({this.onDismiss});

  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(13, 10, 6, 10),
        decoration: BoxDecoration(
          color: FluxColors.cardOf(context).withValues(alpha: .78),
          borderRadius: BorderRadius.circular(FluxRadius.md),
          border: Border.all(color: FluxColors.lineOf(context)),
        ),
        child: Row(
          children: [
            FluxIcon(
              icon: FluxIcons.info,
              size: 16,
              color: FluxColors.mutedOf(context),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                L10n.of(context).chatHistoryUnavailableNotice,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: FluxColors.mutedOf(context),
                    ),
              ),
            ),
            if (onDismiss != null)
              _ReplyActionButton(
                icon: FluxIcons.close,
                tooltip: L10n.of(context).commonDismiss,
                onTap: onDismiss!,
              ),
          ],
        ),
      );
}

class _CompleteReply extends StatelessWidget {
  const _CompleteReply({
    required this.text,
    this.userPrompt,
    this.modelTier = 'FinnAI',
    this.status = ConversationMessageStatus.complete,
    this.showActions = true,
    this.onContinue,
    this.onRegenerate,
    this.sources = const [],
    this.toolActivities = const [],
    this.pendingAction,
    this.onRunAction,
    this.onDismissAction,
    this.onSourcesHeightDelta,
  });

  final String text;
  final String? userPrompt;
  final String modelTier;
  final ConversationMessageStatus status;
  final bool showActions;
  final VoidCallback? onContinue;
  final VoidCallback? onRegenerate;
  final List<WebSource> sources;

  /// Browser steps this reply took, kept for the inline search indicator.
  final List<ToolActivity> toolActivities;

  /// A device action this reply is proposing. While it is set the reply shows
  /// its confirm controls and nothing has touched the device yet.
  final DeviceActionInvocation? pendingAction;
  final VoidCallback? onRunAction;
  final VoidCallback? onDismissAction;

  /// Forwards the animated growth of the sources list in pixels so the chat
  /// can keep the answer anchored while the actions below slide down.
  final ValueChanged<double>? onSourcesHeightDelta;

  @override
  Widget build(BuildContext context) {
    final imageUrls = sources
        .map((s) => s.imageUrl)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageUrls.isNotEmpty) ...[
          _ArticlePhotoSlideshow(imageUrls: imageUrls),
          const SizedBox(height: 12),
        ],
        // The assistant answer sits directly on the canvas — no bubble — and its
        // text is natively selectable.
        SelectionArea(child: SafeMarkdownText(text: text)),
        // The confirm controls sit directly under the sentence they confirm, so
        // what is about to happen and the button that does it are read together.
        if (pendingAction != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              FluxPillButton(
                label: L10n.of(context).deviceActionsConfirm,
                icon: FluxIcons.check,
                compact: true,
                onTap: onRunAction,
              ),
              const SizedBox(width: 8),
              FluxPillButton(
                label: L10n.of(context).deviceActionsCancel,
                compact: true,
                onTap: onDismissAction,
              ),
            ],
          ),
        ],
        // Browser steps and the pages they produced sit between the answer and
        // the reply actions: expanding either pushes only the actions below,
        // never the answer above.
        if (toolActivities.isNotEmpty) ...[
          const SizedBox(height: 6),
          ToolActivityIndicator(
            activities: toolActivities,
            busy: status == ConversationMessageStatus.generating,
          ),
        ],
        if (sources.isNotEmpty) ...[
          const SizedBox(height: 6),
          _SourceList(
            sources: sources,
            onHeightDelta: onSourcesHeightDelta ?? (_) {},
          ),
        ],
        if (showActions) ...[
          const SizedBox(height: 6),
          _ReplyActions(
            text: text,
            userPrompt: userPrompt,
            modelTier: modelTier,
            onRegenerate: onRegenerate,
          ),
          if (status == ConversationMessageStatus.generating) ...[
            const SizedBox(height: 5),
            Text(
              L10n.of(context).chatFinnTyping,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: FluxColors.mutedOf(context),
                  ),
            ),
          ],
          if (onContinue != null)
            TextButton.icon(
              onPressed: onContinue,
              icon: const FluxIcon(icon: FluxIcons.arrowRight02, size: 17),
              label: Text(L10n.of(context).commonContinue),
            ),
        ],
      ],
    );
  }
}

/// Compact, always-visible row of low-emphasis actions for a completed reply:
/// copy, report, and an overflow that carries regenerate. Selection is handled
/// natively on the text, so there is no separate "Select" action.
class _ReplyActions extends StatefulWidget {
  const _ReplyActions({
    required this.text,
    required this.userPrompt,
    required this.modelTier,
    this.onRegenerate,
  });

  final String text;
  final String? userPrompt;
  final String modelTier;
  final VoidCallback? onRegenerate;

  @override
  State<_ReplyActions> createState() => _ReplyActionsState();
}

class _ReplyActionsState extends State<_ReplyActions> {
  final GlobalKey _overflowKey = GlobalKey();

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(L10n.of(context).commonCopiedToClipboard),
          duration: const Duration(milliseconds: 900),
        ),
      );
  }

  void _openOverflow() {
    final regenerate = widget.onRegenerate;
    if (regenerate == null) return;
    showFluxContextMenu<void>(
      context: context,
      targetKey: _overflowKey,
      previewWidget: Container(
        constraints: BoxConstraints(
          maxWidth: math.min(MediaQuery.sizeOf(context).width * .82, 620),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: FluxColors.cardOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.sm),
        ),
        child: Text(
          widget.text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      items: <FluxContextMenuItem>[
        FluxContextMenuItem(
          icon: FluxIcons.refresh,
          label: L10n.of(context).chatRegenerate,
          onTap: regenerate,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final regenerate = widget.onRegenerate;
    // The row arrives with the finished reply, so it settles in rather than
    // appearing under text that was already on screen.
    return _FadeRise(
      rise: 6,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReplyActionButton(
            asset: FigmaAssets.replyCopy,
            tooltip: L10n.of(context).chatCopy,
            onTap: _copy,
          ),
          _ReplyActionButton(
            asset: FigmaAssets.replyAlert,
            tooltip: L10n.of(context).chatReportAction,
            onTap: () => ReportDialog.show(
              context,
              assistantResponse: widget.text,
              userPrompt: widget.userPrompt,
              modelTier: widget.modelTier,
            ),
          ),
          if (regenerate != null)
            _ReplyActionButton(
              key: _overflowKey,
              asset: FigmaAssets.replyMore,
              tooltip: L10n.of(context).chatMoreActions,
              onTap: _openOverflow,
            ),
        ],
      ),
    );
  }
}

/// One glyph of the row that sits under a reply: the design's 25px artwork on
/// a 40px touch target.
class _ReplyActionButton extends StatelessWidget {
  const _ReplyActionButton({
    super.key,
    this.asset,
    this.icon,
    required this.tooltip,
    required this.onTap,
  }) : assert(asset != null || icon != null);

  /// The design's own artwork for the reply row.
  final String? asset;

  /// Glyph alternative used by the notices that share this touch target.
  final List<List<dynamic>>? icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FluxPressScale(
        scale: .9,
        child: SizedBox.square(
          dimension: 40,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: asset != null
                  ? FigmaSvg(asset: asset!, width: 25, height: 25)
                  : FluxIcon(
                      icon: icon!,
                      size: 20,
                      color: FluxColors.mutedOf(context),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticlePhotoSlideshow extends StatefulWidget {
  const _ArticlePhotoSlideshow({required this.imageUrls});

  final List<String> imageUrls;

  @override
  State<_ArticlePhotoSlideshow> createState() => _ArticlePhotoSlideshowState();
}

class _ArticlePhotoSlideshowState extends State<_ArticlePhotoSlideshow> {
  late final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    final count = widget.imageUrls.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(FluxRadius.md),
      child: Container(
        height: 200,
        width: double.infinity,
        color: isDark
            ? FluxColors.bubbleAssistantDark
            : FluxColors.bubbleUserLight,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: count,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, index) {
                final url = widget.imageUrls[index];
                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => Center(
                    child: FluxIcon(
                      icon: FluxIcons.image,
                      size: 28,
                      color: FluxColors.mutedOf(context),
                    ),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                          color: FluxColors.mutedOf(context),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            if (count > 1)
              Positioned(
                bottom: 10,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(FluxRadius.pill),
                  ),
                  child: Text(
                    '${_currentPage + 1}/$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Collapsible sources list shown under a web-grounded answer: the favicon of
/// the first page, its host, and a chevron that rotates down to reveal every
/// source the turn used. It shares [FluxDisclosure] with the browser-steps
/// indicator so both read as the same affordance. The revealed list has no card
/// background — it reads as a plain list — and its growth is reported per frame
/// so the chat can keep the answer above anchored while only the content below
/// slides.
class _SourceList extends StatelessWidget {
  const _SourceList({required this.sources, required this.onHeightDelta});

  final List<WebSource> sources;

  /// Per-frame growth (or shrink) of the expanded list in pixels.
  final ValueChanged<double> onHeightDelta;

  Future<void> _open(BuildContext context, WebSource source) async {
    final uri = source.url;
    if (uri.scheme != 'http' && uri.scheme != 'https') return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// The source's excerpt, or empty when the search service only had its
  /// "no excerpt" placeholder to offer.
  static String _snippetOf(WebSource source) {
    final snippet = source.snippet.replaceAll(RegExp(r'\s+'), ' ').trim();
    return snippet == 'No excerpt available.' ? '' : snippet;
  }

  @override
  Widget build(BuildContext context) {
    final firstHost = sources.isNotEmpty
        ? sources.first.url.host.replaceFirst(RegExp(r'^www\.'), '')
        : L10n.of(context).chatSources;
    final extraCount = sources.length - 1;

    return FluxDisclosure(
      leading: _SourceFavicon(source: sources.first, size: 16),
      label: firstHost,
      trailing: extraCount > 0 ? '+$extraCount' : null,
      expandLabel: L10n.of(context).chatShowSources,
      collapseLabel: L10n.of(context).chatHideSources,
      onHeightDelta: onHeightDelta,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final source in sources)
            FluxDisclosureRow(
              leading: _SourceFavicon(source: source, size: 18),
              title: source.title.isEmpty ? source.url.host : source.title,
              subtitle: _snippetOf(source),
              onTap: () => _open(context, source),
            ),
        ],
      ),
    );
  }
}

/// Deterministic stand-in for the website's favicon: a circle tinted from the
/// hostname with the domain's initial letter, so sources are easy to tell
/// apart without fetching anything over the network.
class _SourceFavicon extends StatelessWidget {
  const _SourceFavicon({required this.source, this.size = 18});

  final WebSource source;
  final double size;

  static const List<Color> _palette = [
    Color(0xFF4A7CF3),
    Color(0xFFE05D3B),
    Color(0xFF2FA36B),
    Color(0xFF9B59B6),
    Color(0xFFE2A12E),
    Color(0xFF3BA7C9),
    Color(0xFFE05C8A),
    Color(0xFF5F6B7A),
  ];

  @override
  Widget build(BuildContext context) {
    final host = source.url.host.replaceFirst('www.', '');
    final letter = host.isEmpty ? '?' : host[0].toUpperCase();
    final color = _palette[host.hashCode.abs() % _palette.length];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.55,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

/// The shared slide-and-fade transition for full-screen sub-pages.
///
/// Public so creations, decks and mini-app hosts push with the same motion as
/// the sidebar destinations rather than each defining their own.
class FinnPageRoute<T> extends PageRouteBuilder<T> {
  FinnPageRoute({required Widget child})
      : super(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, page) {
            if (MediaQuery.disableAnimationsOf(context)) return page;
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubicEmphasized,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(.08, 0),
                  end: Offset.zero,
                ).animate(curved),
                // A hair of scale gives the incoming page depth, so it reads
                // as arriving from behind the current one instead of sliding
                // flat over it. Anchored to the edge it slides from.
                child: ScaleTransition(
                  scale: Tween<double>(begin: .985, end: 1).animate(curved),
                  alignment: Alignment.centerRight,
                  child: page,
                ),
              ),
            );
          },
        );
}

class _ErrorReply extends StatelessWidget {
  const _ErrorReply({super.key, required this.text, this.onRetry});

  final String text;

  /// Retries the failed turn. Null when the failed assistant message is not in
  /// this conversation, in which case there is nothing to re-run.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Bubble(text: text),
        if (retry != null) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: retry,
            icon: const FluxIcon(icon: FluxIcons.refresh, size: 16),
            label: Text(L10n.of(context).commonRetry),
            style: TextButton.styleFrom(
              foregroundColor: FluxColors.inkOf(context),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 48),
            ),
          ),
        ],
      ],
    );
  }
}

/// Edit dialog that owns its text controller, used to rewrite a user message
/// before the turn is answered again.
class _EditMessageDialog extends StatefulWidget {
  const _EditMessageDialog({required this.initialText});

  final String initialText;

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: FluxColors.cardOf(context),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FluxRadius.sheet),
        ),
        title: Text(
          L10n.of(context).chatEditMessage,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w400),
        ),
        content: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 1,
          maxLines: 6,
          maxLength: 4000,
          textCapitalization: TextCapitalization.sentences,
          decoration:
              InputDecoration(hintText: L10n.of(context).chatRewriteHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(L10n.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: Text(L10n.of(context).commonResend),
          ),
        ],
      );
}

class _IMessageAttachmentMenu extends StatefulWidget {
  const _IMessageAttachmentMenu({
    required this.onSelectCamera,
    required this.onSelectPhoto,
    required this.onSelectFile,
  });

  final VoidCallback onSelectCamera;
  final VoidCallback onSelectPhoto;
  final VoidCallback onSelectFile;

  @override
  State<_IMessageAttachmentMenu> createState() =>
      _IMessageAttachmentMenuState();
}

class _IMessageAttachmentMenuState extends State<_IMessageAttachmentMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  late final Animation<double> _scaleAnimation = Tween<double>(
    begin: 0.94,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  late final Animation<double> _fadeAnimation = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    final monochromeBg =
        isDark ? FluxColors.darkCard : FluxColors.bubbleUserLight;
    final monochromeIcon = isDark
        ? FluxColors.bubbleAssistantLight
        : FluxColors.bubbleAssistantDark;

    final items = [
      (
        title: L10n.of(context).attachmentCamera,
        icon: HugeIcons.strokeRoundedCamera01,
        iconBg: monochromeBg,
        iconColor: monochromeIcon,
        onTap: widget.onSelectCamera,
      ),
      (
        title: L10n.of(context).attachmentPhotos,
        icon: HugeIcons.strokeRoundedImage01,
        iconBg: monochromeBg,
        iconColor: monochromeIcon,
        onTap: widget.onSelectPhoto,
      ),
      (
        title: L10n.of(context).attachmentFiles,
        icon: HugeIcons.strokeRoundedFolder01,
        iconBg: monochromeBg,
        iconColor: monochromeIcon,
        onTap: widget.onSelectFile,
      ),
    ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        alignment: Alignment.bottomLeft,
        scale: _scaleAnimation.value,
        child: Opacity(
          opacity: _fadeAnimation.value.clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FluxRadius.sheet),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            width: 220,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xD91E1E22) : const Color(0xEBFFFFFF),
              borderRadius: BorderRadius.circular(FluxRadius.sheet),
              border: Border.all(
                color:
                    isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                width: 0.75,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++)
                  _buildItemRow(
                    index: i,
                    total: items.length,
                    item: items[i],
                    isDark: isDark,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow({
    required int index,
    required int total,
    required ({
      String title,
      List<List<dynamic>> icon,
      Color iconBg,
      Color iconColor,
      VoidCallback onTap,
    }) item,
    required bool isDark,
  }) {
    final start = (index * 0.06).clamp(0.0, 0.5);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final rowAnimation = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: rowAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 8 * (1 - rowAnimation.value)),
        child: Opacity(
          opacity: rowAnimation.value.clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(FluxRadius.sm),
          splashColor:
              isDark ? const Color(0x28FFFFFF) : const Color(0x18000000),
          highlightColor:
              isDark ? const Color(0x14FFFFFF) : const Color(0x0C000000),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: item.icon,
                      color: item.iconColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.2,
                      color: isDark
                          ? Colors.white
                          : FluxColors.bubbleAssistantDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Swaps a single control when [swapKey] changes, replaying a short scale-pop.
///
/// A cross-fade would hold the outgoing control in the tree for the length of
/// the transition — and, because a fully transparent child is dropped from the
/// semantics tree, would briefly hide the incoming one from a screen reader.
/// Animating one child keeps both the tree and the accessibility label honest:
/// the previous control is gone the moment the state changes.
class _ControlSwap extends StatefulWidget {
  const _ControlSwap({required this.swapKey, required this.child});

  /// Changing this replays the pop.
  final Object swapKey;
  final Widget child;

  @override
  State<_ControlSwap> createState() => _ControlSwapState();
}

class _ControlSwapState extends State<_ControlSwap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  late final Animation<double> _pop = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didUpdateWidget(covariant _ControlSwap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.swapKey == widget.swapKey) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Never fully transparent: an opacity of zero is exactly what would drop
    // the control's semantics while it animates in.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: .5 + .5 * _fade.value,
        child: Transform.scale(scale: .82 + .18 * _pop.value, child: child),
      ),
      child: widget.child,
    );
  }
}

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.blocked,
    required this.onSend,
    this.busy = false,
    this.preparing = false,
    this.compact = false,
    this.attachmentPath,
    this.isAttachmentMenuOpen = false,
    this.onPickAttachment,
    this.onRemoveAttachment,
    this.onReturnToLatest,
    this.width,
    this.onStop,
    this.voiceEnabled = false,
    this.onMic,
    this.voiceListening = false,
    this.onVoiceToggle,
    this.onVoiceExpand,
    this.hintText,
    this.pickAttachmentSemanticLabel,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool blocked;
  final VoidCallback onSend;

  /// Placeholder for the field. Defaults to the chat prompt so conversations
  /// keep their own wording while other entry points reuse the same pill.
  final String? hintText;

  /// Accessibility label for the leading button, which means "attach" in a
  /// conversation but "pick a kind" where the pill only opens a chooser.
  final String? pickAttachmentSemanticLabel;

  /// True only while a real turn is being prepared. [blocked] is also true
  /// during cold-start store initialization, but the field must not claim
  /// "Finn is typing…" when nothing is being generated.
  final bool preparing;

  /// Optional attached file/image path for multimodal queries.
  final String? attachmentPath;

  /// True when the iMessage-style floating attachment menu is open.
  final bool isAttachmentMenuOpen;

  /// Invoked when the user taps the '+' attachment button on the left.
  final VoidCallback? onPickAttachment;

  /// Invoked when the user dismisses an attached file/image.
  final VoidCallback? onRemoveAttachment;

  /// True while a reply is generating. Input stays enabled so the user can
  /// draft the next message, but sending is disabled until the turn ends.
  final bool busy;

  /// When true the whole pill scales down uniformly to 85% around its
  /// center — used while the user scrolls away from the newest message.
  /// Restored to full size near the bottom.
  final bool compact;

  /// Invoked when the field is tapped or focused so the shell can scroll the
  /// chat back to the latest message.
  final VoidCallback? onReturnToLatest;

  /// Full-size width of the pill. When null the pill fills its constraints.
  final double? width;

  /// Invoked while a reply is generating to stop it — the send button becomes
  /// a stop control while [busy] is true.
  final VoidCallback? onStop;

  /// True when voice input is available on this platform. Shows a mic button
  /// next to the send control.
  final bool voiceEnabled;

  /// Invoked when the user taps the mic button to open voice mode.
  final VoidCallback? onMic;

  /// True while the composer is listening for voice input. The pill takes the
  /// listening wash and the trailing control becomes the mic being spoken to.
  final bool voiceListening;

  /// Ends voice input — the shell sends whatever was heard.
  final VoidCallback? onVoiceToggle;

  /// Opens the full-screen voice mode from the inline listening state.
  final VoidCallback? onVoiceExpand;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late bool _hasText;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_changed);
    widget.focusNode.addListener(_onFocusChanged);
  }

  void _changed() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (_hasText == hasText) return;
    setState(() {
      _hasText = hasText;
    });
  }

  void _onFocusChanged() {
    // Tapping the field pops the keyboard and returns the user to the latest
    // message, so the pill expands back to full size.
    if (widget.focusNode.hasFocus) {
      widget.onReturnToLatest?.call();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final hasAttachment =
        widget.attachmentPath != null && widget.attachmentPath!.isNotEmpty;
    final canSend =
        (_hasText || hasAttachment) && !widget.blocked && !widget.busy;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final listening = widget.voiceListening;
    final isDark = FluxColors.isDark(context);
    // While listening the middle pill becomes the design's waveform indicator
    // and the live transcript floats above the control row.
    final transcript = listening ? widget.controller.text.trim() : '';
    final hasDraft = _hasText || hasAttachment;

    // One circular control of the composer row: 50dp, flat colour, glyph.
    Widget circle({
      required Key key,
      required Color color,
      required Widget child,
      VoidCallback? onTap,
      String? label,
      bool dimmed = false,
    }) =>
        Semantics(
          button: true,
          enabled: onTap != null,
          label: label,
          onTap: onTap,
          excludeSemantics: true,
          child: FluxPressScale(
            enabled: onTap != null,
            child: Material(
              color: color,
              shape: const CircleBorder(),
              child: SizedBox.square(
                key: key,
                dimension: 50,
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: Opacity(opacity: dimmed ? .38 : 1, child: child),
                  ),
                ),
              ),
            ),
          ),
        );

    // Left: attachments, or the design's cancel cross while listening.
    final leading = circle(
      key: const ValueKey('add-attachment-button'),
      color: FluxColors.controlOf(context),
      label: listening
          ? l10n.voiceCancelSemantic
          : widget.pickAttachmentSemanticLabel ??
              l10n.chatAddAttachmentSemantic,
      onTap: listening
          ? widget.onVoiceToggle
          : (widget.blocked || widget.busy ? null : widget.onPickAttachment),
      child: AnimatedRotation(
        turns: (widget.isAttachmentMenuOpen || listening) ? .125 : 0.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: const FigmaSvg(
          asset: FigmaAssets.composerAdd,
          width: 25,
          height: 25,
        ),
      ),
    );

    // Right: stop while generating, the mic while listening, send once there
    // is something to send, and the design's voice button otherwise. The key
    // below is what lets the swap between them animate instead of blinking.
    final trailingMode = widget.busy
        ? 'stop'
        : listening
            ? 'voice'
            : hasDraft
                ? 'send'
                : 'mic';
    final trailingControl = widget.busy
        ? circle(
            key: const ValueKey('stop-button-surface'),
            color: FluxColors.actionOf(context),
            label: l10n.chatStopGeneratingSemantic,
            onTap: widget.onStop,
            child: SizedBox.square(
              dimension: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: FluxColors.actionInkOf(context),
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ),
          )
        : listening
            ? circle(
                key: const ValueKey('voice-toggle-surface'),
                color: FluxColors.controlOf(context),
                label: l10n.chatSendMessageSemantic,
                onTap: widget.onVoiceToggle,
                child: const FigmaSvg(
                  asset: FigmaAssets.voiceMic,
                  width: 25,
                  height: 25,
                ),
              )
            : hasDraft
                ? circle(
                    key: const ValueKey('send-button-hit'),
                    color: FluxColors.actionOf(context),
                    label: l10n.chatSendMessageSemantic,
                    onTap: canSend ? widget.onSend : null,
                    dimmed: !canSend,
                    child: FluxIcon(
                      key: const ValueKey('send-button-icon'),
                      icon: FluxIcons.arrowUp02,
                      size: 24,
                      color: FluxColors.actionInkOf(context),
                      strokeWidth: 2,
                    ),
                  )
                : circle(
                    key: const ValueKey('mic-button-surface'),
                    color: FluxColors.actionOf(context),
                    label: l10n.voiceMicSemantic,
                    onTap: widget.voiceEnabled ? widget.onMic : null,
                    child: const FigmaSvg(
                      asset: FigmaAssets.composerVoice,
                      width: 25,
                      height: 25,
                    ),
                  );
    // Mic → send → stop as the field fills and the turn runs: one control that
    // pops when it changes, rather than two cross-fading over each other.
    final trailing = _ControlSwap(
      swapKey: trailingMode,
      child: trailingControl,
    );

    // The middle pill: the input itself, or the listening gradient.
    final pill = AnimatedContainer(
      key: const ValueKey('chat-composer-motion'),
      duration:
          reducedMotion ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: listening ? null : FluxColors.controlOf(context),
        gradient: listening ? FluxColors.voiceGradient : null,
        borderRadius: BorderRadius.circular(
          hasAttachment ? FluxRadius.sheet : FluxRadius.pill,
        ),
        boxShadow: listening
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: isDark ? 20 : 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      constraints: const BoxConstraints(minHeight: 50, maxHeight: 220),
      padding:
          listening ? EdgeInsets.zero : const EdgeInsets.fromLTRB(17, 1, 4, 1),
      child: listening
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasAttachment)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 8,
                      left: 6,
                      right: 6,
                      top: 2,
                    ),
                    child: Row(
                      children: [
                        _buildAttachmentPreview(
                          context,
                          widget.attachmentPath!,
                        ),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      // The pill reads as one big input, so the whole row
                      // focuses the field: a bare single-line TextField is
                      // only as tall as its text (measured on device: 20dp
                      // inside a 56dp pill), which left most of the visible
                      // field inert. The band carries the target and the
                      // field keeps its natural height, centred inside it.
                      child: Semantics(
                        label: l10n.chatMessageToFinnSemantic,
                        textField: true,
                        child: GestureDetector(
                          key: const ValueKey('composer-field-band'),
                          behavior: HitTestBehavior.opaque,
                          // The band is a touch target, not a second control:
                          // the field keeps its own semantics, so a screen
                          // reader still reads exactly one text field here.
                          excludeFromSemantics: true,
                          onTap: () => widget.focusNode.requestFocus(),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Center(
                              child: TextField(
                                controller: widget.controller,
                                focusNode: widget.focusNode,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(4000),
                                ],
                                enabled: !widget.blocked,
                                minLines: 1,
                                maxLines: 5,
                                textAlignVertical: TextAlignVertical.center,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) =>
                                    canSend ? widget.onSend() : null,
                                onTap: () => widget.onReturnToLatest?.call(),
                                style: TextStyle(
                                  fontFamily: 'InstrumentSans',
                                  fontSize: 16,
                                  height: 1.25,
                                  fontWeight: FontWeight.w400,
                                  color: FluxColors.inkOf(context),
                                ),
                                cursorColor: FluxColors.inkOf(context),
                                decoration: InputDecoration.collapsed(
                                  hintText: widget.hintText ??
                                      (widget.preparing
                                          ? l10n.chatFinnTyping
                                          : l10n.chatAskAnythingHint),
                                  // One line, always. A wrapped hint stretches
                                  // the field — and with it the pill — on
                                  // narrow screens and in longer locales.
                                  hintMaxLines: 1,
                                  hintStyle: TextStyle(
                                    fontFamily: 'InstrumentSans',
                                    fontSize: 16,
                                    height: 1.25,
                                    fontWeight: FontWeight.w400,
                                    color: FluxColors.inkOf(context)
                                        .withValues(alpha: .55),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );

    // The design floats the live transcript above the controls while
    // listening; the pill itself only carries the gradient.
    final transcriptPill = transcript.isEmpty
        ? null
        : Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: FluxColors.controlOf(context),
              borderRadius: BorderRadius.circular(FluxRadius.pill),
            ),
            child: Text(
              transcript,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'InstrumentSans',
                fontSize: 16,
                height: 1.25,
                fontWeight: FontWeight.w400,
                color: FluxColors.inkOf(context),
              ),
            ),
          );

    // The control row condenses around its own centre while scrolled away: it
    // scales down uniformly to 85%, so the length shortens a bit while the
    // items inside shrink proportionally. Full size is restored at the bottom.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.compact ? 1.0 : 0.0),
      duration:
          reducedMotion ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, shrink, child) => Transform.scale(
        alignment: Alignment.center,
        scale: 1 - 0.15 * shrink,
        child: child,
      ),
      child: SizedBox(
        width: widget.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (transcriptPill != null) ...[
              Center(child: transcriptPill),
              const SizedBox(height: 40),
            ],
            if (listening)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  leading,
                  const SizedBox(width: 20),
                  SizedBox(width: 100, height: 50, child: pill),
                  const SizedBox(width: 20),
                  trailing,
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  leading,
                  const SizedBox(width: 20),
                  Expanded(child: pill),
                  const SizedBox(width: 20),
                  trailing,
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(BuildContext context, String path) {
    final isDark = FluxColors.isDark(context);
    final file = File(path);
    final fileName = path.split(Platform.pathSeparator).last;
    final isImg = _isImage(path);

    bool fileExists = false;
    try {
      fileExists = file.existsSync();
    } catch (_) {
      fileExists = false;
    }
    if (isImg && fileExists) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FluxRadius.sm),
              border: Border.all(
                color:
                    isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(FluxRadius.sm),
              child: Image.file(
                file,
                width: 54,
                height: 54,
                cacheWidth: 400,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : FluxColors.bubbleUserLight,
                  child: Center(
                    child: FluxIcon(
                      icon: FluxIcons.brokenImage,
                      size: 20,
                      color: FluxColors.mutedOf(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: widget.onRemoveAttachment,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF48484A)
                      : const Color(0xFF3A3A3C),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF18181B) : Colors.white,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: const Center(
                  child: FluxIcon(
                    icon: FluxIcons.close,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Document or non-image file
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toUpperCase()
        : 'FILE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFEFF4),
        borderRadius: BorderRadius.circular(FluxRadius.pill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color:
                  isDark ? const Color(0xFF3A3A3C) : FluxColors.bubbleUserLight,
              borderRadius: BorderRadius.circular(FluxRadius.pill),
            ),
            child: Text(
              ext.length > 4 ? ext.substring(0, 4) : ext,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : FluxColors.bubbleAssistantDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onRemoveAttachment,
            child: FluxIcon(
              icon: FluxIcons.close,
              size: 14,
              color: FluxColors.mutedOf(context),
            ),
          ),
        ],
      ),
    );
  }

  bool _isImage(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.gif');
  }
}

class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.onClose,
    required this.onNewConversation,
    required this.onConversation,
    required this.conversations,
    required this.activeConversationId,
    required this.onCreations,
    required this.onYou,
    required this.onFlows,
    required this.onActions,
    required this.onSettings,
  });

  final VoidCallback onClose;
  final VoidCallback onNewConversation;
  final ValueChanged<String> onConversation;
  final List<FinnConversation> conversations;
  final String? activeConversationId;
  final VoidCallback onCreations;
  final VoidCallback onYou;
  final VoidCallback onFlows;
  final VoidCallback onActions;
  final VoidCallback onSettings;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  late final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      _scrollOffset.value = _scrollController.offset;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double safeBottom = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: FluxColors.controlOf(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double sy = (constraints.maxHeight / 912).clamp(0.72, 1.3);
          const double headerHeight = 50;
          final double headerTop = 70 * sy;
          // Three 70px destinations with the design's 30px gutters.
          final double navSize = ((constraints.maxWidth - 50 - 60) / 3).clamp(
            56.0,
            80.0,
          );
          final double navHeight = navSize + 22;
          final double navTop = 139 * sy;
          final double titleTop = 262 * sy;
          const double titleHeight = 24;
          final double historyTopAtRest = titleTop + titleHeight + 8;
          final double pinnedTitleTop = headerTop + 14;
          final double titleTravelDistance = math.max(
            1.0,
            titleTop - pinnedTitleTop,
          );
          final double bottomBarHeight = 50 + 20 + safeBottom;

          return Stack(
            children: [
              // 1. Chat history, scrolling beneath the pinned header.
              Positioned.fill(
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const FluxBouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.only(
                        left: 25,
                        right: 25,
                        top: historyTopAtRest,
                        bottom: bottomBarHeight + 40,
                      ),
                      sliver: widget.conversations.isEmpty
                          ? SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 40,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const FigmaSvg(
                                      asset: FigmaAssets.noHistory,
                                      width: 40,
                                      height: 40,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      L10n.of(context).chatNoHistory,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: FluxColors.mutedOf(context),
                                            fontSize: 10,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                mainAxisExtent: 100,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final conversation =
                                      widget.conversations[index];
                                  final card = _SidebarConversationTile(
                                    key: ValueKey(conversation.id),
                                    conversation: conversation,
                                    selected: conversation.id ==
                                        widget.activeConversationId,
                                    onTap: () =>
                                        widget.onConversation(conversation.id),
                                  );
                                  // The design's staggered grid: the right
                                  // column starts half a card lower than the
                                  // left one.
                                  return index.isOdd
                                      ? Transform.translate(
                                          offset: const Offset(0, 55),
                                          child: card,
                                        )
                                      : card;
                                },
                                childCount: widget.conversations.length,
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              // 2. Lightweight pinned-header surface. A solid surface avoids
              // per-frame backdrop filtering while preserving legibility.
              ValueListenableBuilder<double>(
                valueListenable: _scrollOffset,
                builder: (context, offset, _) {
                  final double scrollUp = math.max(0.0, offset);
                  final double coverProgress = (scrollUp / 24.0).clamp(
                    0.0,
                    1.0,
                  );
                  final double coverHeight = coverProgress <= 0
                      ? 0.0
                      : (pinnedTitleTop + titleHeight + 18 * sy);

                  return Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: coverHeight,
                    child: IgnorePointer(
                      child: coverProgress <= 0
                          ? const SizedBox()
                          : ColoredBox(
                              color: FluxColors.controlOf(
                                context,
                              ).withValues(alpha: .96),
                            ),
                    ),
                  );
                },
              ),

              // 3. Brand row with the close control.
              Positioned(
                left: 25,
                right: 25,
                top: headerTop,
                height: headerHeight,
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  builder: (context, offset, child) {
                    final double pullDown = offset < 0 ? -offset : 0.0;
                    final double shift = pullDown * 0.20;
                    final double scrollUp = math.max(0.0, offset);
                    final double opacity =
                        (1.0 - (scrollUp / (titleTravelDistance * 0.5))).clamp(
                      0.0,
                      1.0,
                    );

                    return IgnorePointer(
                      ignoring: opacity < 0.5,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(0, shift),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            L10n.of(context).appBrandFinnAI,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ),
                      ),
                      _SidebarCircleButton(
                        asset: FigmaAssets.appClose,
                        tooltip: L10n.of(context).commonClose,
                        background: FluxColors.controlOf(context),
                        onTap: widget.onClose,
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Local feature destinations.
              Positioned(
                left: 25,
                right: 25,
                top: navTop,
                height: navHeight,
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  builder: (context, offset, child) {
                    final double pullDown = offset < 0 ? -offset : 0.0;
                    final double shift = pullDown * 0.45;
                    final double scrollUp = math.max(0.0, offset);
                    final double opacity =
                        (1.0 - (scrollUp / (titleTravelDistance * 0.7))).clamp(
                      0.0,
                      1.0,
                    );

                    return IgnorePointer(
                      ignoring: opacity < 0.5,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(0, shift),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SidebarCircleTile(
                        asset: FigmaAssets.tileCreations,
                        label: L10n.of(context).creationsTitle,
                        onTap: widget.onCreations,
                        size: navSize,
                      ),
                      _SidebarCircleTile(
                        asset: FigmaAssets.tileFlows,
                        label: L10n.of(context).flowsTitle,
                        onTap: widget.onFlows,
                        size: navSize,
                      ),
                      _SidebarCircleTile(
                        asset: FigmaAssets.tileYou,
                        label: L10n.of(context).youTitle,
                        onTap: widget.onYou,
                        size: navSize,
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Chat History Title - lifts up on scroll all the way to
              // headerTop replacing content beneath, spring overscroll on pull
              // down.
              Positioned(
                left: 25,
                right: 25,
                top: titleTop,
                height: titleHeight,
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  builder: (context, offset, child) {
                    double shift;
                    if (offset < 0) {
                      final double pullDown = -offset;
                      shift = pullDown * 0.70;
                    } else {
                      shift = -math.min(titleTravelDistance, offset);
                    }
                    return Transform.translate(
                      offset: Offset(0, shift),
                      child: child,
                    );
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      L10n.of(context).chatHistory,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 18,
                          ),
                    ),
                  ),
                ),
              ),

              // 6. The two shortcuts that used to sit in the header.
              Positioned(
                left: 25,
                bottom: safeBottom + 3,
                height: 50,
                child: Row(
                  children: [
                    _SidebarCircleButton(
                      asset: FigmaAssets.appNewChat,
                      tooltip: L10n.of(context).chatNewChat,
                      background: FluxColors.tileOf(context),
                      onTap: widget.onNewConversation,
                    ),
                    const SizedBox(width: 11),
                    _SidebarCircleButton(
                      asset: FigmaAssets.appSettings,
                      tooltip: L10n.of(context).settingsTitle,
                      background: FluxColors.tileOf(context),
                      onTap: widget.onSettings,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A circular shortcut in the sidebar: the nav destinations and the bottom
/// pair all share this shape.
class _SidebarCircleTile extends StatelessWidget {
  const _SidebarCircleTile({
    required this.label,
    required this.onTap,
    this.icon,
    this.asset,
    this.size = 70,
  }) : assert(icon != null || asset != null);

  final List<List<dynamic>>? icon;
  final String? asset;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: FluxPressScale(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(FluxRadius.sm),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(FluxRadius.sm),
              child: SizedBox(
                width: size,
                height: size + 22,
                child: Column(
                  children: [
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: FluxColors.tileOf(context),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: asset != null
                            ? FigmaSvg(
                                asset: asset!,
                                width: size * .57,
                                height: size * .57,
                              )
                            : FluxIcon(
                                icon: icon!,
                                size: size * 0.42,
                                color: FluxColors.inkOf(context),
                              ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 17,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'InstrumentSans',
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w400,
                            color: FluxColors.inkOf(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// A circular icon-only control, e.g. close, new chat or settings.
class _SidebarCircleButton extends StatelessWidget {
  const _SidebarCircleButton({
    required this.tooltip,
    required this.background,
    required this.onTap,
    this.icon,
    this.asset,
  }) : assert(icon != null || asset != null);

  final List<List<dynamic>>? icon;
  final String? asset;
  final String tooltip;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          onTap: onTap,
          excludeSemantics: true,
          child: FluxPressScale(
            child: Material(
              color: background,
              shape: const CircleBorder(),
              child: SizedBox.square(
                dimension: 50,
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: asset != null
                        ? FigmaSvg(asset: asset!, width: 25, height: 25)
                        : FluxIcon(
                            icon: icon!,
                            size: 22,
                            color: FluxColors.inkOf(context),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _SidebarConversationTile extends StatelessWidget {
  const _SidebarConversationTile({
    super.key,
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final FinnConversation conversation;
  final bool selected;
  final VoidCallback onTap;

  /// Keys exist only to anchor a tile's context menu. A key is useless once its
  /// tile unmounts, so the cache is pruned instead of retaining one entry for
  /// every conversation the user has ever opened (including deleted ones).
  static final Map<String, GlobalKey> _tileKeys = {};
  static const int _maxRetainedTileKeys = 200;

  GlobalKey _getTileKey() {
    if (_tileKeys.length > _maxRetainedTileKeys) {
      _tileKeys.removeWhere((_, key) => key.currentContext == null);
    }
    return _tileKeys.putIfAbsent(conversation.id, () => GlobalKey());
  }

  void _showContextMenu(BuildContext context) {
    final key = _getTileKey();

    final preview = Container(
      decoration: BoxDecoration(
        color: FluxColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(FluxRadius.sm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Text(
        conversation.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );

    final items = <FluxContextMenuItem>[
      FluxContextMenuItem(
        icon: FluxIcons.edit,
        label: L10n.of(context).chatRenameAction,
        onTap: () => _showRenameDialog(context),
      ),
      FluxContextMenuItem(
        icon: FluxIcons.close,
        label: L10n.of(context).commonDelete,
        isDestructive: true,
        onTap: () => _showDeleteConfirmDialog(context),
      ),
    ];

    showFluxContextMenu<void>(
      context: context,
      targetKey: key,
      previewWidget: preview,
      items: items,
      targetBorderRadius: BorderRadius.circular(14),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: conversation.title);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FluxRadius.sheet),
        ),
        title: Text(L10n.of(context).chatRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: L10n.of(context).chatRenameEnterTitleHint,
          ),
          onSubmitted: (text) {
            Navigator.of(dialogContext).pop();
            ConversationStore.instance.renameConversation(
              conversation.id,
              text,
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              L10n.of(context).commonCancel,
              style: TextStyle(color: FluxColors.mutedOf(context)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ConversationStore.instance.renameConversation(
                conversation.id,
                controller.text,
              );
            },
            child: Text(
              L10n.of(context).commonSave,
              style: TextStyle(
                color: FluxColors.inkOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    final generationActive = conversation.messages.any(
      (message) => message.status == ConversationMessageStatus.generating,
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FluxRadius.sheet),
        ),
        title: Text(L10n.of(context).chatDeleteTitle),
        content: Text(
          generationActive
              ? L10n.of(context).chatDeleteActiveGenerationBody
              : L10n.of(context).chatDeleteConfirmBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              generationActive
                  ? L10n.of(context).commonClose
                  : L10n.of(context).commonCancel,
              style: TextStyle(color: FluxColors.mutedOf(context)),
            ),
          ),
          if (!generationActive)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ConversationStore.instance.deleteConversation(conversation.id);
              },
              child: Text(
                L10n.of(context).commonDelete,
                style: TextStyle(
                  color: FluxColors.isDark(context)
                      ? FluxColors.destructiveDark
                      : FluxColors.destructive,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = _getTileKey();
    final foreground =
        selected ? FluxColors.actionInkOf(context) : FluxColors.inkOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: conversation.title,
      onTap: onTap,
      excludeSemantics: true,
      child: FluxPressScale(
        scale: .96,
        child: Material(
          color: selected
              ? FluxColors.actionOf(context)
              : FluxColors.tileOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.card),
          child: InkWell(
            key: key,
            onTap: onTap,
            onLongPress: () => _showContextMenu(context),
            borderRadius: BorderRadius.circular(FluxRadius.card),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Text(
                      formatConversationTimestamp(
                          context, conversation.updatedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'InstrumentSans',
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w400,
                        color: selected
                            ? FluxColors.actionInkOf(context)
                                .withValues(alpha: .7)
                            : FluxColors.timestampOf(context),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    conversation.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'InstrumentSans',
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w400,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
