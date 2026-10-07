import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/creations/creation_palette.dart';
import 'package:finn_ai/src/features/creations/spec/widget_spec.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';

/// A home-screen widget drawn in the app, and *working*: the same taps do the
/// same things as on the launcher, so a creation can be tried before it is put
/// on the home screen.
///
/// The rules mirror `FinnHomeWidgetActions.kt`. This preview keeps its own
/// numbers for the lifetime of the screen; the launcher keeps its own.
class HomeWidgetPreview extends StatefulWidget {
  const HomeWidgetPreview({super.key, required this.spec});

  final HomeWidgetSpec spec;

  @override
  State<HomeWidgetPreview> createState() => _HomeWidgetPreviewState();
}

class _HomeWidgetPreviewState extends State<HomeWidgetPreview> {
  static const _goalSegments = 10;

  late int _value;
  late List<bool> _checks;
  late List<int> _values;

  HomeWidgetSpec get _spec => widget.spec;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(HomeWidgetPreview old) {
    super.didUpdateWidget(old);
    if (old.spec != widget.spec &&
        old.spec.toJson().toString() != widget.spec.toJson().toString()) {
      _reset();
    }
  }

  void _reset() {
    _value = _spec.rows.firstOrNull?.number ?? 0;
    _checks = [for (final _ in _spec.rows) false];
    _values = [for (final row in _spec.rows) row.number ?? 0];
  }

  void _tap(VoidCallback change) {
    HapticFeedback.selectionClick();
    setState(change);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context).textTheme;
    final accent = CreationPalette.pastel(_spec.accent);
    final interactive = _spec.kind.interactive;
    final isCounter = _spec.kind == HomeWidgetKind.counter;
    final goalNote =
        isCounter && _spec.goal > 0 ? '$_value / ${_spec.goal}' : null;
    final footer = [
      if (goalNote != null) goalNote,
      if (_spec.footer.trim().isNotEmpty) _spec.footer.trim(),
    ].join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FluxRadius.card),
        border: Border.all(color: const Color(0xFFE4E4E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            color: accent,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _spec.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleMedium?.copyWith(
                    color: CreationPalette.onPastel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_spec.kind == HomeWidgetKind.checklist)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${_checks.where((c) => c).length}/${_spec.rows.length}',
                    style: theme.labelMedium?.copyWith(
                      color: CreationPalette.onPastelMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (interactive)
                Semantics(
                  button: true,
                  label: l10n.creationsResetApp,
                  child: InkResponse(
                    onTap: () => _tap(_reset),
                    radius: 22,
                    child: const SizedBox(
                      width: 36,
                      height: 28,
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: CreationPalette.onPastelMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (isCounter)
            _counterBody(context, accent)
          else
            for (var i = 0; i < _spec.rows.take(4).length; i++)
              _row(context, i, accent),
          if (footer.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              footer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.labelMedium?.copyWith(
                color: CreationPalette.onPastelMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _counterBody(BuildContext context, Color accent) {
    final theme = Theme.of(context).textTheme;
    final label = _spec.rows.firstOrNull?.label ?? '';
    final filled = _spec.goal > 0
        ? (_value * _goalSegments ~/ _spec.goal).clamp(0, _goalSegments)
        : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.bodySmall?.copyWith(
            color: CreationPalette.onPastelMuted,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _round(
                accent,
                '−',
                () => _tap(() {
                      _value = (_value - _spec.step).clamp(0, 999999);
                    })),
            Expanded(
              child: Text(
                '$_value',
                textAlign: TextAlign.center,
                maxLines: 1,
                style: theme.displaySmall?.copyWith(
                  color: CreationPalette.onPastel,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _round(
                accent,
                '+',
                () => _tap(() {
                      _value = (_value + _spec.step).clamp(0, 999999);
                    })),
          ],
        ),
        if (_spec.goal > 0) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < _goalSegments; i++) ...[
                Expanded(
                  child: Container(
                    height: 5,
                    color: i < filled ? accent : const Color(0xFFE6E6E2),
                  ),
                ),
                if (i < _goalSegments - 1) const SizedBox(width: 3),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _round(Color color, String glyph, VoidCallback onTap) => Semantics(
        button: true,
        label: glyph,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              glyph,
              style: const TextStyle(
                color: CreationPalette.onPastel,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      );

  Widget _row(BuildContext context, int index, Color accent) {
    final theme = Theme.of(context).textTheme;
    final row = _spec.rows[index];
    final kind = _spec.kind;
    final done = kind == HomeWidgetKind.checklist && _checks[index];
    final content = Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          if (kind == HomeWidgetKind.checklist) ...[
            Icon(
              done
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 20,
              color:
                  done ? accent.withValues(alpha: 1) : CreationPalette.onPastel,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              row.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodyMedium?.copyWith(
                color: done
                    ? CreationPalette.onPastelMuted.withValues(alpha: .6)
                    : CreationPalette.onPastelMuted,
              ),
            ),
          ),
          if (kind == HomeWidgetKind.tracker) ...[
            Text(
              '${_values[index]}',
              style: theme.bodyMedium?.copyWith(
                color: CreationPalette.onPastel,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 26,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Text(
                '+',
                style: TextStyle(
                  color: CreationPalette.onPastel,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ] else if (kind == HomeWidgetKind.display)
            Text(
              row.value,
              style: theme.bodyMedium?.copyWith(
                color: CreationPalette.onPastel,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
    if (!kind.interactive) return content;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(() {
          if (kind == HomeWidgetKind.checklist) {
            _checks[index] = !_checks[index];
          } else {
            _values[index] = (_values[index] + _spec.step).clamp(0, 999999);
          }
        }),
        child: content,
      ),
    );
  }
}
