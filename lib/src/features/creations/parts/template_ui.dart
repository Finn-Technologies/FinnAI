part of '../creations_page.dart';

String _templateLabel(BuildContext context, String id) {
  final l10n = L10n.of(context);
  return switch (id) {
    'counter' => l10n.creationsTemplateCounter,
    'checklist' => l10n.creationsTemplateChecklist,
    'list' => l10n.creationsTemplateList,
    'scoreboard' => l10n.creationsTemplateScoreboard,
    'stat' => l10n.creationsTemplateStat,
    'rows' => l10n.creationsTemplateRows,
    _ => id,
  };
}

String _slotLabel(BuildContext context, String key) {
  final l10n = L10n.of(context);
  return switch (key) {
    'title' => l10n.creationsSlotTitle,
    'unit' => l10n.creationsSlotUnit,
    'goal' => l10n.creationsSlotGoal,
    'emoji' => l10n.creationsSlotEmoji,
    'accent' => l10n.creationsSlotAccent,
    'items' => l10n.creationsSlotItems,
    'hint' => l10n.creationsSlotHint,
    'empty' => l10n.creationsSlotEmpty,
    'nameA' => l10n.creationsSlotNameA,
    'nameB' => l10n.creationsSlotNameB,
    'label' => l10n.creationsSlotLabel,
    'value' => l10n.creationsSlotValue,
    'footer' => l10n.creationsSlotFooter,
    'rows' => l10n.creationsSlotRows,
    _ => key,
  };
}

String _accentLabel(BuildContext context, MiniAppAccent accent) {
  final l10n = L10n.of(context);
  return switch (accent) {
    MiniAppAccent.mint => l10n.creationsAccentMint,
    MiniAppAccent.blue => l10n.creationsAccentBlue,
    MiniAppAccent.lime => l10n.creationsAccentLime,
    MiniAppAccent.amber => l10n.creationsAccentAmber,
    MiniAppAccent.rose => l10n.creationsAccentRose,
    MiniAppAccent.violet => l10n.creationsAccentViolet,
    MiniAppAccent.sky => l10n.creationsAccentSky,
  };
}

/// "Want a starting point?": the templates for a kind, as tappable chips.
///
/// Optional. Skipping it lets the app choose from the brief.
class _TemplateQuestion extends StatelessWidget {
  const _TemplateQuestion({
    required this.kind,
    required this.answered,
    required this.onChoose,
  });

  final CreationKind kind;

  /// The chosen template id, or null while "Let Finn choose" is in effect.
  final String? answered;
  final ValueChanged<String?> onChoose;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            L10n.of(context).creationsTemplateQuestion,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TemplateChip(
                label: L10n.of(context).creationsTemplateAuto,
                selected: answered == null,
                onTap: () => onChoose(null),
              ),
              for (final template in CreationTemplates.forKind(kind))
                _TemplateChip(
                  label: _templateLabel(context, template.id),
                  selected: answered == template.id,
                  onTap: () => onChoose(template.id),
                ),
            ],
          ),
        ],
      );
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: selected
              ? FluxColors.inkOf(context)
              : FluxColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.pill),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(FluxRadius.pill),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected
                          ? FluxColors.canvasOf(context)
                          : FluxColors.inkOf(context),
                    ),
              ),
            ),
          ),
        ),
      );
}

/// Edits a template-made creation by its slots. Saving rebuilds the creation
/// from the template: no model is involved, so it is instant and always valid.
class _SlotEditorSheet extends StatefulWidget {
  const _SlotEditorSheet({required this.creation, required this.onSave});

  final FinnCreation creation;
  final Future<void> Function(Map<String, Object?> slots) onSave;

  @override
  State<_SlotEditorSheet> createState() => _SlotEditorSheetState();
}

class _SlotEditorSheetState extends State<_SlotEditorSheet> {
  late final CreationTemplate _template;
  late final Map<String, Object?> _values;
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _template = CreationTemplates.byId(widget.creation.template?.id)!;
    _values = Map.of(widget.creation.template!.slots);
    for (final slot in _template.slots) {
      switch (slot.kind) {
        case SlotKind.text || SlotKind.emoji || SlotKind.integer:
          _controllers[slot.key] = TextEditingController(
            text: '${_values[slot.key] ?? ''}',
          );
        case SlotKind.list:
          _controllers[slot.key] = TextEditingController(
            text: ((_values[slot.key] as List?) ?? const []).join('\n'),
          );
        case SlotKind.accent || SlotKind.choice:
          break;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final raw = Map<String, Object?>.of(_values);
    for (final entry in _controllers.entries) {
      raw[entry.key] = entry.value.text;
    }
    await widget.onSave(raw);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Container(
      decoration: BoxDecoration(
        color: FluxColors.canvasOf(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(FluxRadius.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            18,
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 18),
            Text(
              '${l10n.creationsEditTitle} · '
              '${_templateLabel(context, _template.id)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            for (final slot in _template.slots) ...[
              _field(context, slot),
              const SizedBox(height: 14),
            ],
            FluxPillButton(
              label: l10n.commonSave,
              onTap: _saving ? null : () => unawaited(_save()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(BuildContext context, TemplateSlot slot) {
    final l10n = L10n.of(context);
    final label = _slotLabel(context, slot.key);
    switch (slot.kind) {
      case SlotKind.accent:
        final selected = MiniAppAccent.parse(
          '${_values[slot.key] ?? slot.fallback}',
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final accent in MiniAppAccent.values)
                  Semantics(
                    button: true,
                    selected: accent == selected,
                    label: _accentLabel(context, accent),
                    child: InkResponse(
                      onTap: () =>
                          setState(() => _values[slot.key] = accent.name),
                      radius: 26,
                      child: SizedBox.square(
                        dimension: 48,
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: CreationPalette.pastel(accent),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accent == selected
                                    ? FluxColors.inkOf(context)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      case SlotKind.choice:
        return const SizedBox.shrink();
      default:
        final isList = slot.kind == SlotKind.list;
        return TextField(
          controller: _controllers[slot.key],
          minLines: 1,
          maxLines: isList ? 6 : 1,
          keyboardType: slot.kind == SlotKind.integer
              ? TextInputType.number
              : TextInputType.multiline,
          textInputAction:
              isList ? TextInputAction.newline : TextInputAction.next,
          decoration: InputDecoration(
            labelText: label,
            helperText: isList
                ? (slot.key == 'rows'
                    ? l10n.creationsSlotRowFormat
                    : l10n.creationsSlotOnePerLine)
                : null,
          ),
        );
    }
  }
}
