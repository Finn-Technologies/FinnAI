part of '../home_shell.dart';

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
