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
    this.onVoiceTap,
    this.voice,
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

  /// What a tap on the live pill or its mic does: finish what was said, or cut
  /// Finn off and talk.
  final VoidCallback? onVoiceTap;

  /// The live conversation the pill shows. Null outside voice mode.
  final VoiceChatController? voice;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer>
    with SingleTickerProviderStateMixin {
  late bool _hasText;

  /// 0 = chatting, 1 = a live voice conversation: the one motion the whole
  /// bottom row follows (see [VoiceMorphBar]). Slower going in than coming
  /// back, because arriving is the moment worth watching.
  late final AnimationController _morph;
  late final Animation<double> _progress;

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.voiceListening == oldWidget.voiceListening) return;
    final target = widget.voiceListening ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _morph.value = target;
    } else {
      _morph.animateTo(
        target,
        curve: Curves.linear,
        duration:
            widget.voiceListening ? _morph.duration : _morph.reverseDuration,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _morph = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
      reverseDuration: const Duration(milliseconds: 540),
      value: widget.voiceListening ? 1 : 0,
    );
    // Not the "emphasized" curve: it spends nearly all of its change in the
    // first third, and the whole motion is over before it can be seen.
    _progress = CurvedAnimation(parent: _morph, curve: Curves.easeInOutCubic);
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
    _morph.dispose();
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
    final isDark = FluxColors.isDark(context);
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

    // Left: attachments, turning into the design's cancel cross as voice
    // mode arrives. The turn belongs to the same motion as the rest of the
    // row, with a little overshoot so it lands rather than stops.
    Widget leadingFor(double c) => circle(
          key: const ValueKey('add-attachment-button'),
          color: FluxColors.controlOf(context),
          label: c > .5
              ? l10n.voiceCancelSemantic
              : widget.pickAttachmentSemanticLabel ??
                  l10n.chatAddAttachmentSemantic,
          onTap: c > .5
              ? widget.onVoiceToggle
              : (widget.blocked || widget.busy
                  ? null
                  : widget.onPickAttachment),
          child: Transform.rotate(
            angle: 2 *
                math.pi *
                .125 *
                Interval(0, .85, curve: Curves.easeOutBack).transform(c),
            child: AnimatedRotation(
              turns: widget.isAttachmentMenuOpen ? .125 : 0.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: const FigmaSvg(
                asset: FigmaAssets.composerAdd,
                width: 25,
                height: 25,
              ),
            ),
          ),
        );

    // Right, in chat: stop while generating, send once there is something to
    // send, and the design's voice button otherwise. The key is what lets the
    // swap between them animate instead of blinking.
    final chatMode = widget.busy
        ? 'stop'
        : hasDraft
            ? 'send'
            : 'mic';
    final chatControl = widget.busy
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
    final trailing = _ControlSwap(swapKey: chatMode, child: chatControl);
    // Right, in a live conversation: the light microphone.
    final voiceTrailing = circle(
      key: const ValueKey('voice-toggle-surface'),
      color: FluxColors.controlOf(context),
      label: l10n.voiceMicSemantic,
      onTap: widget.onVoiceTap ?? widget.onVoiceToggle,
      child: const FigmaSvg(asset: FigmaAssets.voiceMic, width: 25, height: 25),
    );

    // What is inside the message field: an attachment, then the text itself.
    final fieldColumn = Column(
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
                        onSubmitted: (_) => canSend ? widget.onSend() : null,
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
    );
    const fieldInset = EdgeInsets.fromLTRB(17, 1, 4, 1);

    // The middle pill outside live voice: just the field.
    final pill = AnimatedContainer(
      key: const ValueKey('chat-composer-motion'),
      duration:
          reducedMotion ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: FluxColors.controlOf(context),
        borderRadius: BorderRadius.circular(
          hasAttachment ? FluxRadius.sheet : FluxRadius.pill,
        ),
        boxShadow: [
          BoxShadow(
            color: FluxColors.elevationOf(context)
                .withValues(alpha: isDark ? 0.14 : 0.08),
            blurRadius: isDark ? 20 : 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      constraints: const BoxConstraints(minHeight: 50, maxHeight: 220),
      padding: fieldInset,
      child: fieldColumn,
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
        child: widget.voice == null
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  leadingFor(0),
                  const SizedBox(width: 20),
                  Expanded(child: pill),
                  const SizedBox(width: 20),
                  trailing,
                ],
              )
            : VoiceMorphBar(
                progress: _progress,
                voice: widget.voice!,
                leading: leadingFor,
                chatTrailing: trailing,
                voiceTrailing: voiceTrailing,
                field: Padding(padding: fieldInset, child: fieldColumn),
                fieldRadius: hasAttachment ? FluxRadius.sheet : FluxRadius.pill,
                onVoiceTap: widget.onVoiceTap ?? widget.onVoiceToggle,
              ),
      ),
    );
  }
}
