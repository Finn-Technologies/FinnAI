import 'package:flutter/material.dart';

import '../theme/flux_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/flux_controls.dart';

enum _CreationKind { app, widget, presentation }

class _CreationData {
  const _CreationData({
    required this.label,
    required this.kind,
    required this.icon,
  });

  final String label;
  final _CreationKind kind;
  final List<List<dynamic>> icon;
}

class CreationsPage extends StatefulWidget {
  const CreationsPage({super.key});

  @override
  State<CreationsPage> createState() => _CreationsPageState();
}

class _CreationsPageState extends State<CreationsPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  int selected = 0;
  bool askingDetails = false;
  String prompt = '';
  final List<_CreationData> _creations = [];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    _focusNode.unfocus();
    setState(() {
      prompt = value;
      askingDetails = true;
      _controller.clear();
    });
  }

  void _completeCreation(_CreationKind kind) {
    final icon = switch (kind) {
      _CreationKind.app => FluxIcons.canvas,
      _CreationKind.widget => FluxIcons.chip,
      _CreationKind.presentation => FluxIcons.skills,
    };
    setState(() {
      _creations.add(_CreationData(label: prompt, kind: kind, icon: icon));
      askingDetails = false;
      prompt = '';
      selected = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleCreations = _visibleCreations();
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AmbientBackground(
        intensity: 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sy = constraints.maxHeight / 844;
            final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
            return Stack(
              children: [
                Positioned(
                  left: 20,
                  top: 71 * sy,
                  child: BackControl(onTap: () => Navigator.pop(context)),
                ),
                Positioned(
                  left: 20,
                  top: 110 * sy,
                  child: Text(
                    'Creations',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (!askingDetails) ...[
                  Positioned(
                    left: 20,
                    top: 149 * sy,
                    right: 20,
                    height: 28,
                    child: _Chips(
                      selected: selected,
                      onSelected: (value) => setState(() => selected = value),
                    ),
                  ),
                  if (visibleCreations.isNotEmpty)
                    Positioned.fill(
                      top: 197 * sy,
                      bottom: 100 + safeBottom,
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: 178,
                              crossAxisSpacing: 37,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: visibleCreations.length,
                        itemBuilder: (context, index) => _CreationCard(
                          creation: visibleCreations[index],
                          index: index,
                        ),
                      ),
                    ),
                ] else ...[
                  Positioned(
                    right: 20,
                    top: 154 * sy,
                    child: _PromptBubble(text: prompt),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    top: 212 * sy,
                    height: 197,
                    child: _AskingDetails(onSelected: _completeCreation),
                  ),
                ],
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 124 + safeBottom,
                  child: IgnorePointer(
                    child: ColoredBox(color: FluxColors.canvasOf(context)),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: safeBottom + (constraints.maxHeight < 650 ? 20 : 30),
                  child: _CreationComposer(
                    controller: _controller,
                    focusNode: _focusNode,
                    onSubmit: _submit,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<_CreationData> _visibleCreations() {
    if (selected == 0) return _creations;
    final kind = _CreationKind.values[selected - 1];
    return _creations.where((creation) => creation.kind == kind).toList();
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = ['All', 'Apps', 'Widgets', 'Presentations'];
    const widths = [49.0, 67.0, 89.0, 126.0];
    return Row(
      children: List.generate(labels.length, (i) {
        final active = i == selected;
        return Padding(
          padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 5),
          child: Material(
            color: active
                ? FluxColors.inkOf(context)
                : FluxColors.surfaceOf(context).withValues(alpha: .84),
            borderRadius: BorderRadius.circular(99),
            child: InkWell(
              onTap: () => onSelected(i),
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                width: widths[i],
                height: 28,
                child: Center(
                  child: Text(
                    labels[i],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
      }),
    );
  }
}

class _CreationCard extends StatelessWidget {
  const _CreationCard({required this.creation, required this.index});
  final _CreationData creation;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFBFEECB),
      const Color(0xFFBBE7F6),
      const Color(0xFFD0F1BB),
      const Color(0xFFF0CFBB),
      const Color(0xFFD2D2F4),
    ];
    final iconColors = [
      FluxColors.ink,
      const Color(0xFF55A6F7),
      const Color(0xFF75E38C),
      const Color(0xFFE87777),
      const Color(0xFF55A6F7),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors[index % colors.length],
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: FluxIcon(
                      icon: creation.icon,
                      size: 60,
                      color: iconColors[index % iconColors.length],
                      strokeWidth: 1.45,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 5,
                bottom: 5,
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const FluxIcon(icon: FluxIcons.add, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 150,
          child: Text(
            creation.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _CreationComposer extends StatefulWidget {
  const _CreationComposer({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  State<_CreationComposer> createState() => _CreationComposerState();
}

class _CreationComposerState extends State<_CreationComposer> {
  late bool _hasText;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_changed);
  }

  void _changed() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText == _hasText) return;
    setState(() => _hasText = hasText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FluxGlass(
    radius: 15,
    color: Colors.white.withValues(alpha: .84),
    child: SizedBox(
      height: 50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            const FigmaSvg(
              asset: FigmaAssets.creationAdd,
              width: 30,
              height: 30,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => widget.onSubmit(),
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration.collapsed(
                  hintText: 'Describe a Creation',
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: FluxColors.mutedOf(context),
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: _hasText ? widget.onSubmit : null,
              borderRadius: BorderRadius.circular(17),
              child: FigmaSvg(
                asset: _hasText
                    ? FigmaAssets.activeSend
                    : FigmaAssets.creationSend,
                width: 34,
                height: 34,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PromptBubble extends StatelessWidget {
  const _PromptBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 230),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: FluxColors.surfaceOf(context),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

class _AskingDetails extends StatelessWidget {
  const _AskingDetails({required this.onSelected});
  final ValueChanged<_CreationKind> onSelected;

  @override
  Widget build(BuildContext context) => FluxGlass(
    radius: 12,
    child: Stack(
      children: [
        Positioned(
          left: 15,
          right: 15,
          top: 15,
          child: Text(
            'Is your new Creation an app, a widget or a presentation?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Positioned(
          left: 15,
          right: 15,
          top: 66,
          child: Column(
            children: _CreationKind.values
                .map(
                  (kind) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: FluxColors.surfaceOf(
                        context,
                      ).withValues(alpha: .84),
                      borderRadius: BorderRadius.circular(99),
                      child: InkWell(
                        onTap: () => onSelected(kind),
                        borderRadius: BorderRadius.circular(99),
                        child: SizedBox(
                          width: 320,
                          height: 32,
                          child: Center(
                            child: Text(switch (kind) {
                              _CreationKind.app => 'App',
                              _CreationKind.widget => 'Widget',
                              _CreationKind.presentation => 'Presentation',
                            }, style: Theme.of(context).textTheme.bodyMedium),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    ),
  );
}
