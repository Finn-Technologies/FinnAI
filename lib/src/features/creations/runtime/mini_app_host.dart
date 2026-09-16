import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/features/creations/runtime/mini_app_renderer.dart';
import 'package:finn_ai/src/features/creations/runtime/mini_app_state.dart';
import 'package:finn_ai/src/features/creations/spec/mini_app_spec.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/ambient_background.dart';
import 'package:finn_ai/src/shared/widgets/finn_page_header.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

/// Full-screen host for a generated mini app.
///
/// Owns the [MiniAppState] for the lifetime of the screen, so state is
/// per-launch and in memory only: a creation reopened later starts fresh.
class MiniAppHost extends StatefulWidget {
  const MiniAppHost({
    super.key,
    required this.title,
    required this.spec,
    required this.onBack,
  });

  final String title;
  final MiniAppSpec spec;
  final VoidCallback onBack;

  @override
  State<MiniAppHost> createState() => _MiniAppHostState();
}

class _MiniAppHostState extends State<MiniAppHost> {
  late final MiniAppState _state = MiniAppState(widget.spec);
  final _scrollOffset = ValueNotifier<double>(0);

  @override
  void dispose() {
    _state.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      floatingActionButton: FloatingActionButton.small(
        onPressed: _state.reset,
        tooltip: L10n.of(context).creationsResetApp,
        backgroundColor: FluxColors.surfaceOf(context),
        foregroundColor: FluxColors.inkOf(context),
        elevation: 0,
        child: const FluxIcon(icon: FluxIcons.refresh, size: 19),
      ),
      body: AmbientBackground(
        intensity: .6,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = FinnPageHeaderMetrics.forHeight(
              constraints.maxHeight,
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      _scrollOffset.value = notification.metrics.pixels;
                      return false;
                    },
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const FluxBouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        20,
                        metrics.contentTop + 6,
                        20,
                        120 + MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: MiniAppRenderer(state: _state),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: FinnPageHeader(
                    title: widget.title,
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
