import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/flows/flow_icons.dart';
import 'package:finn_ai/src/features/flows/flow_labels.dart';
import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/src/shared/widgets/flux_surfaces.dart';

/// The families a step belongs to, for the picker's chips.
enum _Family { ai, device, logic }

_Family _familyOf(FlowBlockKind kind) => switch (kind) {
      FlowBlockKind.ask || FlowBlockKind.web => _Family.ai,
      FlowBlockKind.notify ||
      FlowBlockKind.speak ||
      FlowBlockKind.action =>
        _Family.device,
      FlowBlockKind.wait ||
      FlowBlockKind.branch ||
      FlowBlockKind.saveToChat ||
      FlowBlockKind.stop =>
        _Family.logic,
    };

/// Each step's colour, so a flow reads as a coloured sequence the way a
/// Shortcuts script does: what thinks is violet and blue, what touches the
/// phone is green, pink and orange, and logic is the quieter hues.
Color flowBlockColor(FlowBlockKind kind) => switch (kind) {
      FlowBlockKind.ask => const Color(0xFF8B5CF6),
      FlowBlockKind.web => const Color(0xFF3B82F6),
      FlowBlockKind.notify => const Color(0xFFF97316),
      FlowBlockKind.speak => const Color(0xFFEC4899),
      FlowBlockKind.action => const Color(0xFF22A35A),
      FlowBlockKind.wait => const Color(0xFFE0A100),
      FlowBlockKind.branch => const Color(0xFF14A3A0),
      FlowBlockKind.saveToChat => const Color(0xFF6366F1),
      FlowBlockKind.stop => const Color(0xFF6B7280),
    };

/// Which step to add. Null when dismissed.
///
/// Like the Shortcuts action library: a search field, a row of family
/// chips, and the steps as rows with a coloured glyph — one tap adds it.
Future<FlowBlockKind?> pickFlowBlockKind(
  BuildContext context, {
  required bool canBranch,
}) {
  final l10n = L10n.of(context);
  return showFinnSheet<FlowBlockKind>(
    context,
    title: l10n.flowsEdChooseStep,
    children: (sheet) => [_BlockPicker(canBranch: canBranch)],
  );
}

class _BlockPicker extends StatefulWidget {
  const _BlockPicker({required this.canBranch});

  final bool canBranch;

  @override
  State<_BlockPicker> createState() => _BlockPickerState();
}

class _BlockPickerState extends State<_BlockPicker> {
  final _search = TextEditingController();
  _Family? _family;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final query = _search.text.trim().toLowerCase();
    final kinds = [
      for (final kind in FlowBlockKind.values)
        if (kind != FlowBlockKind.branch || widget.canBranch)
          if (_family == null || _familyOf(kind) == _family)
            if (query.isEmpty ||
                flowBlockTitle(l10n, kind).toLowerCase().contains(query) ||
                flowBlockHint(l10n, kind).toLowerCase().contains(query))
              kind,
    ];
    String familyName(_Family family) => switch (family) {
          _Family.ai => 'FinnAI',
          _Family.device => l10n.flowsPickerDevice,
          _Family.logic => l10n.flowsPickerLogic,
        };
    IconData familyIcon(_Family family) => switch (family) {
          _Family.ai => FluxIcons.magic,
          _Family.device => FluxIcons.miniApp,
          _Family.logic => FlowIcons.branch,
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FluxPillField(
          key: const Key('block-search'),
          controller: _search,
          hint: l10n.searchHint,
          onChanged: (_) => setState(() {}),
          leading: FluxIcon(
            icon: FluxIcons.search,
            size: 20,
            color: FluxColors.mutedOf(context),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final family in _Family.values) ...[
                _FamilyChip(
                  label: familyName(family),
                  icon: familyIcon(family),
                  selected: _family == family,
                  onTap: () => setState(
                    () => _family = _family == family ? null : family,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSize(
          duration: FluxMotion.revealDuration,
          curve: FluxMotion.revealCurve,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final kind in kinds) ...[
                _StepRow(
                  key: Key('block-kind-${kind.name}'),
                  kind: kind,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).pop(kind);
                  },
                ),
                const SizedBox(height: 8),
              ],
              if (kinds.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    l10n.flowsPickerEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FluxColors.mutedOf(context)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A family filter, in the accent: tinted fill and text, like the
/// Shortcuts library's category buttons.
class _FamilyChip extends StatelessWidget {
  const _FamilyChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = FluxColors.accentOf(context);
    return Semantics(
      button: true,
      onTap: onTap,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: FluxPressScale(
        child: AnimatedContainer(
          duration: FluxMotion.revealDuration,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected
                ? accent
                : accent.withValues(
                    alpha: FluxColors.isDark(context) ? .16 : .1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FluxIcon(
                    icon: icon,
                    size: 18,
                    color: selected ? FluxColors.canvasOf(context) : accent,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: selected ? FluxColors.canvasOf(context) : accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One step: its coloured glyph, its name and what it does.
class _StepRow extends StatelessWidget {
  const _StepRow({super.key, required this.kind, required this.onTap});

  final FlowBlockKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final color = flowBlockColor(kind);
    return Semantics(
      button: true,
      onTap: onTap,
      label: '${flowBlockTitle(l10n, kind)}. ${flowBlockHint(l10n, kind)}',
      excludeSemantics: true,
      child: FluxPressScale(
        scale: .97,
        child: Material(
          color: FluxColors.isDark(context)
              ? const Color(0x14FFFFFF)
              : const Color(0x0D000000),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(color, Colors.white, .18)!,
                          color,
                        ],
                      ),
                    ),
                    child: Center(
                      child: FluxIcon(
                        icon: FlowIcons.forBlock(kind),
                        size: 21,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flowBlockTitle(l10n, kind),
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                            color: FluxColors.inkOf(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          flowBlockHint(l10n, kind),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 13,
                            height: 1.25,
                            color: FluxColors.secondaryInkOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
