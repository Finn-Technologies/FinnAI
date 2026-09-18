import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/actions/device_action.dart';
import 'package:finn_ai/src/features/actions/device_action_descriptions.dart';
import 'package:finn_ai/src/features/actions/device_actions_controller.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/ambient_background.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_header.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

typedef _Example = ({
  List<List<dynamic>> icon,
  String Function(AppLocalizations) label,
});

class DeviceActionsPage extends StatefulWidget {
  const DeviceActionsPage({super.key, required this.onBack, this.controller});

  final VoidCallback onBack;
  final DeviceActionsController? controller;

  @override
  State<DeviceActionsPage> createState() => _DeviceActionsPageState();
}

class _DeviceActionsPageState extends State<DeviceActionsPage> {
  late final DeviceActionsController _controller =
      widget.controller ?? DeviceActionsController();
  late final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);
  final TextEditingController _field = TextEditingController();

  bool get _ownsController => widget.controller == null;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _controller.addListener(_onControllerChanged);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      _scrollOffset.value = _scrollController.offset;
    }
  }

  void _onControllerChanged() {
    final controller = _controller;
    if (controller.flow == DeviceActionFlow.done ||
        controller.error == 'unresolved') {
      _field.clear();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffset.dispose();
    _field.dispose();
    super.dispose();
  }

  Future<void> _submit([String? request]) async {
    final text = request ?? _field.text;
    if (text.trim().isEmpty) return;
    _field.text = text;
    await _controller.submit(text);
  }

  static final _examples = <_Example>[
    (icon: FluxIcons.alarm, label: (l10n) => l10n.deviceActionsExampleAlarm),
    (icon: FluxIcons.timer, label: (l10n) => l10n.deviceActionsExampleTimer),
    (icon: FluxIcons.wifi, label: (l10n) => l10n.deviceActionsExampleWifi),
    (
      icon: FluxIcons.flashlight,
      label: (l10n) => l10n.deviceActionsExampleFlashlight,
    ),
    (
      icon: FluxIcons.bluetooth,
      label: (l10n) => l10n.deviceActionsExampleBluetooth,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                    listenable: _controller,
                    builder: (context, _) => ListView(
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
                                Text(
                                  L10n.of(context).deviceActionsIntro,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: FluxColors.mutedOf(context),
                                      ),
                                ),
                                const SizedBox(height: 18),
                                _RequestField(
                                  controller: _field,
                                  busy: _controller.isBusy,
                                  onSubmit: _submit,
                                ),
                                const SizedBox(height: 18),
                                if (_controller.flow ==
                                    DeviceActionFlow.resolving)
                                  const _BusyRow(),
                                if (_controller.invocation != null &&
                                    _controller.flow ==
                                        DeviceActionFlow.confirming)
                                  _ConfirmCard(
                                    invocation: _controller.invocation!,
                                    onRun: _controller.confirm,
                                    onCancel: _controller.cancel,
                                  ),
                                if (_controller.flow ==
                                    DeviceActionFlow.running)
                                  const _BusyRow(),
                                if (_controller.result != null)
                                  _ResultCard(
                                    result: _controller.result!,
                                    onReset: _controller.reset,
                                  ),
                                if (_controller.error == 'unresolved')
                                  _UnresolvedCard(onReset: _controller.reset),
                                const SizedBox(height: 22),
                                _SectionLabel(
                                  text: L10n.of(context).deviceActionsExamples,
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final example in _examples)
                                      FluxPillButton(
                                        label: example.label(L10n.of(context)),
                                        icon: example.icon,
                                        compact: true,
                                        onTap: _controller.isBusy
                                            ? null
                                            : () => _submit(
                                                  example
                                                      .label(L10n.of(context)),
                                                ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                _OpenNotice(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: FinnPageHeader(
                    title: L10n.of(context).deviceActionsTitle,
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

class _RequestField extends StatelessWidget {
  const _RequestField({
    required this.controller,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final void Function([String?]) onSubmit;

  @override
  Widget build(BuildContext context) {
    return FluxGlass(
      radius: FluxRadius.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !busy,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: L10n.of(context).deviceActionsHint,
                  hintStyle: TextStyle(color: FluxColors.mutedOf(context)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FluxIconButton(
              icon: FluxIcons.arrowUp01,
              tooltip: L10n.of(context).deviceActionsRun,
              onTap: busy ? null : () => onSubmit(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: FluxColors.mutedOf(context)),
      );
}

class _BusyRow extends StatelessWidget {
  const _BusyRow();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
          const SizedBox(width: 10),
          Text(
            L10n.of(context).deviceActionsResolving,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: FluxColors.mutedOf(context)),
          ),
        ],
      );
}

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({
    required this.invocation,
    required this.onRun,
    required this.onCancel,
  });

  final DeviceActionInvocation invocation;
  final VoidCallback onRun;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return _Card(
      icon: _iconFor(invocation),
      title: DeviceActionDescriptions.describe(context, invocation),
      actions: [
        FluxPillButton(
          label: L10n.of(context).deviceActionsCancel,
          compact: true,
          onTap: onCancel,
        ),
        FluxPillButton(
          label: L10n.of(context).deviceActionsConfirm,
          icon: FluxIcons.check,
          compact: true,
          onTap: onRun,
        ),
      ],
    );
  }

  static List<List<dynamic>> _iconFor(DeviceActionInvocation call) =>
      switch (call.action.name) {
        'set_alarm' || 'show_alarms' => FluxIcons.alarm,
        'set_timer' => FluxIcons.timer,
        'torch' => FluxIcons.flashlight,
        'volume' || 'media' => FluxIcons.volume,
        'open_settings' => _settingsIcon(call.argument('screen') ?? ''),
        'open_app' => FluxIcons.chip,
        'dial' || 'compose_sms' => FluxIcons.internet,
        'compose_email' => FluxIcons.note,
        'take_photo' => FluxIcons.camera,
        'navigate' => FluxIcons.navigation,
        'share' => FluxIcons.copy,
        _ => FluxIcons.magic,
      };

  static List<List<dynamic>> _settingsIcon(String screen) => switch (screen) {
        'wifi' || 'hotspot' || 'mobile_data' => FluxIcons.wifi,
        'bluetooth' => FluxIcons.bluetooth,
        'battery_saver' || 'battery_usage' => FluxIcons.battery,
        'display' => FluxIcons.sun,
        'dnd' || 'sound' => FluxIcons.moon,
        'location' => FluxIcons.navigation,
        'date_time' => FluxIcons.calendar,
        _ => FluxIcons.settings,
      };
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onReset});

  final DeviceActionResult result;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final failed = result.outcome == DeviceActionOutcome.failed;

    final icon = switch (result.outcome) {
      DeviceActionOutcome.performed ||
      DeviceActionOutcome.opened =>
        FluxIcons.check,
      DeviceActionOutcome.unavailable => FluxIcons.cloudOff,
      DeviceActionOutcome.failed => FluxIcons.error,
    };

    return _Card(
      icon: icon,
      iconColor: failed
          ? Colors.redAccent
          : (result.isSuccess ? null : FluxColors.mutedOf(context)),
      title: DeviceActionDescriptions.resultLine(context, result),
      actions: [
        FluxPillButton(
          label: L10n.of(context).deviceActionsAgain,
          compact: true,
          onTap: onReset,
        ),
      ],
    );
  }
}

class _UnresolvedCard extends StatelessWidget {
  const _UnresolvedCard({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => _Card(
        icon: FluxIcons.info,
        title: L10n.of(context).deviceActionsUnresolved,
        actions: [
          FluxPillButton(
            label: L10n.of(context).deviceActionsAgain,
            compact: true,
            onTap: onReset,
          ),
        ],
      );
}

class _OpenNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: FluxIcon(
              icon: FluxIcons.info,
              size: 14,
              color: FluxColors.mutedOf(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              L10n.of(context).deviceActionsOpenNotice,
              style: Theme.of(
                context,
              )
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: FluxColors.mutedOf(context)),
            ),
          ),
        ],
      );
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.title,
    required this.actions,
    this.iconColor,
  });

  final List<List<dynamic>> icon;
  final String title;
  final List<Widget> actions;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return FluxGlass(
      radius: FluxRadius.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: FluxIcon(
                    icon: icon,
                    size: 16,
                    color: iconColor ?? FluxColors.inkOf(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  actions[i],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
