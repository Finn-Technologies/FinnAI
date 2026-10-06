part of '../home_shell.dart';

/// The chat's "+" sheet: what you can make (widget, mini app, presentation,
/// flow) as a grid of cards, and what you can add to the message (photo,
/// camera, file). Rises from the bottom over a light scrim, the way the
/// design shows it; a tap outside or a drag down puts it away.
class _PlusSheet extends StatefulWidget {
  const _PlusSheet({
    required this.open,
    required this.onClose,
    required this.onSelectCamera,
    required this.onSelectPhoto,
    required this.onSelectFile,
    required this.onCreate,
    required this.bottomInset,
    required this.maxWidth,
  });

  final bool open;
  final VoidCallback onClose;
  final VoidCallback onSelectCamera;
  final VoidCallback onSelectPhoto;
  final VoidCallback onSelectFile;

  /// Starts building something: `widget`, `app`, `presentation` or `flow`.
  final ValueChanged<String> onCreate;
  final double bottomInset;
  final double maxWidth;

  @override
  State<_PlusSheet> createState() => _PlusSheetState();
}

typedef _PlusEntry = ({
  String title,
  String? subtitle,
  IconData icon,
  VoidCallback onTap,
});

class _PlusSheetState extends State<_PlusSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: FluxMotion.emphasisDuration,
    reverseDuration: const Duration(milliseconds: 220),
    value: widget.open ? 1 : 0,
  );

  /// How far a drag has pulled the sheet down, in logical pixels.
  double _drag = 0;

  @override
  void didUpdateWidget(covariant _PlusSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open == oldWidget.open) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.open ? 1 : 0;
      return;
    }
    if (widget.open) {
      _drag = 0;
      HapticFeedback.selectionClick();
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(VoidCallback action) {
    HapticFeedback.lightImpact();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final create = <_PlusEntry>[
      // A widget is for a phone's home screen; a desktop has none to put it on.
      if (!isDesktop)
        (
          title: l10n.plusWidget,
          subtitle: l10n.plusWidgetSub,
          icon: FluxIcons.widget,
          onTap: () => widget.onCreate('widget'),
        ),
      (
        title: l10n.plusMiniApp,
        subtitle: l10n.plusMiniAppSub,
        icon: FluxIcons.miniApp,
        onTap: () => widget.onCreate('app'),
      ),
      (
        title: l10n.plusPresentation,
        subtitle: l10n.plusPresentationSub,
        icon: FluxIcons.presentation,
        onTap: () => widget.onCreate('presentation'),
      ),
      (
        title: l10n.plusFlow,
        subtitle: l10n.plusFlowSub,
        icon: FluxIcons.flows,
        onTap: () => widget.onCreate('flow'),
      ),
    ];
    final attach = <_PlusEntry>[
      (
        title: l10n.plusPhoto,
        subtitle: null,
        icon: FluxIcons.photo,
        onTap: widget.onSelectPhoto,
      ),
      // image_picker has no camera on a desktop; a webcam is not a photo
      // taken for a message, and the entry would only fail.
      if (!isDesktop)
        (
          title: l10n.attachmentCamera,
          subtitle: null,
          icon: FluxIcons.camera,
          onTap: widget.onSelectCamera,
        ),
      (
        title: l10n.attachmentFiles,
        subtitle: null,
        icon: FluxIcons.file,
        onTap: widget.onSelectFile,
      ),
    ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        if (t == 0 && !widget.open) return const SizedBox.shrink();
        // Rises on a soft spring, falls on a plain ease.
        final rise = _controller.status == AnimationStatus.reverse
            ? Curves.easeInCubic.transform(t)
            : const ElasticOutCurve(.85).transform(t).clamp(0.0, 1.06);
        var index = 0;
        Widget card(_PlusEntry entry) {
          final i = index++;
          // Each card lands a beat after the one before it.
          final start = (i * .055).clamp(0.0, .5);
          final local = ((t - start) / .5).clamp(0.0, 1.0);
          final curve = Curves.easeOutCubic.transform(local);
          return Opacity(
            opacity: curve,
            child: Transform.translate(
              offset: Offset(0, 14 * (1 - curve)),
              child: _PlusCard(
                key: ValueKey('plus-${entry.title}'),
                entry: entry,
                onTap: () => _pick(entry.onTap),
              ),
            ),
          );
        }

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('plus-scrim'),
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: ColoredBox(
                  color: Colors.black.withValues(
                    alpha: (FluxColors.isDark(context) ? .35 : .1) *
                        Curves.easeOut.transform(t),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: widget.maxWidth),
                  child: FractionalTranslation(
                    translation: Offset(0, 1 - rise),
                    child: Transform.translate(
                      offset: Offset(0, _drag),
                      child: GestureDetector(
                        onVerticalDragUpdate: (d) => setState(
                            () => _drag = math.max(0, _drag + d.delta.dy)),
                        onVerticalDragEnd: (d) {
                          if (_drag > 80 || (d.primaryVelocity ?? 0) > 500) {
                            widget.onClose();
                          } else {
                            setState(() => _drag = 0);
                          }
                        },
                        child: _sheet(context, [
                          _heading(l10n.plusCreate),
                          _grid([
                            for (final entry in create) card(entry),
                          ], columns: 2),
                          _heading(l10n.plusAddToChat),
                          _grid([
                            for (final entry in attach) card(entry),
                          ], columns: 3),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sheet(BuildContext context, List<Widget> children) => Material(
        key: const ValueKey('plus-sheet'),
        color: FluxColors.tileOf(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(25, 12, 25, 24 + widget.bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FluxColors.lineOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ...children,
            ],
          ),
        ),
      );

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'InstrumentSans',
            fontSize: 18,
            height: 22 / 18,
          ),
        ),
      );

  Widget _grid(List<Widget> cards, {required int columns}) {
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += columns) {
      final slice = cards.sublist(i, math.min(i + columns, cards.length));
      rows.add(Row(
        children: [
          for (var j = 0; j < columns; j++) ...[
            if (j > 0) const SizedBox(width: 10),
            Expanded(
                child: j < slice.length ? slice[j] : const SizedBox.shrink()),
          ],
        ],
      ));
    }
    return Column(
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          row,
        ],
      ],
    );
  }
}

/// One option: a white card with its icon at the top and its name (and what
/// it is for) at the bottom.
class _PlusCard extends StatelessWidget {
  const _PlusCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final _PlusEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = entry.subtitle;
    return Semantics(
      button: true,
      label: subtitle == null ? entry.title : '${entry.title}. $subtitle',
      excludeSemantics: true,
      child: FluxPressScale(
        child: Material(
          color: FluxColors.controlOf(context),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 110,
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FluxIcon(
                      icon: entry.icon,
                      size: 26,
                      color: FluxColors.actionOf(context),
                    ),
                    const Spacer(),
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'InstrumentSans',
                        fontSize: 14,
                        height: 17 / 14,
                        color: FluxColors.inkOf(context),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'InstrumentSans',
                          fontSize: 13,
                          height: 16 / 13,
                          color: FluxColors.secondaryInkOf(context),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
