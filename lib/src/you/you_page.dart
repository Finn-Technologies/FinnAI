import 'package:flutter/material.dart';

import '../theme/flux_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/finn_page_header.dart';
import '../widgets/flux_controls.dart';
import 'you_profile_store.dart';

class YouPage extends StatefulWidget {
  const YouPage({super.key, required this.onBack, this.store});

  final VoidCallback onBack;
  final YouProfileStore? store;

  @override
  State<YouPage> createState() => _YouPageState();
}

class _YouPageState extends State<YouPage> {
  late final YouProfileStore _store = widget.store ?? YouProfileStore.instance;
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _instructionsController = TextEditingController();
  FinnResponseStyle _style = FinnResponseStyle.balanced;
  bool _ready = false;
  late final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      _scrollOffset.value = _scrollController.offset;
    }
  }

  Future<void> _load() async {
    await _store.initialize();
    if (!mounted) return;
    final profile = _store.profile;
    _nameController.text = profile.preferredName;
    _aboutController.text = profile.about;
    _instructionsController.text = profile.customInstructions;
    setState(() {
      _style = profile.responseStyle;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffset.dispose();
    _nameController.dispose();
    _aboutController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final saved = await _store.save(
      FinnUserProfile(
        preferredName: _nameController.text,
        about: _aboutController.text,
        customInstructions: _instructionsController.text,
        responseStyle: _style,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? 'Personalization saved locally.' : 'Could not save changes.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AmbientBackground(
        intensity: 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = FinnPageHeaderMetrics.forHeight(
              constraints.maxHeight,
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: !_ready
                      ? const Center(
                          child: SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        )
                      : ListView(
                          controller: _scrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          physics: const FluxBouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            20,
                            metrics.contentTop + 10,
                            20,
                            24 + MediaQuery.viewInsetsOf(context).bottom,
                          ),
                          children: [
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 680,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _IntroCard(
                                      icon: FluxIcons.you,
                                      title: 'Make Finn feel like yours',
                                      body:
                                          'Your preferences stay on this device and shape future replies.',
                                    ),
                                    const SizedBox(height: 22),
                                    const _SectionLabel('About you'),
                                    const SizedBox(height: 9),
                                    _FinnTextField(
                                      key: const Key('you-name-field'),
                                      controller: _nameController,
                                      label: 'What should Finn call you?',
                                      hint: 'Preferred name',
                                      maxLength: 60,
                                    ),
                                    const SizedBox(height: 10),
                                    _FinnTextField(
                                      key: const Key('you-about-field'),
                                      controller: _aboutController,
                                      label: 'Anything Finn should know?',
                                      hint:
                                          'Your work, interests, goals, or context',
                                      maxLines: 3,
                                      maxLength: 400,
                                    ),
                                    const SizedBox(height: 22),
                                    const _SectionLabel('Response style'),
                                    const SizedBox(height: 9),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: FinnResponseStyle.values
                                          .map(
                                            (style) => _StyleChip(
                                              style: style,
                                              selected: _style == style,
                                              onTap: () => setState(
                                                () => _style = style,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                    const SizedBox(height: 22),
                                    const _SectionLabel('Custom instructions'),
                                    const SizedBox(height: 9),
                                    _FinnTextField(
                                      key: const Key('you-instructions-field'),
                                      controller: _instructionsController,
                                      label: 'How should Finn respond?',
                                      hint:
                                          'For example: explain technical terms, use metric units…',
                                      maxLines: 5,
                                      maxLength: 1000,
                                    ),
                                    const SizedBox(height: 16),
                                    ListenableBuilder(
                                      listenable: _store,
                                      builder: (context, _) => Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          SizedBox(
                                            height: 48,
                                            child: FilledButton(
                                              key: const Key('you-save-button'),
                                              onPressed: _store.saving
                                                  ? null
                                                  : _save,
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    FluxColors.inkOf(context),
                                                foregroundColor:
                                                    FluxColors.canvasOf(
                                                      context,
                                                    ),
                                                disabledBackgroundColor:
                                                    FluxColors.inkOf(
                                                      context,
                                                    ).withValues(alpha: .25),
                                                shape: const StadiumBorder(),
                                                elevation: 0,
                                              ),
                                              child: Text(
                                                _store.saving
                                                    ? 'Saving…'
                                                    : 'Save preferences',
                                              ),
                                            ),
                                          ),
                                          if (_store.storageError != null) ...[
                                            const SizedBox(height: 10),
                                            Text(
                                              _store.storageError!,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium
                                                  ?.copyWith(
                                                    color: Colors.redAccent,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                Positioned.fill(
                  child: FinnPageHeader(
                    title: 'You',
                    onBack: widget.onBack,
                    metrics: metrics,
                    scrollOffset: _scrollOffset,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: FluxColors.cardOf(context),
      borderRadius: BorderRadius.circular(FluxRadius.sheet),
      border: Border.all(color: FluxColors.lineOf(context)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: FluxColors.surfaceOf(context),
            shape: BoxShape.circle,
          ),
          child: Center(child: FluxIcon(icon: icon, size: 22)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 4),
              Text(
                body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: FluxColors.mutedOf(context),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: FluxColors.mutedOf(context),
      letterSpacing: .2,
    ),
  );
}

class _FinnTextField extends StatelessWidget {
  const _FinnTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.maxLength,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLength;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLines: maxLines,
    maxLength: maxLength,
    textCapitalization: TextCapitalization.sentences,
    style: Theme.of(context).textTheme.bodyMedium,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: FluxColors.mutedOf(context)),
      counterStyle: TextStyle(color: FluxColors.mutedOf(context)),
      filled: true,
      fillColor: FluxColors.cardOf(context),
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FluxRadius.md),
        borderSide: BorderSide(color: FluxColors.lineOf(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FluxRadius.md),
        borderSide: BorderSide(color: FluxColors.lineOf(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FluxRadius.md),
        borderSide: BorderSide(color: FluxColors.inkOf(context), width: 1.2),
      ),
    ),
  );
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final FinnResponseStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${style.label} response style',
    child: Material(
      color: selected ? FluxColors.inkOf(context) : FluxColors.cardOf(context),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? FluxColors.inkOf(context)
              : FluxColors.lineOf(context),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Center(
              child: Text(
                style.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected
                      ? FluxColors.canvasOf(context)
                      : FluxColors.inkOf(context),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
