import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/flows/flow_icons.dart';
import 'package:finn_ai/src/features/flows/flow_labels.dart';
import 'package:finn_ai/src/features/flows/flow_model.dart';
import 'package:finn_ai/src/features/flows/flows_actions.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// The colour of a flow's tile, from what starts it: the clock is indigo,
/// power and battery amber, Wi-Fi and flight sky blue, a headset pink, the
/// phone waking green, and a flow you start yourself slate. Like a
/// Shortcuts tile it makes a flow findable at a glance; unlike one, the
/// colour says something (Tasker's contexts, made visible).
///
/// Every stop keeps white text at WCAG AA (4.5:1 or more, checked in
/// `test/features/flow_tile_test.dart`); the first palette sat at 2.3-4.1:1
/// where the name is drawn.
List<Color> flowTileColors(FlowTriggerKind kind) => switch (kind) {
      FlowTriggerKind.manual => const [Color(0xFF69748E), Color(0xFF576074)],
      FlowTriggerKind.timeOfDay || FlowTriggerKind.interval => const [
          Color(0xFF556AE2),
          Color(0xFF4553C2)
        ],
      FlowTriggerKind.chargerConnected ||
      FlowTriggerKind.chargerDisconnected ||
      FlowTriggerKind.batteryLow =>
        const [Color(0xFFB15F18), Color(0xFF984A21)],
      FlowTriggerKind.headsetConnected ||
      FlowTriggerKind.headsetDisconnected =>
        const [Color(0xFFD23282), Color(0xFF9E3D6F)],
      FlowTriggerKind.wifiConnected ||
      FlowTriggerKind.wifiDisconnected ||
      FlowTriggerKind.airplaneOn ||
      FlowTriggerKind.airplaneOff =>
        const [Color(0xFF237BB1), Color(0xFF22649A)],
      FlowTriggerKind.deviceBooted || FlowTriggerKind.screenUnlocked => const [
          Color(0xFF308261),
          Color(0xFF1B6C4E)
        ],
    };

/// One flow as a tile: what starts it at the top left, a play button at the
/// top right, its name at the bottom, and whether it is on.
///
/// Tap opens the flow; play runs it now; the switch turns it on or off. A
/// paused flow keeps its place but loses its colour, so what is live stands
/// out without a second list.
class FlowTile extends StatelessWidget {
  const FlowTile({
    super.key,
    required this.flow,
    required this.actions,
    required this.onTap,
    required this.onRun,
  });

  final FinnFlow flow;
  final FlowsActions actions;
  final VoidCallback onTap;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final runs = actions.store.runsOf(flow.id);
    final last = runs.isEmpty ? null : runs.first;
    final running = actions.runningId == flow.id;
    final line = !flow.enabled
        ? l10n.flowsPausedLine
        : last == null
            ? flowTriggerLabel(l10n, flow.trigger)
            : l10n.flowsLastRunLine(
                flowWhen(context, last.startedAt),
                switch (last.outcome) {
                  FlowRunOutcome.completed => l10n.flowsResultDone,
                  FlowRunOutcome.interrupted => l10n.flowsResultStopped,
                  FlowRunOutcome.skipped => l10n.flowsRunSkipped,
                  _ => l10n.flowsResultFailed,
                },
              );
    final base = flowTileColors(flow.trigger.kind);
    final grey = FluxColors.isDark(context)
        ? const Color(0xFF3A3A44)
        : const Color(0xFF6E7080);
    final colors = [
      for (final c in base) Color.lerp(c, grey, flow.enabled ? 0 : .78)!,
    ];
    const ink = Colors.white;
    const glass = Color(0x33FFFFFF);

    return Semantics(
      button: true,
      label: '${flow.name}. ${flowTriggerLabel(l10n, flow.trigger)}. $line',
      child: FluxPressScale(
        scale: .96,
        child: AnimatedContainer(
          duration: FluxMotion.revealDuration,
          curve: FluxMotion.revealCurve,
          height: 148,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: Key('flow-tile-${flow.id}'),
              borderRadius: BorderRadius.circular(26),
              onTap: onTap,
              child: Stack(
                children: [
                  // A soft sheen across the top, so the tile reads as a lit
                  // object rather than a flat swatch.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.center,
                            colors: [Color(0x26FFFFFF), Color(0x00FFFFFF)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 9, 7, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: glass,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: FluxIcon(
                                  icon: FlowIcons.forTrigger(flow.trigger.kind),
                                  size: 21,
                                  color: ink,
                                ),
                              ),
                            ),
                            const Spacer(),
                            _TileSwitch(
                              key: Key('flow-toggle-${flow.id}'),
                              value: flow.enabled,
                              label: l10n.flowsNameSemantic(flow.name),
                              onChanged: (v) => unawaited(
                                actions.setEnabled(context, flow, v),
                              ),
                            ),
                            _PlayButton(
                              key: Key('flow-run-tile-${flow.id}'),
                              running: running,
                              label: l10n.flowsRunAction,
                              onTap: onRun,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          flow.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 17,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.35,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          line,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 12.5,
                            height: 1.2,
                            color: Color(0xF2FFFFFF),
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

/// The tile's run control: a frosted circle with a play mark that turns
/// into a turning ring while the flow runs.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    super.key,
    required this.running,
    required this.label,
    required this.onTap,
  });

  final bool running;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: FluxPressScale(
          // A 48dp target; the frosted disc inside it stays 38dp.
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: running
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    onTap();
                  },
            child: SizedBox.square(
              dimension: FluxMotion.minTapTarget,
              child: Center(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0x33FFFFFF),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 38,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: FluxMotion.revealDuration,
                        child: running
                            ? const SizedBox.square(
                                key: ValueKey('running'),
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Padding(
                                key: ValueKey('play'),
                                // Optical centre: a triangle's mass sits left.
                                padding: EdgeInsets.only(left: 2),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  size: 24,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// A small on/off switch drawn for a coloured tile: a frosted track and a
/// white knob that slides, with the same semantics as the app's switch.
class _TileSwitch extends StatelessWidget {
  const _TileSwitch({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        toggled: value,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(!value);
          },
          child: Padding(
            // A 48dp target around the 38x22 track.
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 13),
            child: AnimatedContainer(
              duration: FluxMotion.revealDuration,
              curve: FluxMotion.pressReturnCurve,
              width: 38,
              height: 22,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color:
                    value ? const Color(0x66FFFFFF) : const Color(0x33000000),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      );
}
