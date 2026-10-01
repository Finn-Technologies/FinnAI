import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/flows/flow_labels.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_overlays.dart';

/// Picks a time and the days of the week it runs. Null when dismissed.
Future<FlowTrigger?> showFlowSchedule(
  BuildContext context,
  FlowTrigger initial,
) =>
    showFinnSheet<FlowTrigger>(
      context,
      title: L10n.of(context).flowsScheduleSheetTitle,
      children: (_) => [_ScheduleBody(initial: initial)],
    );

class _ScheduleBody extends StatefulWidget {
  const _ScheduleBody({required this.initial});

  final FlowTrigger initial;

  @override
  State<_ScheduleBody> createState() => _ScheduleBodyState();
}

class _ScheduleBodyState extends State<_ScheduleBody> {
  late int _hour = widget.initial.isScheduled ? widget.initial.hour : 7;
  late int _minute = widget.initial.isScheduled ? widget.initial.minute : 30;
  late final Set<int> _days = !widget.initial.isScheduled
      ? {1, 2, 3, 4, 5}
      : widget.initial.daysOfWeek.isEmpty
          ? {1, 2, 3, 4, 5, 6, 7}
          : {...widget.initial.daysOfWeek};

  Future<void> _pick() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final initials = flowDayInitials(l10n);
    final names = flowDayNames(l10n);
    String two(int v) => v.toString().padLeft(2, '0');
    Widget box(String text, {required Key key}) => Semantics(
          button: true,
          label: l10n.flowsScheduleTime,
          excludeSemantics: true,
          child: Material(
            color: FluxColors.controlOf(context),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              key: key,
              onTap: _pick,
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 110,
                height: 90,
                child: Center(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            box(two(_hour), key: const Key('flow-schedule-hour')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(':', style: Theme.of(context).textTheme.titleLarge),
            ),
            box(two(_minute), key: const Key('flow-schedule-time')),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var day = 1; day <= 7; day++)
              Semantics(
                button: true,
                selected: _days.contains(day),
                label: names[day - 1],
                excludeSemantics: true,
                child: Material(
                  color: _days.contains(day)
                      ? FluxColors.actionOf(context)
                      : FluxColors.controlOf(context),
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: Key('flow-day-$day'),
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() {
                      _days.contains(day) ? _days.remove(day) : _days.add(day);
                    }),
                    child: SizedBox.square(
                      dimension: 44,
                      child: Center(
                        child: Text(
                          initials[day - 1],
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: _days.contains(day)
                                        ? FluxColors.actionInkOf(context)
                                        : null,
                                  ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        FinnButton(
          key: const Key('flow-schedule-save'),
          label: l10n.flowsScheduleSave,
          onTap: _days.isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    _days.length == 7
                        ? FlowTrigger.daily(_hour, _minute)
                        : FlowTrigger.weekly(_hour, _minute, {..._days}),
                  ),
        ),
      ],
    );
  }
}
