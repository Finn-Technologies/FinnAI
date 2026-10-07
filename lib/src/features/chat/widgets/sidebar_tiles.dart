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

  /// What the card says under its title: the start of Finn's first answer,
  /// with markdown marks taken out, or the first question when there is no
  /// answer yet.
  static String previewOf(FinnConversation conversation) {
    final messages = conversation.messages;
    final answer = messages
        .where((m) => m.role == ConversationRole.assistant && m.text.isNotEmpty)
        .firstOrNull;
    final source = answer ??
        messages
            .where((m) => m.role == ConversationRole.user && m.text.isNotEmpty)
            .firstOrNull;
    if (source == null) return '';
    final plain = source.text
        // A model's private reasoning, and any stray markup, is not preview.
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
        .replaceAll(RegExp(r'</?\s*think\b[^>\s]*>?'), '')
        .replaceAll(RegExp(r'</?[a-zA-Z][a-zA-Z0-9]*\s*/?>'), '')
        .replaceAll(RegExp(r'[#*_`>\[\]]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return plain.length > 160 ? '${plain.substring(0, 160)}…' : plain;
  }

  /// The photo a chat started from, which makes its card a picture card.
  static String? imageOf(FinnConversation conversation) {
    for (final m in conversation.messages) {
      final path = m.imagePath;
      if (path != null && path.isNotEmpty && File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  /// A height the masonry can plan with before laying anything out.
  static double estimatedHeight(FinnConversation conversation) {
    if (imageOf(conversation) != null) return 190;
    final preview = previewOf(conversation);
    final lines =
        preview.isEmpty ? 0 : (preview.length / 22).ceil().clamp(1, 4);
    final titleLines = (conversation.title.length / 16).ceil().clamp(1, 3);
    return 46 + 20.0 * titleLines + 17.0 * lines;
  }

  @override
  Widget build(BuildContext context) {
    final selected = this.selected;
    final image = imageOf(conversation);
    final preview = previewOf(conversation);
    final when = formatConversationTimestamp(context, conversation.updatedAt);
    final ink =
        selected ? FluxColors.actionInkOf(context) : FluxColors.inkOf(context);
    final soft = selected
        ? FluxColors.actionInkOf(context).withValues(alpha: .7)
        : FluxColors.timestampOf(context);
    // Like the Siri app's history: a card per conversation with when it was,
    // a bold title and how it went; a chat with a photo shows the photo.
    return Semantics(
      button: true,
      onTap: onTap,
      selected: selected,
      label: '${conversation.title}. $when',
      excludeSemantics: true,
      child: FluxPressScale(
        scale: .96,
        child: Material(
          color: selected
              ? FluxColors.actionOf(context)
              : FluxColors.tileOf(context),
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: _getTileKey(),
            onTap: onTap,
            onLongPress: () => _showContextMenu(context),
            child: image != null
                ? SizedBox(
                    height: 190,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(image),
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                          excludeFromSemantics: true,
                          errorBuilder: (_, __, ___) =>
                              ColoredBox(color: FluxColors.tileOf(context)),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.center,
                              colors: [Color(0x99000000), Color(0x00000000)],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                when,
                                style: const TextStyle(
                                  fontFamily: 'Geist',
                                  fontSize: 12,
                                  color: Color(0xCCFFFFFF),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                conversation.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Geist',
                                  fontSize: 16,
                                  height: 1.15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          when,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 12,
                            color: soft,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          conversation.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 16,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                            color: ink,
                          ),
                        ),
                        if (preview.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            preview,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 13,
                              height: 1.3,
                              color: soft,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
