part of '../flows_page.dart';

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.flow,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
    this.onRun,
    this.onGrantChanged,
    this.onEditSchedule,
    this.notificationsOff = false,
    this.runs = const [],
    this.isRunning = false,
  });

  final FinnFlow flow;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEditSchedule;

  /// The flow is scheduled but the OS will not show its notification.
  final bool notificationsOff;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Runs the flow once, on the spot. Always asks before any device action.
  final VoidCallback? onRun;

  final ValueChanged<bool>? onGrantChanged;
  final List<FlowRun> runs;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: FluxColors.cardOf(context),
        borderRadius: BorderRadius.circular(FluxRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(FluxRadius.card),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FluxColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(FluxRadius.sm),
                ),
                child: Center(
                  child: FluxIcon(
                    icon: _iconFor(flow.category),
                    size: 20,
                    color: FluxColors.inkOf(context),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            flow.name,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ),
                        if (!flow.builtIn)
                          PopupMenuButton<String>(
                            tooltip: L10n.of(context).flowsActionsTooltip,
                            padding: EdgeInsets.zero,
                            icon: const FluxIcon(
                              icon: FluxIcons.moreHorizontal,
                              size: 21,
                            ),
                            onSelected: (value) {
                              if (value == 'edit') onEdit?.call();
                              if (value == 'delete') onDelete?.call();
                            },
                            itemBuilder: (_) => [
                              // An automation is edited by its schedule chip
                              // and recreated from a template, not here.
                              if (onEdit != null)
                                PopupMenuItem(
                                    value: 'edit',
                                    child: Text(L10n.of(context).commonEdit)),
                              PopupMenuItem(
                                  value: 'delete',
                                  child: Text(L10n.of(context).commonDelete)),
                            ],
                          ),
                      ],
                    ),
                    if (flow.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        flow.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: FluxColors.mutedOf(context),
                              height: 1.35,
                            ),
                      ),
                    ],
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: FluxColors.surfaceOf(context),
                            borderRadius:
                                BorderRadius.circular(FluxRadius.pill),
                          ),
                          child: Text(
                            _categoryLabel(context, flow.category),
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  letterSpacing: -0.1,
                                ),
                          ),
                        ),
                        const Spacer(),
                        Semantics(
                          label: L10n.of(context).flowsNameSemantic(flow.name),
                          toggled: flow.enabled,
                          child: ExcludeSemantics(
                            child: Switch.adaptive(
                              key: Key('flow-toggle-${flow.id}'),
                              value: flow.enabled,
                              onChanged: onToggle,
                              activeTrackColor: FluxColors.inkOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (flow.steps.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _AutomationControls(
                        flow: flow,
                        isRunning: isRunning,
                        onRun: onRun,
                        onGrantChanged: onGrantChanged,
                        onEditSchedule: onEditSchedule,
                        notificationsOff: notificationsOff,
                      ),
                    ],
                    if (runs.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _RunHistory(runs: runs),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<List<dynamic>> _iconFor(String category) => switch (category) {
        'Writing' => FluxIcons.note,
        'Development' => FluxIcons.sourceCode,
        'Learning' => FluxIcons.education,
        'Planning' => FluxIcons.task,
        _ => FluxIcons.magic,
      };
}

/// The controls that make a flow an automation rather than a preference: when
/// it runs, whether it may run by itself, and a button to run it now.
class _AutomationControls extends StatelessWidget {
  const _AutomationControls({
    required this.flow,
    required this.isRunning,
    this.onRun,
    this.onGrantChanged,
    this.onEditSchedule,
    this.notificationsOff = false,
  });

  final FinnFlow flow;
  final bool isRunning;
  final VoidCallback? onRun;
  final ValueChanged<bool>? onGrantChanged;
  final VoidCallback? onEditSchedule;
  final bool notificationsOff;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final canAct = flow.hasDeviceAction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FluxPillButton(
              key: Key('flow-run-${flow.id}'),
              label: isRunning ? l10n.flowsRunRunning : l10n.flowsRunAction,
              onTap: isRunning ? null : onRun,
            ),
            FluxChip(
              key: Key('flow-steps-${flow.id}'),
              label: l10n.flowsStepCount(flow.steps.length),
              onTap: null,
            ),
            if (flow.trigger.isScheduled || onEditSchedule != null)
              FluxChip(
                key: Key('flow-schedule-${flow.id}'),
                label: flow.trigger.isScheduled
                    ? _scheduleLabel(context, flow.trigger)
                    : l10n.flowsScheduleHeading,
                onTap: onEditSchedule,
              ),
          ],
        ),
        if (notificationsOff) ...[
          const SizedBox(height: 8),
          Text(
            l10n.flowsNotifyOff,
            key: Key('flow-notify-off-${flow.id}'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: FluxColors.secondaryInkOf(context),
                  height: 1.35,
                ),
          ),
        ],
        if (canAct) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.flowsGrantLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: FluxColors.inkOf(context),
                      ),
                ),
              ),
              Semantics(
                label: l10n.flowsGrantLabel,
                toggled: flow.granted,
                child: ExcludeSemantics(
                  child: Switch.adaptive(
                    key: Key('flow-grant-${flow.id}'),
                    value: flow.granted,
                    onChanged: onGrantChanged,
                    activeTrackColor: FluxColors.inkOf(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.flowsGrantExplain,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: FluxColors.secondaryInkOf(context),
                  height: 1.35,
                ),
          ),
        ],
      ],
    );
  }

  String _scheduleLabel(BuildContext context, FlowTrigger trigger) {
    final l10n = L10n.of(context);
    final time = '${trigger.hour.toString().padLeft(2, '0')}:'
        '${trigger.minute.toString().padLeft(2, '0')}';
    if (trigger.daysOfWeek.isEmpty) {
      return l10n.flowsScheduleDaily(time);
    }
    if (trigger.daysOfWeek.length == 5 &&
        trigger.daysOfWeek.containsAll(const {1, 2, 3, 4, 5})) {
      return l10n.flowsScheduleWeekdaysAt(time);
    }
    return l10n.flowsScheduleWeekly(_weekdays(context, trigger), time);
  }

  String _weekdays(BuildContext context, FlowTrigger trigger) {
    // Uses intl's locale data rather than shipping weekday names in five ARB
    // files. The data is loaded by the app's Material delegates; where it is
    // not (a bare test app, an unsupported locale) the English names are used
    // instead of letting a label crash the page.
    final days = [
      for (final day in trigger.daysOfWeek.toList()..sort())
        if (day >= 1 && day <= 7) day,
    ];
    try {
      final names = DateFormat.EEEE(L10n.of(context).localeName);
      return [
        for (final day in days) names.format(DateTime(2026, 1, 5 + day - 1)),
      ].join(', ');
    } on Object {
      const english = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return [for (final day in days) english[day - 1]].join(', ');
    }
  }
}
