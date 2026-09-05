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

import '../conversations/conversation_store.dart';
import '../creations/creations_page.dart';
import '../generation/chat_generation_controller.dart';
import '../inference/device_profile.dart';
import '../inference/finn_inference.dart';
import '../inference/residency_policy.dart';
import '../reporting/report_dialog.dart';
import '../search/search_agent.dart';
import '../search/web_search_agent.dart';
import '../search/web_search_service.dart';
import '../settings/settings_page.dart';
import '../skills/skills_page.dart';
import '../skills/skills_store.dart';
import '../theme/flux_theme.dart';
import '../voice/voice_chat_controller.dart';
import '../voice/voice_settings_store.dart';
import '../voice/voice_sheet.dart';
import '../you/you_page.dart';
import '../you/you_profile_store.dart';
import '../widgets/ambient_background.dart';
import '../widgets/flux_context_menu.dart';
import '../widgets/flux_controls.dart';
import '../widgets/safe_markdown_text.dart';
import '../../l10n/l10n_helper.dart';

bool _isImageAttachmentPath(String path) {
  final extension = path.split('.').last.toLowerCase();
  return const {'jpg', 'jpeg', 'png', 'webp', 'heic'}.contains(extension);
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.generationController,
    this.conversationStore,
    this.inference,
    this.initializeServices = true,
    this.webSearch,
    this.voiceController,
  });

  final ChatGenerationController? generationController;
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
  late final _voice = widget.voiceController ?? VoiceChatController.instance;
  String? _voiceReplyGenerationId;
  Timer? _memoryReleaseTimer;
  static const MethodChannel _memoryPressureChannel =
      MethodChannel('finn_ai/memory.pressure');
  Timer? _prewarmTimer;
  bool _sidebar = false;
  bool _sidebarEverOpened = false;
  bool _preparing = false;
  bool _dismissedSearchNotice = false;
  String? _attachedImagePath;
  Uint8List? _attachedImageBytes;
  bool _attachmentMenuOpen = false;
  late bool _storesReady = !widget.initializeServices;
  static int _welcomeSession = 0;
  late int _welcomeRotation;
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
    }
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
    if (widget.initializeServices) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_initializeStores());
      });
    }
    // Each fresh home screen shows a different "Try asking" suggestion set so
    // the welcome slate never feels stale across app re-opens.
    _welcomeRotation = _welcomeSession++;
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
    await Future.wait([
      _conversations.initialize(),
      YouProfileStore.instance.initialize(),
      SkillsStore.instance.initialize(),
      VoiceSettingsStore.instance.initialize(),
    ]);
    if (!mounted) return;
    // Every cold start lands on the welcome slate instead of dropping the
    // user back into the last conversation. History stays in the sidebar;
    // tapping a past chat re-activates it.
    _conversations.clearActive();
    setState(() => _storesReady = true);
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
        '${_generation.busy}';
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
                content: Text(
                  L10n.of(context).chatImageAnalysisUnavailable,
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      } catch (_) {}
    });
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
          SkillsStore.instance.initialize(),
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
        SkillsStore.instance.promptContextFor(value),
      ].where((item) => item.trim().isNotEmpty).join('\n\n');
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
            content: Text(
              L10n.of(context).chatDownloadModelBody(size),
            ),
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
        });
      }
      // Pass imagePath for persistence (store), but also ensure the history
      // carries bytes when present so the engine can use imageBytes without file I/O.
      await _generation.start(
        conversationId: conversation.id,
        prompt: effectivePrompt,
        imagePath: attached,
        history: attachedBytes != null ? sendHistory : history,
        systemContext: systemContext,
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
      SkillsStore.instance.promptContextFor(latestUser.text),
    ].where((item) => item.trim().isNotEmpty).join('\n\n');
    // Continuations reuse the original turn's sources; the decision pass is
    // disabled for the continuation prompt itself.
    GroundedSearchResult? continuationGrounded;
    if (assistant.sources.isNotEmpty &&
        _webSearch.policy.shouldSearch(latestUser.text)) {
      continuationGrounded = await WebSearchAgent(searchService: _webSearch)
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
      SkillsStore.instance.promptContextFor(latestUser.text),
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
      SkillsStore.instance.promptContextFor(trimmed),
    ].where((item) => item.trim().isNotEmpty).join('\n\n');
    if (mounted) setState(() => _dismissedSearchNotice = false);
    await _generation.replyToExisting(
      conversationId: conversation.id,
      prompt: trimmed,
      history: history,
      systemContext: systemContext,
    );
  }

  void _applySuggestion(String text) {
    _composer.text = text;
    _composer.selection = TextSelection.collapsed(offset: text.length);
    _focusNode.requestFocus();
  }

  Future<void> _openVoiceMode() async {
    if (!voiceSupportedOnPlatform || _busy) return;
    _voice.setSpokenResponses(VoiceSettingsStore.instance.spokenResponses);
    await openVoiceSheet(
      context: context,
      voice: _voice,
      onSendTranscript: _sendVoiceTranscript,
      onStopGeneration: _stopReply,
    );
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
    // the user actually sends a first message. Fresh suggestions each time so
    // a new chat always starts with a new prompt set.
    _conversations.clearActive();
    _welcomeRotation = _welcomeSession++;
    _setSidebar(false);
    setState(() {});
  }

  Future<void> _openCreations() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    Navigator.of(context)
        .push(_FinnPageRoute<void>(child: const CreationsPage()));
  }

  Future<void> _openYou() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    Navigator.of(context).push(
      _FinnPageRoute<void>(
          child: YouPage(onBack: () => Navigator.of(context).pop())),
    );
  }

  Future<void> _openSkills() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    Navigator.of(context).push(
      _FinnPageRoute<void>(
        child: SkillsPage(onBack: () => Navigator.of(context).pop()),
      ),
    );
  }

  Future<void> _openSettings() async {
    await _closeSidebarForNavigation();
    if (!mounted) return;
    Navigator.of(context).push(
      _FinnPageRoute<void>(
        child: SettingsPage(onBack: () => Navigator.of(context).pop()),
      ),
    );
  }

  void _setSidebar(bool open) {
    if (_sidebar == open) return;
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
            final sy = (constraints.maxHeight / 844).clamp(.72, 1.08);
            final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
            final horizontalGutter = constraints.maxWidth < 380 ? 14.0 : 20.0;
            final contentWidth = math.min(
              760.0,
              constraints.maxWidth - horizontalGutter * 2,
            );
            final contentLeft = (constraints.maxWidth - contentWidth) / 2;
            final homeLayer = RepaintBoundary(
              child: AmbientBackground(
                intensity: 1,
                child: Stack(
                  children: [
                    // 0. The scrolling chat list, full-bleed so content can
                    // slide beneath the glass regions at the very top and
                    // very bottom.
                    Positioned(
                      left: contentLeft,
                      width: contentWidth,
                      top: 0,
                      bottom: 0,
                      child: _Conversation(
                        messages: _conversations.active?.messages ?? const [],
                        activeConversationId: _conversations.active?.id,
                        generation: _generation,
                        conversations: _conversations,
                        onStop: _stopReply,
                        onContinue: _continueReply,
                        onRegenerate: _regenerateReply,
                        onEdit: _editUserMessage,
                        onSuggestion: _applySuggestion,
                        onOpenConversation: _activateConversation,
                        preparing: _preparing,
                        welcomeRotation: _welcomeRotation,
                        // First message starts below the header; newest
                        // message sits above the composer.
                        topInset: 125 * sy,
                        bottomInset: safeBottom +
                            (constraints.maxHeight < 650 ? 68 : 78),
                        scrollController: _chatScrollController,
                      ),
                    ),
                    // 2. Floating notices (drawn above the list/glass, below
                    // the header/composer).
                    if (_inference.lastSearchFailed &&
                        !_dismissedSearchNotice &&
                        !_generation.busy)
                      Positioned(
                        left: contentLeft,
                        width: contentWidth,
                        bottom: safeBottom +
                            (constraints.maxHeight < 650 ? 74 : 84),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: FluxColors.cardOf(context),
                            borderRadius: BorderRadius.circular(FluxRadius.sm),
                            border: Border.all(
                              color: FluxColors.lineOf(context),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.cloud_off_outlined,
                                size: 16,
                                color: FluxColors.mutedOf(context),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  L10n.of(context).chatOfflineNotice,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: FluxColors.mutedOf(context),
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(
                                  () => _dismissedSearchNotice = true,
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: FluxColors.mutedOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // 4. Header and composer are the topmost layers: crisp
                    // over the glass and always tappable.
                    Positioned(
                      left: contentLeft,
                      top: 71 * sy,
                      child: _HomeHeader(onMenu: () => _setSidebar(true)),
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
                          bottom: safeBottom +
                              (scrolledAway
                                  ? (constraints.maxHeight < 650 ? 10 : 20)
                                  : (constraints.maxHeight < 650 ? 20 : 30)) +
                              52,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: _IMessageAttachmentMenu(
                            onSelectCamera: _pickFromCamera,
                            onSelectPhoto: _pickFromGallery,
                            onSelectFile: _pickFromFileSystem,
                          ),
                        ),
                      ),
                    ],

                    ValueListenableBuilder<bool>(
                      valueListenable: _chatScrolledAway,
                      builder: (context, scrolledAway, _) => AnimatedPositioned(
                        left: contentLeft,
                        // When scrolled away the pill condenses and sits a
                        // touch lower on screen; full size is restored at the
                        // bottom, so the resting position stays as-is.
                        bottom: safeBottom +
                            (scrolledAway
                                ? (constraints.maxHeight < 650 ? 10 : 20)
                                : (constraints.maxHeight < 650 ? 20 : 30)),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: ChatComposer(
                          controller: _composer,
                          focusNode: _focusNode,
                          blocked: _preparing || !_storesReady,
                          busy: _generation.busy,
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
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
            final sidebarLayer = !_sidebarEverOpened
                ? const SizedBox.shrink()
                : RepaintBoundary(
                    child: _Sidebar(
                      onClose: () => _setSidebar(false),
                      onNewConversation: _newConversation,
                      onConversation: _activateConversation,
                      conversations: _conversations.conversations,
                      activeConversationId: _conversations.active?.id,
                      onCreations: _openCreations,
                      onYou: _openYou,
                      onSkills: _openSkills,
                      onSettings: _openSettings,
                    ),
                  );
            return AnimatedBuilder(
              animation: _sidebarAnimation,
              builder: (context, _) {
                final motion = _sidebarAnimation.value;
                final scale = 1.0 - (.04 * motion);
                return Stack(
                  children: [
                    ExcludeSemantics(
                      excluding: _sidebar,
                      child: Transform.translate(
                        offset: Offset(constraints.maxWidth * .14 * motion, 0),
                        child: Transform.scale(scale: scale, child: homeLayer),
                      ),
                    ),
                    IgnorePointer(
                      ignoring: !_sidebar,
                      child: GestureDetector(
                        onTap: () => _setSidebar(false),
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: .18 * motion),
                        ),
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onMenu});
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 158,
        height: 34,
        child: Row(
          children: [
            Tooltip(
              message: L10n.of(context).chatOpenMenuTooltip,
              child: InkWell(
                onTap: onMenu,
                borderRadius: BorderRadius.circular(17),
                child: const FigmaSvg(
                  asset: FigmaAssets.menu,
                  width: 34,
                  height: 34,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 114,
              height: 24,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  L10n.of(context).appBrandFinnAI,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w400),
                ),
              ),
            ),
          ],
        ),
      );
}

/// A static soft-edge fade that sits over the scrolling chat list so messages
/// appear to slide beneath the header at the top and fade into the very bottom
/// edge of the screen below the composer. It replaces the old progressive
/// backdrop blur with a plain gradient — effectively free per scroll frame —
/// and never reaches full opacity, so the outermost row of the chat stays
/// faintly visible at the screen edges. The header and composer are drawn
/// above these fades in the shell Stack, so they stay crisp and tappable.
class _ChatEdgeFade extends StatelessWidget {
  const _ChatEdgeFade({super.key, required this.top});

  /// True for the fade under the header at the top of the screen, false for
  /// the fade hugging the very bottom edge of the screen.
  final bool top;

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    final color = isDark ? FluxColors.darkCanvas : FluxColors.canvas;
    return DecoratedBox(
      decoration: BoxDecoration(
        // Progressive: mostly transparent across the band and easing smoothly
        // to near-opaque only at the screen edge, so there is no hard line.
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          stops: const [0.0, 0.35, 0.7, 1.0],
          colors: [
            color.withValues(alpha: 0.93),
            color.withValues(alpha: 0.64),
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Cold-start welcome shown when the active conversation has no messages yet:
/// a friendly intro plus tappable suggestions that pre-fill the composer.
/// Clean canvas only — no gradient, no brand mark, no feature pills.
class _ConversationEmpty extends StatelessWidget {
  const _ConversationEmpty({
    required this.onSuggestion,
    required this.rotation,
  });

  final ValueChanged<String> onSuggestion;

  /// Advances each time the home screen opens so the "Try asking" chips
  /// show a different set on every re-open.
  final int rotation;

  /// The localized suggestion pool, windowed by [rotation] so consecutive
  /// opens share only a little overlap.
  List<String> _suggestions(BuildContext context) {
    final l10n = L10n.of(context);
    final pool = [
      l10n.suggestionSummarizeArticle,
      l10n.suggestionExplainSimply,
      l10n.suggestionPlanDay,
      l10n.suggestionDraftEmail,
      l10n.suggestionBrainstormNames,
      l10n.suggestionIdeaToPlan,
      l10n.suggestionDebugError,
      l10n.suggestionGoodbyeNote,
      l10n.suggestionCompareOptions,
      l10n.suggestionFreshPerspective,
    ];
    final start = (rotation * 3) % pool.length;
    return [
      for (var i = 0; i < 4; i++) pool[(start + i) % pool.length],
    ];
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      L10n.of(context).chatHiPrefix,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      L10n.of(context).chatAskAnything,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: FluxColors.mutedOf(context),
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      L10n.of(context).chatTryAsking,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: FluxColors.mutedOf(context),
                            letterSpacing: .4,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final suggestion in _suggestions(context))
                          ActionChip(
                            label: Text(suggestion),
                            onPressed: () => onSuggestion(suggestion),
                            backgroundColor:
                                FluxColors.cardOf(context).withValues(
                              alpha: FluxColors.isDark(context) ? .65 : .75,
                            ),
                            side: BorderSide.none,
                            labelStyle: Theme.of(context).textTheme.labelMedium,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(FluxRadius.pill),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
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
    required this.onEdit,
    required this.onSuggestion,
    required this.onOpenConversation,
    required this.preparing,
    required this.welcomeRotation,
    required this.topInset,
    required this.bottomInset,
    required this.scrollController,
  });
  final List<ConversationMessage> messages;
  final String? activeConversationId;
  final ChatGenerationController generation;
  final ConversationStore conversations;
  final VoidCallback onStop;
  final ValueChanged<ConversationMessage> onContinue;
  final ValueChanged<ConversationMessage> onRegenerate;
  final ValueChanged<ConversationMessage> onEdit;
  final ValueChanged<String> onSuggestion;
  final ValueChanged<String> onOpenConversation;
  final bool preparing;

  /// Advances each time the home screen opens so the welcome slate shows a
  /// fresh "Try asking" suggestion set.
  final int welcomeRotation;

  /// Vertical insets so the first message clears the header and the newest
  /// message clears the composer, while the list still bleeds beneath both
  /// for the soft edge fade.
  final double topInset;
  final double bottomInset;

  /// Scroll controller owned by the shell so it can observe the scroll
  /// position (to collapse the composer) and jump back to the latest message.
  final ScrollController scrollController;

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
    if (widget.messages.isEmpty &&
        activeJob == null &&
        visibleError == null &&
        !widget.preparing) {
      return Padding(
        padding: EdgeInsets.fromLTRB(0, widget.topInset, 0, widget.bottomInset),
        child: _ConversationEmpty(
          onSuggestion: widget.onSuggestion,
          rotation: widget.welcomeRotation,
        ),
      );
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
        // enough to wash over the header; the bottom band fades content into
        // the very bottom edge of the screen and completes exactly at the
        // composer's top edge, so messages stay crisp right up to the input.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 160,
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
        final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                                const Icon(Icons.image_outlined, size: 16),
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
                              const Icon(Icons.image_outlined, size: 16),
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
    final isDark = FluxColors.isDark(context);
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(19),
      topRight: const Radius.circular(19),
      bottomLeft: Radius.circular(widget.user ? 19 : 5),
      bottomRight: Radius.circular(widget.user ? 5 : 19),
    );

    final preview = Container(
      constraints: BoxConstraints(
        maxWidth: math.min(MediaQuery.sizeOf(context).width * .82, 620),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.user
            ? (isDark ? FluxColors.bubbleUserDark : FluxColors.bubbleUserLight)
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
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(19),
      topRight: const Radius.circular(19),
      bottomLeft: Radius.circular(widget.user ? 19 : 5),
      bottomRight: Radius.circular(widget.user ? 5 : 19),
    );

    final bubble = Container(
      key: _bubbleKey,
      constraints: BoxConstraints(
        maxWidth: math.min(MediaQuery.sizeOf(context).width * .82, 620),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.user
            ? (isDark ? FluxColors.bubbleUserDark : FluxColors.bubbleUserLight)
            : FluxColors.cardOf(context),
        borderRadius: borderRadius,
        boxShadow: widget.user
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? .35 : .05),
                  blurRadius: isDark ? 10 : 7,
                  offset: const Offset(0, 3),
                ),
              ],
        border: widget.user
            ? null
            : Border.all(
                color: FluxColors.lineOf(context).withValues(alpha: 0.06),
              ),
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

  @override
  void initState() {
    super.initState();
    _pulse.repeat(reverse: true);
    widget.generation.addListener(_onGenerationChanged);
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
    if (next == _text) return;
    setState(() => _text = next);
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

    if (fullText.isEmpty) {
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
                    color: FluxColors.inkOf(context).withValues(
                      alpha: .3 + .5 * _pulse.value,
                    ),
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

    return Semantics(
      liveRegion: true,
      child: Text(
        fullText,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.38),
      ),
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
            borderRadius: BorderRadius.circular(16),
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
                  onPressed: onOpen, child: Text(L10n.of(context).commonOpen)),
              TextButton(
                  onPressed: onStop, child: Text(L10n.of(context).commonStop)),
            ],
          ),
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

  /// Forwards the animated growth of the sources list in pixels so the chat
  /// can keep the answer anchored while the actions below slide down.
  final ValueChanged<double>? onSourcesHeightDelta;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The assistant answer sits directly on the canvas — no bubble — and its
          // text is natively selectable.
          SelectionArea(child: SafeMarkdownText(text: text)),
          // Sources live between the answer and the reply actions: expanding the
          // list pushes only the actions below it, never the answer above it.
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
                icon: const Icon(Icons.arrow_forward, size: 17),
                label: Text(L10n.of(context).commonContinue),
              ),
          ],
        ],
      );
}

/// Compact, always-visible row of low-emphasis actions for a completed reply:
/// copy, regenerate (when available), and report. Selection is handled
/// natively on the text, so there is no separate "Select" action.
class _ReplyActions extends StatelessWidget {
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

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(L10n.of(context).commonCopiedToClipboard),
          duration: Duration(milliseconds: 900),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final regenerate = onRegenerate;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ReplyActionButton(
          icon: FluxIcons.copy,
          tooltip: L10n.of(context).chatCopy,
          onTap: () => _copy(context),
        ),
        if (regenerate != null) ...[
          const SizedBox(width: 2),
          _ReplyActionButton(
            icon: FluxIcons.refresh,
            tooltip: L10n.of(context).chatRegenerate,
            onTap: regenerate,
          ),
        ],
        const SizedBox(width: 2),
        _ReplyActionButton(
          icon: FluxIcons.flag,
          tooltip: L10n.of(context).chatReportAction,
          onTap: () => ReportDialog.show(
            context,
            assistantResponse: text,
            userPrompt: userPrompt,
            modelTier: modelTier,
          ),
        ),
      ],
    );
  }
}

class _ReplyActionButton extends StatelessWidget {
  const _ReplyActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FluxRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: FluxIcon(
            icon: icon,
            size: 16,
            color: FluxColors.mutedOf(context),
          ),
        ),
      ),
    );
  }
}

