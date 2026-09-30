// ignore_for_file: invalid_use_of_protected_member
part of '../flows_page.dart';

String _templateName(BuildContext context, String id) {
  final l10n = L10n.of(context);
  return switch (id) {
    'morning_brief' => l10n.flowsTemplateMorningBrief,
    'web_check' => l10n.flowsTemplateWebCheck,
    'reminder' => l10n.flowsTemplateReminder,
    _ => id,
  };
}

String _templateBody(BuildContext context, String id) {
  final l10n = L10n.of(context);
  return switch (id) {
    'morning_brief' => l10n.flowsTemplateMorningBriefBody,
    'web_check' => l10n.flowsTemplateWebCheckBody,
    'reminder' => l10n.flowsTemplateReminderBody,
    _ => '',
  };
}

String _slotName(BuildContext context, String key) {
  final l10n = L10n.of(context);
  return switch (key) {
    'topics' => l10n.flowsSlotTopics,
    'city' => l10n.flowsSlotCity,
    'topic' => l10n.flowsSlotTopic,
    'message' => l10n.flowsSlotMessage,
    _ => key,
  };
}

/// What the user picked in the automation sheet.
class _AutomationDraft {
  const _AutomationDraft({required this.values, required this.trigger});

  final SlotValues values;
  final FlowTrigger trigger;
}

extension _AutomationActions on _SkillsPageState {
  /// Tell the user why, then ask. The system prompt has no explanation of its
  /// own, and asking at first use (never at install) is the point.
  Future<bool> _ensureNotifications() async {
    final scheduler = widget.scheduler;
    if (scheduler == null) return false;
    if (await scheduler.backend.notificationsAllowed()) return true;
    if (!mounted) return false;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context).flowsNotifyWhyTitle),
        content: Text(L10n.of(context).flowsNotifyWhyBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(L10n.of(context).commonNotNow),
          ),
          FilledButton(
            key: const Key('flow-notify-allow'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(L10n.of(context).flowsNotifyAllow),
          ),
        ],
      ),
    );
    if (agreed != true) return false;
    final granted = await scheduler.ensurePermission();
    await _refreshNotificationState();
    return granted;
  }

  Future<void> _newAutomation() async {
    final template = await showModalBottomSheet<FlowTemplate>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TemplatePicker(),
    );
    if (template == null || !mounted) return;
    final draft = await showModalBottomSheet<_AutomationDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AutomationSheet(template: template),
    );
    if (draft == null) return;
    final flow = template.build(
      'custom-${DateTime.now().microsecondsSinceEpoch}',
      draft.values,
      trigger: draft.trigger,
    );
    final saved = await _store.upsertCustom(
      name: flow.name,
      description: flow.description,
      instructions: '',
      category: flow.category,
      steps: flow.steps,
      trigger: flow.trigger,
    );
    if (saved && flow.trigger.isScheduled) {
      await _ensureNotifications();
    }
    await widget.scheduler?.sync(_store.flows);
    await _refreshNotificationState();
  }

  Future<void> _editSchedule(FinnFlow flow) async {
    final trigger = await showModalBottomSheet<FlowTrigger>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleSheet(initial: flow.trigger, name: flow.name),
    );
    if (trigger == null) return;
    await _store.upsertCustom(
      id: flow.id,
      name: flow.name,
      description: flow.description,
      instructions: flow.instructions,
      category: flow.category,
      enabled: flow.enabled,
      steps: flow.steps,
      trigger: trigger,
    );
    if (trigger.isScheduled) await _ensureNotifications();
    await widget.scheduler?.sync(_store.flows);
    await _refreshNotificationState();
  }

  Future<void> _refreshNotificationState() async {
    final allowed = await widget.scheduler?.backend.notificationsAllowed();
    if (!mounted) return;
    setState(() => _notificationsOn = allowed ?? true);
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
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
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      );
}

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker();

  @override
  Widget build(BuildContext context) => _SheetFrame(
        title: L10n.of(context).flowsNewAutomation,
        child: Column(
          children: [
            for (final template in FlowTemplates.all)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Material(
                  color: FluxColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(FluxRadius.md),
                  child: InkWell(
                    key: Key('flow-template-${template.id}'),
                    onTap: () => Navigator.pop(context, template),
                    borderRadius: BorderRadius.circular(FluxRadius.md),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 64),
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _templateName(context, template.id),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _templateBody(context, template.id),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: FluxColors.mutedOf(context),
                                      height: 1.35,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

/// When a flow runs: never on its own, every day, or on weekdays, at a time.
///
/// Three choices and a time, on purpose. A cron-style editor is powerful and a
/// trap; these cover "every morning" and "on workdays", and the model behind
/// them (`FlowTrigger`) can hold more if a later screen wants it.
class _ScheduleFields extends StatelessWidget {
  const _ScheduleFields({required this.trigger, required this.onChanged});

  final FlowTrigger trigger;
  final ValueChanged<FlowTrigger> onChanged;

  static const _workdays = {1, 2, 3, 4, 5};

  int get _mode => !trigger.isScheduled
      ? 0
      : trigger.daysOfWeek.isEmpty
          ? 1
          : 2;

  FlowTrigger _with(int mode, int hour, int minute) => switch (mode) {
        0 => const FlowTrigger.manual(),
        1 => FlowTrigger.daily(hour, minute),
        _ => FlowTrigger.weekly(hour, minute, _workdays),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final hour = trigger.isScheduled ? trigger.hour : 7;
    final minute = trigger.isScheduled ? trigger.minute : 30;
    final labels = [
      l10n.flowsScheduleManual,
      l10n.flowsScheduleEveryDay,
      l10n.flowsScheduleWeekdaysOnly,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.flowsScheduleHeading,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var mode = 0; mode < labels.length; mode++)
              ChoiceChip(
                key: Key('flow-schedule-mode-$mode'),
                label: Text(labels[mode]),
                selected: _mode == mode,
                onSelected: (_) => onChanged(_with(mode, hour, minute)),
              ),
          ],
        ),
        if (_mode != 0) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            key: const Key('flow-schedule-time'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: hour, minute: minute),
              );
              if (picked != null) {
                onChanged(_with(_mode, picked.hour, picked.minute));
              }
            },
            child: Text(
              '${l10n.flowsScheduleTime}: '
              '${hour.toString().padLeft(2, '0')}:'
              '${minute.toString().padLeft(2, '0')}',
            ),
          ),
        ],
      ],
    );
  }
}

