import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads/banner_ad_widget.dart';
import '../inference/qwen_inference.dart';
import '../theme/flux_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/finn_page_header.dart';
import '../widgets/flux_controls.dart';
import 'creation_generator.dart';
import 'creation_model.dart';
import 'creation_store.dart';
import 'creations_controller.dart';

class CreationsPage extends StatefulWidget {
  const CreationsPage({super.key, this.controller});

  /// Injectable for tests and alternate local generation/storage backends.
  final CreationsController? controller;

  @override
  State<CreationsPage> createState() => _CreationsPageState();
}

class _CreationsPageState extends State<CreationsPage> {
  late final CreationsController _controller;
  late final bool _ownsController;
  final _inference = QwenInference.instance;
  final _promptController = TextEditingController();
  final _focusNode = FocusNode();
  final ValueNotifier<double> _headerOffset = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        CreationsController(CreationStore(), QwenCreationGenerator());
    _controller.addListener(_changed);
    _inference.addListener(_changed);
    _controller.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _inference.removeListener(_changed);
    if (_ownsController) {
      if (_controller.generating) {
        unawaited(_controller.cancelGeneration());
      }
      _controller.dispose();
    }
    _promptController.dispose();
    _focusNode.dispose();
    _headerOffset.dispose();
    super.dispose();
  }

  Future<void> _chooseKind() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty || _controller.generating) return;
    _focusNode.unfocus();
    final kind = await showModalBottomSheet<CreationKind>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _KindPicker(),
    );
    if (kind == null || !mounted) return;
    final creation = await _controller.create(prompt, kind);
    if (!mounted) return;
    if (creation != null) {
      _promptController.clear();
      await _showCreation(creation);
    }
  }

  Future<void> _close() async {
    if (!_controller.generating) {
      Navigator.of(context).pop();
      return;
    }
    final stop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Stop this creation?'),
        content: const Text(
          'The unfinished result will be discarded. Your prompt will stay here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep creating'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (stop != true) return;
    await _controller.cancelGeneration();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showCreation(FinnCreation creation) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _CreationDetail(
          creation: creation,
          onDelete: () async {
            Navigator.pop(context);
            await _controller.delete(creation);
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !_controller.generating,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: AmbientBackground(
          intensity: .6,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final metrics = FinnPageHeaderMetrics.forHeight(
                constraints.maxHeight,
              );
              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: metrics.contentTop + 5,
                    bottom: 0,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Turn an idea into a structured plan, entirely on device.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: FluxColors.mutedOf(context),
                                      height: 1.35,
                                    ),
                              ),
                              const SizedBox(height: 18),
                              _Filters(
                                selected: _controller.filter,
                                onSelected: _controller.setFilter,
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                child: _controller.error == null
                                    ? const SizedBox(width: double.infinity)
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: _ErrorNotice(
                                          message: _controller.error!,
                                          onDismiss: _controller.clearError,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(child: _content()),
                        BannerAdWidget(
                          key: const Key('creations-idle-ad'),
                          enabled:
                              !_controller.loading &&
                              !_controller.generating &&
                              _controller.creations.isNotEmpty &&
                              QwenInference.instance.phase !=
                                  InferencePhase.generating &&
                              bottomInset == 0,
                          margin: const EdgeInsets.only(top: 2, bottom: 4),
                        ),
                        AnimatedPadding(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.fromLTRB(
                            20,
                            10,
                            20,
                            bottomInset > 0
                                ? 12
                                : MediaQuery.paddingOf(context).bottom + 20,
                          ),
                          child: _CreationComposer(
                            controller: _promptController,
                            focusNode: _focusNode,
                            busy: _controller.loading || _controller.generating,
                            onSubmit: _chooseKind,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: FinnPageHeader(
                      title: 'Creations',
                      onBack: _close,
                      metrics: metrics,
                      scrollOffset: _headerOffset,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_controller.loading) {
      return const Center(child: _QuietLoader(label: 'Opening creations'));
    }
    final visible = _controller.visible;
    if (visible.isEmpty) {
      return _EmptyState(filtered: _controller.filter != null);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 460
            ? 2
            : 1;
        return GridView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 164,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final creation = visible[index];
            return _CreationCard(
              key: ValueKey(creation.id),
              creation: creation,
              onTap: () => _showCreation(creation),
            );
          },
        );
      },
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onSelected});
  final CreationKind? selected;
  final ValueChanged<CreationKind?> onSelected;

  @override
  Widget build(BuildContext context) {
    final values = <CreationKind?>[null, ...CreationKind.values];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final value = values[index];
          final active = selected == value;
          return Semantics(
            button: true,
            selected: active,
            label: '${value?.label ?? 'All'} creations',
            child: Material(
              color: active
                  ? FluxColors.inkOf(context)
                  : FluxColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(99),
              child: InkWell(
                onTap: () => onSelected(value),
                borderRadius: BorderRadius.circular(99),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: Text(
                      value?.label ?? 'All',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: active
                            ? FluxColors.canvasOf(context)
                            : FluxColors.inkOf(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered});
  final bool filtered;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 42),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: FluxColors.surfaceOf(context),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: FluxIcon(icon: FluxIcons.canvas, size: 27),
            ),
          ),
          const SizedBox(height: 17),
          Text(
            filtered ? 'Nothing here yet' : 'Make something useful',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            filtered
                ? 'Try another category or create a new one.'
                : 'Describe an app, widget or presentation below. Finn will shape it into a practical plan.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: FluxColors.mutedOf(context),
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CreationCard extends StatelessWidget {
  const _CreationCard({super.key, required this.creation, required this.onTap});
  final FinnCreation creation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = switch (creation.kind) {
      CreationKind.app => const Color(0xFFBDECCB),
      CreationKind.widget => const Color(0xFFB9DFF1),
      CreationKind.presentation => const Color(0xFFE5D4F5),
    };
    return Material(
      color: FluxColors.cardOf(context),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: FluxIcon(
                        icon: _iconFor(creation.kind),
                        color: FluxColors.ink,
                        size: 19,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    creation.kind.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: FluxColors.mutedOf(context),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                creation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 5),
              Text(
                creation.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: FluxColors.mutedOf(context),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreationComposer extends StatefulWidget {
  const _CreationComposer({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  State<_CreationComposer> createState() => _CreationComposerState();
}

class _CreationComposerState extends State<_CreationComposer> {
  late bool _focused;

  @override
  void initState() {
    super.initState();
    _focused = widget.focusNode.hasFocus;
    widget.controller.addListener(_changed);
    widget.focusNode.addListener(_changed);
  }

  void _changed() => setState(() => _focused = widget.focusNode.hasFocus);

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.focusNode.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.controller.text.trim().isNotEmpty && !widget.busy;
    return FluxGlass(
      radius: 999,
      color: FluxColors.surfaceOf(context),
      borderColor: FluxColors.inkOf(
        context,
      ).withValues(alpha: _focused ? .2 : .07),
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.only(left: 18, right: 7),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  inputFormatters: [LengthLimitingTextInputFormatter(4000)],
                  enabled: !widget.busy,
                  minLines: 1,
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => canSend ? widget.onSubmit() : null,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration.collapsed(
                    hintText: 'Describe a creation',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: FluxColors.mutedOf(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Semantics(
                button: true,
                enabled: canSend,
                label: 'Create',
                child: SizedBox.square(
                  dimension: 40,
                  child: InkWell(
                    onTap: canSend ? widget.onSubmit : null,
                    customBorder: const CircleBorder(),
                    child: Center(
                      child: FigmaSvg(
                        asset: canSend
                            ? FigmaAssets.activeSend
                            : FigmaAssets.send,
                        width: 34,
                        height: 34,
                        invertForDark: FluxColors.isDark(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
    decoration: BoxDecoration(
      color: const Color(0xFFD34B4B).withValues(alpha: .09),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const FluxIcon(icon: FluxIcons.sad, size: 18, color: Color(0xFFD34B4B)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.labelMedium),
        ),
        FluxIconButton(
          icon: FluxIcons.close,
          size: 30,
          tooltip: 'Dismiss',
          onTap: onDismiss,
        ),
      ],
    ),
  );
}

class _KindPicker extends StatelessWidget {
  const _KindPicker();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: FluxColors.canvasOf(context),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    ),
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      MediaQuery.paddingOf(context).bottom + 22,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          child: Container(
            width: 34,
            height: 4,
            decoration: BoxDecoration(
              color: FluxColors.lineOf(context),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'What are we making?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Finn adapts the structure to the format.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: FluxColors.mutedOf(context)),
        ),
        const SizedBox(height: 18),
        ...CreationKind.values.map(
          (kind) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Material(
              color: FluxColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => Navigator.pop(context, kind),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      FluxIcon(icon: _iconFor(kind), size: 21),
                      const SizedBox(width: 13),
                      Text(
                        kind.label,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const Spacer(),
                      const FluxIcon(icon: FluxIcons.arrowUp02, size: 17),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CreationDetail extends StatelessWidget {
  const _CreationDetail({required this.creation, required this.onDelete});
  final FinnCreation creation;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.sizeOf(context).height * .88,
    decoration: BoxDecoration(
      color: FluxColors.canvasOf(context),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: FluxColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: FluxIcon(icon: _iconFor(creation.kind), size: 18),
                ),
              ),
              const SizedBox(width: 11),
              Text(
                creation.kind.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: FluxColors.mutedOf(context),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text('Delete this creation?'),
                      content: Text(
                        '“${creation.title}” will be removed from this device.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) onDelete();
                },
                child: Text(
                  'Delete',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFFD34B4B),
                  ),
                ),
              ),
              FluxIconButton(
                icon: FluxIcons.close,
                tooltip: 'Close',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              Text(
                creation.title,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              if (creation.summary.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  creation.summary,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: FluxColors.mutedOf(context),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ...creation.sections.map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: FluxColors.cardOf(context),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.heading,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          section.body,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: FluxColors.mutedOf(context),
                                height: 1.45,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Original brief',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: FluxColors.mutedOf(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                creation.prompt,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _QuietLoader extends StatefulWidget {
  const _QuietLoader({this.label});
  final String? label;

  @override
  State<_QuietLoader> createState() => _QuietLoaderState();
}

class _QuietLoaderState extends State<_QuietLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _animation.value = .15;
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label ?? 'Creating',
    liveRegion: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RotationTransition(
          turns: _animation,
          child: FluxIcon(
            icon: FluxIcons.loading,
            size: 20,
            color: FluxColors.mutedOf(context),
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(width: 10),
          Text(
            widget.label!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: FluxColors.mutedOf(context),
            ),
          ),
        ],
      ],
    ),
  );
}

List<List<dynamic>> _iconFor(CreationKind kind) => switch (kind) {
  CreationKind.app => FluxIcons.canvas,
  CreationKind.widget => FluxIcons.chip,
  CreationKind.presentation => FluxIcons.skills,
};
