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
    final selected = this.selected;
    return FinnSidebarHistoryTile(
      title: conversation.title,
      selected: selected,
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
      badgeKey: _getTileKey(),
      badge: Text(
        formatConversationTimestamp(context, conversation.updatedAt),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'InstrumentSans',
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w400,
          color: FinnSidebarHistoryTile.badgeInk(context, selected),
        ),
      ),
    );
  }
}
