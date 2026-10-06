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
