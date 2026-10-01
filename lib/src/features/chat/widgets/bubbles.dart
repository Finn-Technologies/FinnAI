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
            ? FluxColors.bubbleUserOf(context)
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
            ? FluxColors.bubbleUserOf(context)
            : FluxColors.cardOf(context),
        borderRadius: borderRadius,
        boxShadow: widget.user
            ? null
            : FluxColors.elevationShadow(
                context,
                alpha: .04,
                blur: isDark ? 12 : 9,
                offset: const Offset(0, 3),
              ),
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
