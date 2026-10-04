import 'package:flutter/material.dart';

import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/ambient_background.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_header.dart';
import 'package:finn_ai/src/shared/widgets/finn_ui.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/you/you_profile_store.dart';

class YouProfilePage extends StatefulWidget {
  const YouProfilePage({super.key, required this.onBack, this.store});

  final VoidCallback onBack;
  final YouProfileStore? store;

  @override
  State<YouProfilePage> createState() => _YouProfilePageState();
}

class _YouProfilePageState extends State<YouProfilePage> {
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
          saved ? L10n.of(context).youSaved : L10n.of(context).youSaveFailed,
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
              constraints.maxWidth,
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
                            25,
                            metrics.contentTop,
                            25,
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
                                    FinnReveal(
                                      child: _IntroCard(
                                        icon: FluxIcons.you,
                                        title: L10n.of(context).youIntroTitle,
                                        body: L10n.of(context).youIntroBody,
                                      ),
                                    ),
                                    const SizedBox(height: 25),
                                    FluxSectionLabel(
                                        L10n.of(context).youAboutYou),
                                    const SizedBox(height: 6),
                                    _FinnTextField(
                                      key: const Key('you-name-field'),
                                      controller: _nameController,
                                      label: L10n.of(context).youNameHint,
                                      hint: L10n.of(context).youNamePlaceholder,
                                      maxLength: 60,
                                    ),
                                    const SizedBox(height: 10),
                                    _FinnTextField(
                                      key: const Key('you-about-field'),
                                      controller: _aboutController,
                                      label: L10n.of(context).youAboutQuestion,
                                      hint:
                                          L10n.of(context).youAboutPlaceholder,
                                      maxLines: 3,
                                      maxLength: 400,
                                    ),
                                    const SizedBox(height: 25),
                                    FluxSectionLabel(
                                      L10n.of(context).youResponseStyle,
                                    ),
                                    const SizedBox(height: 6),
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
                                    const SizedBox(height: 25),
                                    FluxSectionLabel(
                                      L10n.of(context).youInstructionsLabel,
                                    ),
                                    const SizedBox(height: 6),
                                    _FinnTextField(
                                      key: const Key('you-instructions-field'),
                                      controller: _instructionsController,
                                      label: L10n.of(context)
                                          .youInstructionsQuestion,
                                      hint: L10n.of(
                                        context,
                                      ).youInstructionsPlaceholder,
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
                                            height: 50,
                                            child: FilledButton(
                                              key: const Key('you-save-button'),
                                              onPressed:
                                                  _store.saving ? null : _save,
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    FluxColors.actionOf(
                                                        context),
                                                foregroundColor:
                                                    FluxColors.actionInkOf(
                                                  context,
                                                ),
                                                disabledBackgroundColor:
                                                    FluxColors.actionOf(
                                                  context,
                                                ).withValues(alpha: .25),
                                                shape: const StadiumBorder(),
                                                elevation: 0,
                                              ),
                                              child: Text(
                                                _store.saving
                                                    ? L10n.of(context).youSaving
                                                    : L10n.of(
                                                        context,
                                                      ).youSavePreferences,
                                              ),
                                            ),
                                          ),
                                          if (_store.storageError != null) ...[
                                            const SizedBox(height: 10),
                                            Text(
                                              L10n.of(context).youSaveFailed,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium
                                                  ?.copyWith(
                                                    color: FluxColors
                                                        .destructiveOf(context),
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
                    title: L10n.of(context).youTitle,
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
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: FluxColors.controlOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: FluxColors.tileOf(context),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: FluxIcon(icon: icon, size: 22, strokeWidth: 1.5),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FluxColors.secondaryInkOf(context),
                        ),
                  ),
                ],
              ),
            ),
          ],
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
          fillColor: FluxColors.controlOf(context),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(FluxRadius.card),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(FluxRadius.card),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(FluxRadius.card),
            borderSide:
                BorderSide(color: FluxColors.actionOf(context), width: 1.2),
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
        label: L10n.of(
          context,
        ).youStyleSemantic(_styleLabel(context, style)),
        child: Material(
          color: selected
              ? FluxColors.actionOf(context)
              : FluxColors.controlOf(context),
          shape: const StadiumBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                // widthFactor/heightFactor make the Center shrink to the label.
                // A plain Center expands to the widest constraint it is given,
                // and Wrap hands its children the full line width, so each
                // style chip stretched edge to edge and the four of them
                // stacked into what looked like four full-width buttons
                // instead of one row of choices.
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    _styleLabel(context, style),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: selected
                              ? FluxColors.actionInkOf(context)
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

/// Localized label for a response style (the enum's own label stays English
/// data used inside prompt instructions).
String _styleLabel(BuildContext context, FinnResponseStyle style) =>
    switch (style) {
      FinnResponseStyle.balanced => L10n.of(context).youResponseStyleBalanced,
      FinnResponseStyle.concise => L10n.of(context).youResponseStyleConcise,
      FinnResponseStyle.detailed => L10n.of(context).youResponseStyleDetailed,
      FinnResponseStyle.conversational =>
        L10n.of(context).youResponseStyleConversational,
    };
