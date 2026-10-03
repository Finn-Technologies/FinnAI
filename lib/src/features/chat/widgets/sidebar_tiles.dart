part of '../home_shell.dart';

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

  void _showContextMenu(BuildContext context) =>
      showChatOptions(context, conversation);

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
