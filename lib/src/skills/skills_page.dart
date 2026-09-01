import 'package:flutter/material.dart';

import '../theme/flux_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/finn_page_header.dart';
import '../widgets/flux_controls.dart';
import 'skills_store.dart';

class SkillsPage extends StatefulWidget {
  const SkillsPage({super.key, required this.onBack, this.store});

  final VoidCallback onBack;
  final SkillsStore? store;

  @override
  State<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends State<SkillsPage> {
  late final SkillsStore _store = widget.store ?? SkillsStore.instance;
  late final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _store.initialize();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      _scrollOffset.value = _scrollController.offset;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  Future<void> _editSkill([FinnSkill? skill]) async {
    final result = await showModalBottomSheet<_SkillDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SkillEditor(skill: skill),
    );
    if (result == null) return;
    final saved = await _store.upsertCustom(
      id: skill?.id,
      name: result.name,
      description: result.description,
      instructions: result.instructions,
      enabled: skill?.enabled ?? true,
    );
    if (!saved && mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _store.storageError ?? 'That skill could not be saved.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _delete(FinnSkill skill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FluxRadius.card)),
        title: const Text('Delete this skill?'),
        content: Text('“${skill.name}” will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _store.removeCustom(skill.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: ListenableBuilder(
        listenable: _store,
        builder: (context, _) => _store.initialized
            ? FloatingActionButton.extended(
                key: const Key('add-skill-button'),
                onPressed: _editSkill,
                backgroundColor: FluxColors.inkOf(context),
                foregroundColor: FluxColors.canvasOf(context),
                elevation: 0,
                shape: const StadiumBorder(),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('New skill'),
              )
            : const SizedBox.shrink(),
      ),
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
                  child: ListenableBuilder(
                    listenable: _store,
                    builder: (context, _) {
                      if (!_store.initialized) {
                        return const Center(
                          child: SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        );
                      }
                      final builtIns = _store.skills
                          .where((skill) => skill.builtIn)
                          .toList();
                      final custom = _store.skills
                          .where((skill) => !skill.builtIn)
                          .toList();
                      return ListView(
                        controller: _scrollController,
                        physics: const FluxBouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          20,
                          metrics.contentTop + 10,
                          20,
                          104,
                        ),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 680),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _SkillsSummary(
                                    active: _store.enabledSkills.length,
                                    total: _store.skills.length,
                                  ),
                                  const SizedBox(height: 24),
                                  const _SectionTitle(
                                    title: 'Built for Finn',
                                    subtitle:
                                        'Enable only what you need for each kind of work.',
                                  ),
                                  const SizedBox(height: 10),
                                  ...builtIns.map(
                                    (skill) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: _SkillCard(
                                        skill: skill,
                                        onToggle: (value) =>
                                            _store.setEnabled(skill.id, value),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const _SectionTitle(
                                    title: 'Your skills',
                                    subtitle:
                                        'Create reusable instructions for your own workflows.',
                                  ),
                                  const SizedBox(height: 10),
                                  if (custom.isEmpty)
                                    const _EmptyCustomSkills()
                                  else
                                    ...custom.map(
                                      (skill) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: _SkillCard(
                                          skill: skill,
                                          onToggle: (value) => _store
                                              .setEnabled(skill.id, value),
                                          onEdit: () => _editSkill(skill),
                                          onDelete: () => _delete(skill),
                                        ),
                                      ),
                                    ),
                                  if (_store.storageError != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _store.storageError!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(color: Colors.redAccent),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: FinnPageHeader(
                    title: 'Skills',
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

class _SkillsSummary extends StatelessWidget {
  const _SkillsSummary({required this.active, required this.total});

  final int active;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: FluxColors.cardOf(context),
      borderRadius: BorderRadius.circular(FluxRadius.sheet),
      border: Border.all(color: FluxColors.lineOf(context)),
    ),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: FluxColors.surfaceOf(context),
          ),
          child: Center(child: FluxIcon(icon: FluxIcons.skills, size: 23)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                active == 0 ? 'No skills active' : '$active active',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 3),
              Text(
                '$total available · skills guide relevant replies',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: FluxColors.mutedOf(context),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 3),
      Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: FluxColors.mutedOf(context),
          height: 1.35,
        ),
      ),
    ],
  );
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.skill,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  final FinnSkill skill;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Material(
    color: FluxColors.cardOf(context),
    borderRadius: BorderRadius.circular(FluxRadius.card),
    child: Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 10, 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FluxRadius.card),
        border: Border.all(
          color: skill.enabled
              ? FluxColors.inkOf(context).withValues(alpha: .35)
              : FluxColors.lineOf(context),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: FluxColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(FluxRadius.sm),
            ),
            child: Icon(
              _iconFor(skill.category),
              size: 19,
              color: FluxColors.inkOf(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        skill.name,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    if (!skill.builtIn)
                      PopupMenuButton<String>(
                        tooltip: 'Skill actions',
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_horiz_rounded, size: 21),
                        onSelected: (value) {
                          if (value == 'edit') onEdit?.call();
                          if (value == 'delete') onDelete?.call();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                  ],
                ),
                if (skill.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    skill.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: FluxColors.mutedOf(context),
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: FluxColors.surfaceOf(context),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        skill.category,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    const Spacer(),
                    Semantics(
                      label: '${skill.name} skill',
                      toggled: skill.enabled,
                      child: ExcludeSemantics(
                        child: Switch.adaptive(
                          key: Key('skill-toggle-${skill.id}'),
                          value: skill.enabled,
                          onChanged: onToggle,
                          activeTrackColor: FluxColors.inkOf(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  IconData _iconFor(String category) => switch (category) {
    'Writing' => Icons.edit_note_rounded,
    'Development' => Icons.code_rounded,
    'Learning' => Icons.school_outlined,
    'Planning' => Icons.checklist_rounded,
    _ => Icons.auto_awesome_outlined,
  };
}

class _EmptyCustomSkills extends StatelessWidget {
  const _EmptyCustomSkills();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
    decoration: BoxDecoration(
      color: FluxColors.surfaceOf(context).withValues(alpha: .65),
      borderRadius: BorderRadius.circular(FluxRadius.card),
      border: Border.all(color: FluxColors.lineOf(context)),
    ),
    child: Text(
      'No custom skills yet. Create one for a workflow you repeat.',
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: FluxColors.mutedOf(context)),
    ),
  );
}

class _SkillDraft {
  const _SkillDraft({
    required this.name,
    required this.description,
    required this.instructions,
  });

  final String name;
  final String description;
  final String instructions;
}

class _SkillEditor extends StatefulWidget {
  const _SkillEditor({this.skill});
  final FinnSkill? skill;

  @override
  State<_SkillEditor> createState() => _SkillEditorState();
}

class _SkillEditorState extends State<_SkillEditor> {
  late final _name = TextEditingController(text: widget.skill?.name ?? '');
  late final _description = TextEditingController(
    text: widget.skill?.description ?? '',
  );
  late final _instructions = TextEditingController(
    text: widget.skill?.instructions ?? '',
  );

  bool get _valid =>
      _name.text.trim().isNotEmpty && _instructions.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _name.addListener(_changed);
    _instructions.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    decoration: BoxDecoration(
      color: FluxColors.canvasOf(context),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(FluxRadius.sheet)),
    ),
    child: SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FluxColors.lineOf(context),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.skill == null ? 'New skill' : 'Edit skill',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 5),
              Text(
                'Write a reusable instruction Finn should apply when relevant.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: FluxColors.mutedOf(context),
                ),
              ),
              const SizedBox(height: 18),
              _EditorField(
                key: const Key('skill-name-field'),
                controller: _name,
                label: 'Name',
                hint: 'What does this skill do?',
                maxLength: 60,
              ),
              const SizedBox(height: 10),
              _EditorField(
                controller: _description,
                label: 'Short description',
                hint: 'A quick reminder for you',
                maxLength: 140,
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              _EditorField(
                key: const Key('skill-instructions-field'),
                controller: _instructions,
                label: 'Instructions',
                hint: 'Tell Finn how to approach this kind of task',
                maxLength: 500,
                maxLines: 5,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: FilledButton(
                  key: const Key('save-skill-button'),
                  onPressed: _valid
                      ? () => Navigator.pop(
                          context,
                          _SkillDraft(
                            name: _name.text,
                            description: _description.text,
                            instructions: _instructions.text,
                          ),
                        )
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: FluxColors.inkOf(context),
                    foregroundColor: FluxColors.canvasOf(context),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: const Text('Save skill'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EditorField extends StatelessWidget {
  const _EditorField({
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
    maxLength: maxLength,
    maxLines: maxLines,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: FluxColors.mutedOf(context)),
      filled: true,
      fillColor: FluxColors.cardOf(context),
      contentPadding: const EdgeInsets.all(16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FluxRadius.md),
        borderSide: BorderSide(color: FluxColors.lineOf(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FluxRadius.md),
        borderSide: BorderSide(color: FluxColors.inkOf(context)),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(FluxRadius.md)),
    ),
  );
}
