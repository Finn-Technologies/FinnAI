part of '../home_shell.dart';

/// The attachment chip inside the composer's field, apart from the composer so
/// that file stays a size a person can hold in their head.
extension _ComposerAttachment on _ChatComposerState {
  Widget _buildAttachmentPreview(BuildContext context, String path) {
    final isDark = FluxColors.isDark(context);
    final file = File(path);
    final fileName = path.split(Platform.pathSeparator).last;
    final isImg = _isImage(path);

    bool fileExists = false;
    try {
      fileExists = file.existsSync();
    } catch (_) {
      fileExists = false;
    }
    if (isImg && fileExists) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FluxRadius.sm),
              border: Border.all(
                color:
                    isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                width: 1,
              ),
              boxShadow: FluxColors.elevationShadow(
                context,
                alpha: .08,
                blur: 8,
                offset: const Offset(0, 2),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(FluxRadius.sm),
              child: Image.file(
                file,
                width: 54,
                height: 54,
                cacheWidth: 400,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : FluxColors.bubbleUserLight,
                  child: Center(
                    child: FluxIcon(
                      icon: FluxIcons.brokenImage,
                      size: 20,
                      color: FluxColors.mutedOf(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: widget.onRemoveAttachment,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF48484A)
                      : const Color(0xFF3A3A3C),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF18181B) : Colors.white,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: const Center(
                  child: FluxIcon(
                    icon: FluxIcons.close,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Document or non-image file
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toUpperCase()
        : 'FILE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FluxColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(FluxRadius.pill),
        boxShadow: FluxColors.elevationShadow(
          context,
          alpha: .04,
          blur: 8,
          offset: const Offset(0, 2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color:
                  isDark ? const Color(0xFF3A3A3C) : FluxColors.bubbleUserLight,
              borderRadius: BorderRadius.circular(FluxRadius.pill),
            ),
            child: Text(
              ext.length > 4 ? ext.substring(0, 4) : ext,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: FluxColors.inkOf(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onRemoveAttachment,
            child: FluxIcon(
              icon: FluxIcons.close,
              size: 14,
              color: FluxColors.mutedOf(context),
            ),
          ),
        ],
      ),
    );
  }

  bool _isImage(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.gif');
  }
}
