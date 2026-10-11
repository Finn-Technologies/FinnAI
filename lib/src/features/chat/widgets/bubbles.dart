part of '../home_shell.dart';

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
        final style = FinnBubbleBox.textStyle(context, user: user);
        final hasImage = imagePath != null && imagePath!.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasImage) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(FluxRadius.sm),
                  child: _AttachmentPreview(
                    path: imagePath!,
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

/// The image a message attached: the photo when it decodes, a named chip when
/// it does not.
///
/// Both faces are the same size. They used not to be — the error fallback was
/// 160px wide beside a 200px photo — so a bubble whose image failed to decode
/// snapped to a different width than the identical message next to it.
///
/// It also decides whether the file exists *once*, in `initState`, rather than
/// calling `File.existsSync()` on the UI thread for every rendered bubble on
/// every build: that synchronous `stat` is what made the keyboard dismiss
/// before a new message appeared in a long conversation.
class _AttachmentPreview extends StatefulWidget {
  const _AttachmentPreview({required this.path});

  final String path;

  @override
  State<_AttachmentPreview> createState() => _AttachmentPreviewState();
}

class _AttachmentPreviewState extends State<_AttachmentPreview> {
  static const double _width = 200;
  static const double _height = 140;

  late bool _exists = _probe(widget.path);

  static bool _probe(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  void didUpdateWidget(covariant _AttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path == widget.path) return;
    final exists = _probe(widget.path);
    if (exists != _exists) setState(() => _exists = exists);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.path.split(Platform.pathSeparator).last;
    Widget chip() => Container(
          width: _width,
          height: _height,
          padding: const EdgeInsets.all(8),
          color: FluxColors.cardOf(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FluxIcon(icon: FluxIcons.image, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
    if (!_exists) return chip();
    return Image.file(
      File(widget.path),
      width: _width,
      height: _height,
      cacheWidth: 400,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => chip(),
    );
  }
}

/// A gentle entrance for a single element: fades in while rising a few pixels.
///
/// Where [FluxEntrance] travels a fraction of the viewport — right for a message
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
    duration: FluxMotion.emphasisDuration,
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
    final borderRadius = FinnBubbleBox.radiusFor(user: widget.user);
    final preview = FinnBubbleBox(
      user: widget.user,
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
        icon: FluxIcons.selectText,
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
    // A user message is a solid pill of its own; the assistant keeps the
    // softly-cornered surface so an error or notice still reads as a card.
    final bubble = FinnBubbleBox(
      key: _bubbleKey,
      user: widget.user,
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
    duration: FluxMotion.presencePulse,
  );

  late String _text = widget.generation.activeJob?.responseText ?? widget.text;
  late int _activityCount = widget.generation.toolActivities.length;

  @override
  void initState() {
    super.initState();
    // The pulse is only drawn by the empty-text "Finn is generating" row; once
    // tokens arrive it would tick vsync forever for nothing.
    if (_text.isEmpty && _activityCount == 0) _pulse.repeat();
    widget.generation.addListener(_onGenerationChanged);
  }

  void _setPulse(bool visible) {
    if (visible) {
      if (!_pulse.isAnimating) _pulse.repeat();
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

  // "Generating" hands over to the first words with a crossfade, not a
  // cut: the orb and its line fade as the text fades up in their place.
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topLeft,
          children: [...previous, if (current != null) current],
        ),
        child: KeyedSubtree(
          key: ValueKey(_text.isEmpty),
          child: _content(context),
        ),
      );

  Widget _content(BuildContext context) {
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
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FinnThinkingOrb(t: _pulse.value),
                const SizedBox(width: 10),
                FinnShimmerText(
                  text: L10n.of(context).chatFinnGenerating,
                  t: _pulse.value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 14,
                        letterSpacing: -0.1,
                      ),
                ),
              ],
            ),
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
        // The line being written comes up out of a soft fade, so text
        // arrives rather than pops in; finished lines above are untouched.
        Semantics(
          liveRegion: true,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              final edge = bounds.height <= 0
                  ? 1.0
                  : (1 - 26 / bounds.height).clamp(0.0, 1.0);
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [Colors.white, Colors.white, Color(0x59FFFFFF)],
                stops: [0, edge, 1],
              ).createShader(bounds);
            },
            child: SafeMarkdownText(text: fullText),
          ),
        ),
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
