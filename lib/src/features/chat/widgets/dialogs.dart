part of '../home_shell.dart';

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
    required this.onCreate,
  });

  final VoidCallback onSelectCamera;
  final VoidCallback onSelectPhoto;
  final VoidCallback onSelectFile;

  /// Starts building something: `widget`, `app`, `presentation` or `flow`.
  final ValueChanged<String> onCreate;

  @override
  State<_IMessageAttachmentMenu> createState() =>
      _IMessageAttachmentMenuState();
}

typedef _MenuEntry = ({
  String title,
  String? subtitle,
  List<List<dynamic>> icon,
  VoidCallback onTap,
});

class _IMessageAttachmentMenuState extends State<_IMessageAttachmentMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
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
    final l10n = L10n.of(context);
    final create = <_MenuEntry>[
      // A widget is for a phone's home screen; a desktop has none to put it on.
      if (!isDesktop)
        (
          title: l10n.plusWidget,
          subtitle: l10n.plusWidgetSub,
          icon: FluxIcons.canvas,
          onTap: () => widget.onCreate('widget'),
        ),
      (
        title: l10n.plusMiniApp,
        subtitle: l10n.plusMiniAppSub,
        icon: FluxIcons.sourceCode,
        onTap: () => widget.onCreate('app'),
      ),
      (
        title: l10n.plusPresentation,
        subtitle: l10n.plusPresentationSub,
        icon: FluxIcons.education,
        onTap: () => widget.onCreate('presentation'),
      ),
      (
        title: l10n.plusFlow,
        subtitle: l10n.plusFlowSub,
        icon: FluxIcons.flows,
        onTap: () => widget.onCreate('flow'),
      ),
    ];
    final attach = <_MenuEntry>[
      (
        title: l10n.plusPhoto,
        subtitle: null,
        icon: HugeIcons.strokeRoundedImage01,
        onTap: widget.onSelectPhoto,
      ),
      // image_picker has no camera on a desktop; a webcam is not a photo
      // taken for a message, and the entry would only fail.
      if (!isDesktop)
        (
          title: l10n.attachmentCamera,
          subtitle: null,
          icon: HugeIcons.strokeRoundedCamera01,
          onTap: widget.onSelectCamera,
        ),
      (
        title: l10n.attachmentFiles,
        subtitle: null,
        icon: HugeIcons.strokeRoundedFolder01,
        onTap: widget.onSelectFile,
      ),
    ];
    var row = 0;
    Widget group(String heading, List<_MenuEntry> entries) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Text(
                heading,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: FluxColors.secondaryInkOf(context),
                    ),
              ),
            ),
            for (final entry in entries) _buildItemRow(row++, entry),
          ],
        );

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
      child: Container(
        width: 270,
        decoration: BoxDecoration(
          color: FluxColors.controlOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.sheet + 1),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            group(l10n.plusCreate, create),
            group(l10n.plusAddToChat, attach),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(int index, _MenuEntry item) {
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
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: FluxColors.tileOf(context),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: item.icon,
                      color: FluxColors.actionOf(context),
                      size: 20,
                      strokeWidth: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (item.subtitle != null)
                        Text(
                          item.subtitle!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: FluxColors.secondaryInkOf(context),
                                  ),
                        ),
                    ],
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