/// ChatGPT-style collapsible sources list shown under a web-grounded answer:
/// a compact pill showing up to two website icons, a "Sources" label and a
/// chevron that points right when collapsed and rotates down when expanded to
/// reveal the tappable list of sources. The list has no card background — it
/// reads as a plain list, and its growth is reported per frame so the chat
/// can keep the answer above anchored while only the content below slides.
class _SourceList extends StatefulWidget {
  const _SourceList({required this.sources, required this.onHeightDelta});

  final List<WebSource> sources;

  /// Per-frame growth (or shrink) of the expanded list in pixels.
  final ValueChanged<double> onHeightDelta;

  @override
  State<_SourceList> createState() => _SourceListState();
}

class _SourceListState extends State<_SourceList>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 220);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    reverseDuration: _duration,
  )..addListener(_onFrame);

  late final CurvedAnimation _factor = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  final GlobalKey _contentKey = GlobalKey();
  double? _fullHeight;
  double _lastHeight = 0;

  bool get _expanded => _controller.value > 0;

  void _onFrame() {
    final full = _fullHeight;
    if (full == null) return;
    final current = full * _factor.value;
    final delta = current - _lastHeight;
    if (delta == 0) return;
    _lastHeight = current;
    widget.onHeightDelta(delta);
    setState(() {});
  }

  void _toggle() {
    final size = _contentKey.currentContext?.size;
    if (size == null) return;
    _fullHeight = size.height;
    _lastHeight = size.height * _controller.value;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _controller.value = _expanded ? 0 : 1);
    } else if (_controller.isAnimating) {
      _controller.reverse();
    } else if (_controller.isDismissed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  Future<void> _open(BuildContext context, WebSource source) async {
    final uri = source.url;
    if (uri.scheme != 'http' && uri.scheme != 'https') return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = FluxColors.mutedOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: _expanded
              ? L10n.of(context).chatHideSources
              : L10n.of(context).chatShowSources,
          child: InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(FluxRadius.pill),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // At least one website icon, and a second one when there are
                  // two or more sources.
                  for (var i = 0;
                      i < math.min(2, widget.sources.length);
                      i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    _SourceFavicon(source: widget.sources[i], size: 18),
                  ],
                  const SizedBox(width: 7),
                  Text(
                    L10n.of(context).chatSources,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: muted,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0.0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: Icon(Icons.chevron_right, size: 18, color: muted),
                  ),
                ],
              ),
            ),
          ),
        ),
        // The list is always laid out (so its full height can be measured)
        // but clipped to the animated height factor: it grows downward from
        // the button without a card background. Semantics are excluded while
        // collapsed so the hidden rows are not announced.
        ExcludeSemantics(
          excluding: !_expanded,
          child: ClipRect(
            child: Align(
              heightFactor: _factor.value,
              alignment: Alignment.topCenter,
              child: Column(
                key: _contentKey,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final source in widget.sources)
                    _SourceRow(
                      source: source,
                      onTap: () => _open(context, source),
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

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.onTap});

  final WebSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            _SourceFavicon(source: source, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                source.title.isEmpty ? source.url.host : source.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
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

class _FinnPageRoute<T> extends PageRouteBuilder<T> {
  _FinnPageRoute({required Widget child})
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
                child: page,
              ),
            );
          },
        );
}

