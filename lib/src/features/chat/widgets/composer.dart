part of '../home_shell.dart';

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
                    child: FigmaSvg(
                      asset: FigmaAssets.composerVoice,
                      width: 25,
                      height: 25,
                      color: FluxColors.actionInkOf(context),
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
        gradient: listening ? FluxColors.voiceGradientOf(context) : null,
        borderRadius: BorderRadius.circular(
          hasAttachment ? FluxRadius.sheet : FluxRadius.pill,
        ),
        boxShadow: listening
            ? null
            : [
                BoxShadow(
                  color: FluxColors.elevationOf(context)
                      .withValues(alpha: isDark ? 0.14 : 0.08),
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
              boxShadow: FluxColors.elevationShadow(
                context,
                alpha: .08,
                blur: 8,
                offset: const Offset(0, 2),
              ),
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
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A000000),
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
        color: FluxColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(FluxRadius.pill),
        boxShadow: FluxColors.elevationShadow(
          context,
          alpha: .04,
          blur: 8,
          offset: const Offset(0, 2),
        ),
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
                color: FluxColors.inkOf(context),
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
