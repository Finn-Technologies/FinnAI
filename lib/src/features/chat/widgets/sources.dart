part of '../home_shell.dart';

class _ArticlePhotoSlideshow extends StatefulWidget {
  const _ArticlePhotoSlideshow({required this.imageUrls});

  final List<String> imageUrls;

  @override
  State<_ArticlePhotoSlideshow> createState() => _ArticlePhotoSlideshowState();
}

class _ArticlePhotoSlideshowState extends State<_ArticlePhotoSlideshow> {
  late final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    final count = widget.imageUrls.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(FluxRadius.md),
      child: Container(
        height: 200,
        width: double.infinity,
        color: isDark
            ? FluxColors.bubbleAssistantDark
            : FluxColors.bubbleUserLight,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: count,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, index) {
                final url = widget.imageUrls[index];
                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => Center(
                    child: FluxIcon(
                      icon: FluxIcons.image,
                      size: 28,
                      color: FluxColors.mutedOf(context),
                    ),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                          color: FluxColors.mutedOf(context),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            if (count > 1)
              Positioned(
                bottom: 10,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(FluxRadius.pill),
                  ),
                  child: Text(
                    '${_currentPage + 1}/$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Collapsible sources list shown under a web-grounded answer: the favicon of
/// the first page, its host, and a chevron that rotates down to reveal every
/// source the turn used. It shares [FluxDisclosure] with the browser-steps
/// indicator so both read as the same affordance. The revealed list has no card
/// background — it reads as a plain list — and its growth is reported per frame
/// so the chat can keep the answer above anchored while only the content below
/// slides.
class _SourceList extends StatelessWidget {
  const _SourceList({required this.sources, required this.onHeightDelta});

  final List<WebSource> sources;

  /// Per-frame growth (or shrink) of the expanded list in pixels.
  final ValueChanged<double> onHeightDelta;

  Future<void> _open(BuildContext context, WebSource source) async {
    final uri = source.url;
    if (uri.scheme != 'http' && uri.scheme != 'https') return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// The source's excerpt, or empty when the search service only had its
  /// "no excerpt" placeholder to offer.
  static String _snippetOf(WebSource source) {
    final snippet = source.snippet.replaceAll(RegExp(r'\s+'), ' ').trim();
    return snippet == 'No excerpt available.' ? '' : snippet;
  }

  @override
  Widget build(BuildContext context) {
    final firstHost = sources.isNotEmpty
        ? sources.first.url.host.replaceFirst(RegExp(r'^www\.'), '')
        : L10n.of(context).chatSources;
    final extraCount = sources.length - 1;

    return FluxDisclosure(
      leading: _SourceFavicon(source: sources.first, size: 16),
      label: firstHost,
      trailing: extraCount > 0 ? '+$extraCount' : null,
      expandLabel: L10n.of(context).chatShowSources,
      collapseLabel: L10n.of(context).chatHideSources,
      onHeightDelta: onHeightDelta,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final source in sources)
            FluxDisclosureRow(
              leading: _SourceFavicon(source: source, size: 18),
              title: source.title.isEmpty ? source.url.host : source.title,
              subtitle: _snippetOf(source),
              onTap: () => _open(context, source),
            ),
        ],
      ),
    );
  }
}

/// Deterministic stand-in for the website's favicon: a circle tinted from the
/// hostname with the domain's initial letter, so sources are easy to tell
/// apart without fetching anything over the network.
class _SourceFavicon extends StatelessWidget {
  const _SourceFavicon({required this.source, this.size = 18});

  final WebSource source;
  final double size;

  static const List<Color> _palette = [
    Color(0xFF4A7CF3),
    Color(0xFFE05D3B),
    Color(0xFF2FA36B),
    Color(0xFF9B59B6),
    Color(0xFFE2A12E),
    Color(0xFF3BA7C9),
    Color(0xFFE05C8A),
    Color(0xFF5F6B7A),
  ];

  @override
  Widget build(BuildContext context) {
    final host = source.url.host.replaceFirst('www.', '');
    final letter = host.isEmpty ? '?' : host[0].toUpperCase();
    final color = _palette[host.hashCode.abs() % _palette.length];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.55,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

/// The shared slide-and-fade transition for full-screen sub-pages.
///
/// Public so creations, decks and mini-app hosts push with the same motion as
/// the sidebar destinations rather than each defining their own.
class FinnPageRoute<T> extends PageRouteBuilder<T> {
  FinnPageRoute({required Widget child})
      : super(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, page) {
            if (MediaQuery.disableAnimationsOf(context)) return page;
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubicEmphasized,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(.08, 0),
                  end: Offset.zero,
                ).animate(curved),
                // A hair of scale gives the incoming page depth, so it reads
                // as arriving from behind the current one instead of sliding
                // flat over it. Anchored to the edge it slides from.
                child: ScaleTransition(
                  scale: Tween<double>(begin: .985, end: 1).animate(curved),
                  alignment: Alignment.centerRight,
                  child: page,
                ),
              ),
            );
          },
        );
}