class _ErrorReply extends StatelessWidget {
  const _ErrorReply({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => _Bubble(text: text);
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
            borderRadius: BorderRadius.circular(FluxRadius.sheet)),
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

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.blocked,
    required this.onSend,
    this.busy = false,
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
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool blocked;
  final VoidCallback onSend;

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
    final hasAttachment =
        widget.attachmentPath != null && widget.attachmentPath!.isNotEmpty;
    final canSend =
        (_hasText || hasAttachment) && !widget.blocked && !widget.busy;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    // Frosted pill: white on light surfaces, dark glass in dark mode, with a
    // light backdrop blur so content scrolling beneath it reads softly through
    // the translucency. The blur sigma stays modest so low-end devices are not
    // taxed.
    // The whole pill condenses around its own center while scrolled away: it
    // scales down uniformly to 85%, so the length shortens a bit while the
    // items inside shrink proportionally — nothing gets stretched or squished.
    // Full size is restored at the bottom.
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
      child: AnimatedContainer(
        key: const ValueKey('chat-composer-motion'),
        duration:
            reducedMotion ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: FluxColors.isDark(context)
              ? const Color(0xF218181B)
              : const Color(0xF5FFFFFF),
          borderRadius: BorderRadius.circular(hasAttachment ? 22 : 999),
          border: FluxColors.isDark(context)
              ? Border.all(color: const Color(0x28FFFFFF))
              : Border.all(color: FluxColors.line),
        ),
        width: widget.width,
        constraints: const BoxConstraints(minHeight: 42, maxHeight: 220),
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
        child: Column(
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
                    _buildAttachmentPreview(context, widget.attachmentPath!),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Semantics(
                  button: true,
                  label: L10n.of(context).chatAddAttachmentSemantic,
                  child: SizedBox.square(
                    dimension: 34,
                    child: InkWell(
                      key: const ValueKey('add-attachment-button'),
                      onTap: widget.blocked || widget.busy
                          ? null
                          : widget.onPickAttachment,
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: AnimatedRotation(
                          turns: widget.isAttachmentMenuOpen ? 0.125 : 0.0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedAdd01,
                            size: 20,
                            color: (widget.blocked || widget.busy)
                                ? FluxColors.mutedOf(
                                    context,
                                  ).withValues(alpha: 0.35)
                                : (widget.isAttachmentMenuOpen
                                    ? FluxColors.inkOf(context)
                                    : FluxColors.mutedOf(context)),
                            strokeWidth: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Semantics(
                    label: L10n.of(context).chatMessageToFinnSemantic,
                    textField: true,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      inputFormatters: [LengthLimitingTextInputFormatter(4000)],
                      enabled: !widget.blocked,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => canSend ? widget.onSend() : null,
                      onTap: () => widget.onReturnToLatest?.call(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: FluxColors.inkOf(context),
                          ),
                      cursorColor: FluxColors.inkOf(context),
                      decoration: InputDecoration.collapsed(
                        hintText: widget.blocked
                            ? L10n.of(context).chatFinnTyping
                            : L10n.of(context).chatAskAnythingHint,
                        hintStyle: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: FluxColors.mutedOf(context)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (widget.voiceEnabled && !widget.busy && !widget.blocked)
                  Semantics(
                    button: true,
                    label: L10n.of(context).voiceMicSemantic,
                    child: SizedBox.square(
                      key: const ValueKey('mic-button-surface'),
                      dimension: 36,
                      child: InkWell(
                        onTap: widget.onMic,
                        customBorder: const CircleBorder(),
                        child: Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedMic01,
                            size: 20,
                            color: FluxColors.mutedOf(context),
                            strokeWidth: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.busy)
                  Semantics(
                    button: true,
                    label: L10n.of(context).chatStopGeneratingSemantic,
                    child: SizedBox.square(
                      key: const ValueKey('stop-button-surface'),
                      dimension: 36,
                      child: InkWell(
                        onTap: widget.onStop,
                        customBorder: const CircleBorder(),
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: FluxColors.isDark(context)
                                  ? Colors.white
                                  : Colors.black,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: SizedBox.square(
                                dimension: 12,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: FluxColors.isDark(context)
                                        ? Colors.black
                                        : Colors.white,
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Semantics(
                    button: true,
                    enabled: canSend,
                    label: L10n.of(context).chatSendMessageSemantic,
                    child: SizedBox.square(
                      key: const ValueKey('send-button-surface'),
                      dimension: 36,
                      child: InkWell(
                        onTap: canSend ? widget.onSend : null,
                        customBorder: const CircleBorder(),
                        child: Center(
                          child: FigmaSvg(
                            asset: canSend
                                ? FigmaAssets.activeSend
                                : FigmaAssets.send,
                            key: const ValueKey('send-button-icon'),
                            width: 30,
                            height: 30,
                            invertForDark: true,
                          ),
                        ),
                      ),
                    ),
                  ),
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
              borderRadius: BorderRadius.circular(13),
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
                    child: Icon(
                      Icons.broken_image_rounded,
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
                  child: Icon(
                    Icons.close_rounded,
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
        borderRadius: BorderRadius.circular(FluxRadius.sm),
        border: Border.all(
          color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
          width: 0.75,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color:
                  isDark ? const Color(0xFF3A3A3C) : FluxColors.bubbleUserLight,
              borderRadius: BorderRadius.circular(5),
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
            child: Icon(
              Icons.close_rounded,
              size: 16,
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
    required this.onSkills,
    required this.onSettings,
  });

  final VoidCallback onClose;
  final VoidCallback onNewConversation;
  final ValueChanged<String> onConversation;
  final List<FinnConversation> conversations;
  final String? activeConversationId;
  final VoidCallback onCreations;
  final VoidCallback onYou;
  final VoidCallback onSkills;
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
      color: FluxColors.canvasOf(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double sy = (constraints.maxHeight / 844).clamp(0.7, 1.3);
          final double headerTop = 71 * sy;
          final double headerHeight = 34;
          final double gap1 = 14 * sy;
          final double buttonsTop = headerTop + headerHeight + gap1;
          final double navSize = ((constraints.maxWidth - 80) / 3).clamp(
            52.0,
            62.0,
          );
          final double buttonsHeight = navSize + 20;
          final double buttonsBottom = buttonsTop + buttonsHeight;
          final double initialTitleTop = buttonsBottom + 14 * sy;
          final double pinnedTitleTop = headerTop;
          const double titleHeight = 24;
          final double historyTopAtRest = initialTitleTop + titleHeight + 12;
          final double titleTravelDistance = initialTitleTop - pinnedTitleTop;

          return Stack(
            children: [
              // 1. Scrolling Chat History List in Background
              Positioned.fill(
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const FluxBouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: historyTopAtRest,
                        bottom: 30 + safeBottom,
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
                          : SliverList.builder(
                              itemCount: widget.conversations.length,
                              itemBuilder: (context, index) {
                                final conversation =
                                    widget.conversations[index];
                                return _SidebarConversationTile(
                                  key: ValueKey(conversation.id),
                                  conversation: conversation,
                                  selected: conversation.id ==
                                      widget.activeConversationId,
                                  onTap: () =>
                                      widget.onConversation(conversation.id),
                                );
                              },
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
                      : (pinnedTitleTop + titleHeight + 14 * sy);

                  return Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: coverHeight,
                    child: IgnorePointer(
                      child: coverProgress <= 0
                          ? const SizedBox()
                          : ColoredBox(
                              color: FluxColors.canvasOf(
                                context,
                              ).withValues(alpha: .96),
                            ),
                    ),
                  );
                },
              ),

              // 3. Header (FinnAI title + actions) - fades out on scroll up as title replaces it, spring overscroll on pull down
              Positioned(
                left: 25,
                right: 20,
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
                      SizedBox(
                        width: 70,
                        height: 34,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            L10n.of(context).appBrandFinnAI,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w400),
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 78,
                        height: 34,
                        child: Stack(
                          children: [
                            // Underlying SVG showing both icons
                            const FigmaSvg(
                              asset: FigmaAssets.sidebarActions,
                              width: 78,
                              height: 34,
                            ),
                            // Left half → Settings
                            Positioned(
                              left: 0,
                              top: 0,
                              width: 39,
                              bottom: 0,
                              child: Tooltip(
                                message: L10n.of(context).settingsTitle,
                                child: InkWell(
                                  onTap: widget.onSettings,
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(17),
                                  ),
                                ),
                              ),
                            ),
                            // Right half → New Conversation
                            Positioned(
                              left: 39,
                              top: 0,
                              right: 0,
                              bottom: 0,
                              child: Tooltip(
                                message: L10n.of(context).chatNewChat,
                                child: InkWell(
                                  onTap: widget.onNewConversation,
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(17),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Local feature destinations.
              Positioned(
                left: 25,
                right: 25,
                top: buttonsTop,
                height: buttonsHeight,
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
                      _NavTile(
                        asset: FigmaAssets.sidebarCreations,
                        label: L10n.of(context).creationsTitle,
                        onTap: widget.onCreations,
                        size: navSize,
                      ),
                      _NavTile(
                        asset: FigmaAssets.sidebarYou,
                        label: L10n.of(context).youTitle,
                        onTap: widget.onYou,
                        size: navSize,
                      ),
                      _NavTile(
                        asset: FigmaAssets.sidebarSkills,
                        label: L10n.of(context).skillsTitle,
                        onTap: widget.onSkills,
                        size: navSize,
                      ),
                    ],
                  ),
                ),
              ),
              // 5. Chat History Title - lifts up on scroll all the way to headerTop replacing content beneath, spring overscroll on pull down
              Positioned(
                left: 25,
                right: 25,
                top: initialTitleTop,
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
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.asset,
    required this.label,
    required this.onTap,
    this.size = 62,
  });
  final String asset;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(FluxRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FluxRadius.sm),
          child: Container(
            width: size,
            height: size + 20,
            color: Colors.transparent,
            child: Column(
              children: [
                FigmaSvg(
                    asset: asset, width: size, height: size, isNavTile: true),
                const SizedBox(height: 5),
                SizedBox(
                  width: size,
                  height: 15,
                  child: Center(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: FluxColors.inkOf(context),
                          ),
                    ),
                  ),
                ),
              ],
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

  static final Map<String, GlobalKey> _tileKeys = {};

  GlobalKey _getTileKey() =>
      _tileKeys.putIfAbsent(conversation.id, () => GlobalKey());

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
            borderRadius: BorderRadius.circular(FluxRadius.sheet)),
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
            borderRadius: BorderRadius.circular(FluxRadius.sheet)),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: FluxSpringPressable(
        onTap: onTap,
        onLongPress: () => _showContextMenu(context),
        child: Container(
          key: key,
          decoration: BoxDecoration(
            color:
                selected ? FluxColors.surfaceOf(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(FluxRadius.sm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Text(
            conversation.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
