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
          FinnRetryButton(
            label: L10n.of(context).commonRetry,
            onPressed: retry,
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
