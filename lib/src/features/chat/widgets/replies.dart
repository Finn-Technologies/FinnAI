part of '../home_shell.dart';

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
    this.card,
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

  /// What this reply made (a creation or a flow), shown under the text.
  final Widget? card;
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
        if (card != null) card!,
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

  Future<void> _share() async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/finnai-reply.txt');
    await file.writeAsString(widget.text, flush: true);
    await shareLocalFile(file.path, 'text/plain', 'FinnAI');
  }

  void _openOverflow() {
    final regenerate = widget.onRegenerate;
    final l10n = L10n.of(context);
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
          icon: FluxIcons.copy,
          label: l10n.chatCopy,
          onTap: _copy,
        ),
        FluxContextMenuItem(
          icon: FluxIcons.volume,
          label: l10n.chatReadAloud,
          onTap: () => unawaited(ReadAloud.instance.speak(widget.text)),
        ),
        if (regenerate != null)
          FluxContextMenuItem(
            icon: FluxIcons.refresh,
            label: l10n.chatRegenerate,
            onTap: regenerate,
          ),
        FluxContextMenuItem(
          icon: FluxIcons.you,
          label: l10n.chatRememberInYou,
          onTap: () => Navigator.of(context).push(
            FinnPageRoute<void>(
              child: YouAddPage(initialText: _firstSentences(widget.text)),
            ),
          ),
        ),
        FluxContextMenuItem(
          icon: FluxIcons.arrowUp01,
          label: l10n.chatShare,
          onTap: () => unawaited(_share()),
        ),
      ],
    );
  }

  /// A short, memory-sized excerpt of a reply: its first two sentences.
  static String _firstSentences(String text) {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final sentences = RegExp(r'[^.!?]+[.!?]?').allMatches(flat).take(2);
    final joined = sentences.map((m) => m.group(0)!.trim()).join(' ');
    return joined.length > 280 ? joined.substring(0, 280) : joined;
  }

  @override
  Widget build(BuildContext context) {
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