class _AutomationSheet extends StatefulWidget {
  const _AutomationSheet({required this.template});

  final FlowTemplate template;

  @override
  State<_AutomationSheet> createState() => _AutomationSheetState();
}

class _AutomationSheetState extends State<_AutomationSheet> {
  final Map<String, TextEditingController> _controllers = {};
  late FlowTrigger _trigger = widget.template.defaultTrigger;

  @override
  void initState() {
    super.initState();
    for (final slot in widget.template.slots) {
      _controllers[slot.key] = TextEditingController(
        text: '${slot.fallback}' == '' ? '' : '${slot.fallback}',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
        title: _templateName(context, widget.template.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final slot in widget.template.slots) ...[
              TextField(
                key: Key('flow-slot-${slot.key}'),
                controller: _controllers[slot.key],
                maxLength: slot.maxChars,
                decoration: InputDecoration(
                  labelText: _slotName(context, slot.key),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
            ],
            _ScheduleFields(
              trigger: _trigger,
              onChanged: (value) => setState(() => _trigger = value),
            ),
            const SizedBox(height: 18),
            FluxPillButton(
              key: const Key('flow-automation-save'),
              label: L10n.of(context).commonSave,
              onTap: () => Navigator.pop(
                context,
                _AutomationDraft(
                  values: SlotSanitizer.sanitize(widget.template.slots, {
                    for (final entry in _controllers.entries)
                      entry.key: entry.value.text,
                  }),
                  trigger: _trigger,
                ),
              ),
            ),
          ],
        ),
      );
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({required this.initial, required this.name});

  final FlowTrigger initial;
  final String name;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late FlowTrigger _trigger = widget.initial;

  @override
  Widget build(BuildContext context) => _SheetFrame(
        title: widget.name,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScheduleFields(
              trigger: _trigger,
              onChanged: (value) => setState(() => _trigger = value),
            ),
            const SizedBox(height: 18),
            FluxPillButton(
              key: const Key('flow-schedule-save'),
              label: L10n.of(context).commonSave,
              onTap: () => Navigator.pop(context, _trigger),
            ),
          ],
        ),
      );
}
