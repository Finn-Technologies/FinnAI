import 'dart:async';
import 'package:flutter/material.dart';

import '../home/home_shell.dart';
import '../inference/device_profile.dart';
import '../inference/finn_inference.dart';
import '../theme/flux_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/flux_controls.dart';
import '../../l10n/l10n_helper.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    this.enableModelDownload = true,
    this.onComplete,
  });

  final bool enableModelDownload;
  final Future<void> Function()? onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _pageController = PageController();
  final _modelInstallerKey = GlobalKey<_AutomaticModelPageState>();
  bool _modelInstallRequested = false;

  void _to(int page) {
    if (page < 0) return;
    if (page > 4) {
      _finish();
      return;
    }
    final reduced = MediaQuery.disableAnimationsOf(context);
    _pageController.animateToPage(
      page,
      duration: reduced ? Duration.zero : const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubicEmphasized,
    );
    if (page == 2 && widget.enableModelDownload) {
      if (!_modelInstallRequested) {
        setState(() => _modelInstallRequested = true);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _modelInstallerKey.currentState?.start();
      });
    }
    if (page >= 3 && widget.enableModelDownload) {
      // Precautions and the final swipe give the mmap-backed engine time to
      // load before the user can type a first prompt on devices with ample RAM.
      // On entry/low-memory devices, skip eager prewarm to keep UI memory unpressured.
      final profile = FinnInference.instance.deviceProfile;
      if (profile == null || !DeviceProfiler.isLowEnd(profile)) {
        unawaited(FinnInference.instance.prewarm());
      }
    }
  }

  void _finish() {
    final persist = widget.onComplete;
    if (persist != null) unawaited(persist());
    Navigator.of(context).pushReplacement(_blurRoute(const HomeShell()));
  }

  PageRouteBuilder<void> _blurRoute(Widget child) => PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, animation, __) => child,
        transitionsBuilder: (context, animation, _, page) {
          if (MediaQuery.disableAnimationsOf(context)) return page;
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubicEmphasized,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, .06),
                end: Offset.zero,
              ).animate(curved),
              child: page,
            ),
          );
        },
      );

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final textTheme = base.textTheme;
    return Theme(
      data: base.copyWith(
        textTheme: textTheme.copyWith(
          titleMedium: textTheme.titleMedium?.copyWith(fontSize: 20),
          labelLarge: textTheme.labelLarge?.copyWith(fontSize: 16),
          labelMedium: textTheme.labelMedium?.copyWith(fontSize: 14),
        ),
      ),
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _WelcomePage(onNext: () => _to(1)),
            _DetailPage(
              iconAsset: FigmaAssets.privacy,
              title: L10n.of(context).onboardingPrivacyTitle,
              onBack: () => _to(0),
              onNext: () => _to(2),
              child: Text(
                L10n.of(context).onboardingPrivacyBody,
                style: TextStyle(
                  fontFamily: 'InstrumentSans',
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                  color: FluxColors.inkOf(context).withValues(alpha: .7),
                ),
              ),
            ),
            _AutomaticModelPage(
              key: _modelInstallerKey,
              startRequested: _modelInstallRequested,
              onBack: () => _to(1),
              onNext: () => _to(3),
            ),
            _DetailPage(
              iconAsset: FigmaAssets.security,
              title: L10n.of(context).onboardingPrecautionsTitle,
              contentTop: 93,
              onBack: () => _to(2),
              onNext: () => _to(4),
              child: const _Precautions(),
            ),
            _FinishPage(onBack: () => _to(3), onDone: () => _to(5)),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _SwipeAdvance(
        onAdvance: onNext,
        child: AmbientBackground(
          primaryColor: FluxColors.lime,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sy = constraints.maxHeight / 844;
              return Stack(
                children: [
                  Positioned(
                    top: 415 * sy,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        L10n.of(context).onboardingWelcome,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(fontSize: 21),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 655 * sy,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        const _FloatingArrow(),
                        const SizedBox(height: 12),
                        Text(
                          L10n.of(context).onboardingSwipeToStart,
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: FluxColors.mutedOf(context),
                                    fontSize: 16,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
}

class _SwipeAdvance extends StatefulWidget {
  const _SwipeAdvance({required this.child, required this.onAdvance});

  final Widget child;
  final VoidCallback onAdvance;

  @override
  State<_SwipeAdvance> createState() => _SwipeAdvanceState();
}

class _SwipeAdvanceState extends State<_SwipeAdvance> {
  double _distance = 0;
  bool _dragging = false;
  bool _committing = false;

  void _update(DragUpdateDetails details) {
    if (_committing) return;
    setState(() {
      _distance = (_distance - details.delta.dy).clamp(0, 90);
    });
  }

  void _end(DragEndDetails details) {
    if (_committing) return;
    final shouldAdvance =
        _distance >= 42 || (details.primaryVelocity ?? 0) < -420;
    setState(() {
      _dragging = false;
      _distance = shouldAdvance ? 90 : 0;
      _committing = shouldAdvance;
    });
    if (shouldAdvance) {
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (!mounted) return;
        widget.onAdvance();
        setState(() {
          _distance = 0;
          _committing = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => setState(() => _dragging = true),
      onVerticalDragUpdate: _update,
      onVerticalDragEnd: _end,
      onVerticalDragCancel: () => setState(() {
        _dragging = false;
        _distance = 0;
      }),
      child: AnimatedContainer(
        duration: reduced || _dragging
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, -_distance * .18, 0),
        child: widget.child,
      ),
    );
  }
}

class _FloatingArrow extends StatefulWidget {
  const _FloatingArrow();

  @override
  State<_FloatingArrow> createState() => _FloatingArrowState();
}

class _FloatingArrowState extends State<_FloatingArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final Animation<double> _animation = Tween<double>(
    begin: 0,
    end: -6,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const FigmaSvg(
        asset: FigmaAssets.welcomeArrow,
        width: 24,
        height: 24,
      );
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _animation.value),
        child: child,
      ),
      child: const FigmaSvg(
        asset: FigmaAssets.welcomeArrow,
        width: 24,
        height: 24,
      ),
    );
  }
}

class _DetailPage extends StatelessWidget {
  const _DetailPage({
    required this.iconAsset,
    required this.title,
    required this.child,
    required this.onBack,
    required this.onNext,
    this.contentTop = 79,
    this.backEnabled = true,
  });

  final String iconAsset;
  final String title;
  final Widget child;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final double contentTop;
  final bool backEnabled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final sy = constraints.maxHeight / 844;
          return Stack(
            children: [
              Positioned(
                left: 20,
                top: 71 * sy,
                child: IgnorePointer(
                  ignoring: !backEnabled,
                  child: AnimatedOpacity(
                    opacity: backEnabled ? 1 : .38,
                    duration: const Duration(milliseconds: 240),
                    child: BackControl(onTap: onBack),
                  ),
                ),
              ),
              Positioned(
                top: 210 * sy,
                left: (constraints.maxWidth - 90) / 2,
                child: _SoftIconEntrance(iconAsset: iconAsset),
              ),
              Positioned(
                top: 415 * sy,
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(FluxRadius.card),
                  ),
                  child: ColoredBox(
                    color: FluxColors.cardOf(context),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 25,
                          right: 25,
                          top: 40,
                          height: 24,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              title,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 25,
                          right: 25,
                          top: contentTop,
                          height: 216,
                          child: child,
                        ),
                        Positioned(
                          right: 25,
                          bottom: 79,
                          child: FluxPillButton(
                            label: L10n.of(context).commonNext,
                            onTap: onNext,
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _SoftIconEntrance extends StatelessWidget {
  const _SoftIconEntrance({required this.iconAsset});

  final String iconAsset;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 90,
        child: Center(child: FigmaSvg(asset: iconAsset, width: 90, height: 90)),
      );
}

class _AutomaticModelPage extends StatefulWidget {
  const _AutomaticModelPage({
    super.key,
    required this.startRequested,
    required this.onBack,
    required this.onNext,
  });

  final bool startRequested;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  State<_AutomaticModelPage> createState() => _AutomaticModelPageState();
}

class _AutomaticModelPageState extends State<_AutomaticModelPage> {
  final _inference = FinnInference.instance;
  bool _started = false;
  bool _ready = false;
  String? _error;
  double _progress = .02;

  @override
  void initState() {
    super.initState();
    _inference.addListener(_inferenceChanged);
    if (widget.startRequested) {
      WidgetsBinding.instance.addPostFrameCallback((_) => start());
    }
  }

  @override
  void didUpdateWidget(covariant _AutomaticModelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startRequested && !oldWidget.startRequested) {
      WidgetsBinding.instance.addPostFrameCallback((_) => start());
    }
  }

  @override
  void dispose() {
    _inference.removeListener(_inferenceChanged);
    super.dispose();
  }

  void _inferenceChanged() {
    if (!mounted) return;
    setState(() {
      final aggregate = _inference.installProgress;
      if (aggregate != null) {
        // Aggregate progress spans the language model AND the post-model
        // multimodal component, so the bar keeps advancing across the
        // artifact switch instead of jumping to ~97% with half the data
        // still to fetch.
        _progress = aggregate;
      }
    });
  }

  Future<void> start() async {
    debugPrint('FINN_START_CALLED: started=$_started, ready=$_ready');
    if (_started || _ready) return;
    setState(() {
      _started = true;
      _error = null;
      _progress = .02;
    });
    _inference.useAutomaticSelection();
    final models = _inference.requiredModels;
    debugPrint('FINN_START_MODELS: ${models.length}');
    // Resolved before the first await so no BuildContext is used across an
    // async gap.
    final verificationFailedMessage = L10n.of(
      context,
    ).onboardingInstallVerificationFailed;
    try {
      for (var index = 0; index < models.length; index++) {
        if (mounted) {
          setState(() => _progress = index / models.length);
        }
        final model = models[index];
        debugPrint(
            'FINN_INSTALLING_MODEL: ${model.name} (${model.downloadUrl})');
        // Calling install even for an existing language model also completes
        // the post-model mmproj download after an upgrade or interrupted
        // first run.
        await _inference.install(model);
        if (!await _inference.isInstalled(model)) {
          throw FormatException(verificationFailedMessage);
        }
      }
      // Measure the best CPU/GPU/NPU backend now that the model is present.
      try {
        await _inference.optimizeForDevice().timeout(
              const Duration(seconds: 35),
            );
      } catch (e) {
        debugPrint('FINN_OPTIMIZE timed out or failed: $e');
      }
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _ready = true;
      });
    } catch (e, st) {
      debugPrint('FINN_START_ERROR: $e\n$st');
      if (!mounted) return;
      setState(() {
        _started = false;
        _error = _inference.status;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _DetailPage(
        iconAsset: FigmaAssets.magic,
        title: _ready
            ? L10n.of(context).onboardingInstallTitleReady
            : L10n.of(context).onboardingInstallTitleInstalling,
        contentTop: 79,
        onBack: widget.onBack,
        backEnabled: _ready,
        onNext: _ready ? widget.onNext : null,
        child: _AutomaticInstallPanel(
          models: _inference.requiredModels,
          progress: _progress,
          ready: _ready,
          started: _started,
          error: _error,
          statusKey: _inference.statusKey,
          status: _inference.status,
          onRetry: start,
        ),
      );
}

class _AutomaticInstallPanel extends StatelessWidget {
  const _AutomaticInstallPanel({
    required this.models,
    required this.progress,
    required this.ready,
    required this.started,
    required this.error,
    required this.statusKey,
    required this.status,
    required this.onRetry,
  });

  final List<FinnModelSpec> models;
  final double progress;
  final bool ready;
  final bool started;
  final String? error;

  /// Machine-readable engine status, localized at this display layer.
  final FinnStatusKey statusKey;

  /// Raw engine status text, used as the fallback for unmapped values.
  final String status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final model = models.last;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final effectiveProgress = ready ? 1.0 : progress.clamp(.02, .98);
    final isDark = FluxColors.isDark(context);
    final inference = FinnInference.instance;
    final downloading =
        !ready && started && inference.phase == InferencePhase.downloading;
    // The whole install is one honest number: language model + multimodal
    // component, downloaded bytes so far, and what is left.
    final totalBytes = model.expectedBytes + finnMmproj.expectedBytes;
    final receivedBytes = inference.installReceivedBytes;
    final remainingBytes = inference.installRemainingBytes;
    final transferMeta = [
      if (downloading)
        L10n.of(context).onboardingInstallBytesOf(
            _formatBytes(receivedBytes), _formatBytes(totalBytes)),
      if (downloading && remainingBytes > 0)
        L10n.of(context)
            .onboardingInstallBytesLeft(_formatBytes(remainingBytes)),
      if (downloading && inference.downloadSpeedLabel != null)
        inference.downloadSpeedLabel!,
      if (downloading && inference.downloadEtaLabel != null)
        inference.downloadEtaLabel!,
    ].join(' · ');

    // The download card sits on top of the detail page's card, so its own
    // background is dropped in dark mode to avoid a nested dark slab. The
    // content scrolls vertically on very short screens instead of overflowing.
    return FluxGlass(
      radius: 24,
      color: isDark ? Colors.transparent : null,
      borderColor: isDark ? Colors.transparent : null,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration:
                    reduced ? Duration.zero : const Duration(milliseconds: 360),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: FluxIcon(
                  key: ValueKey('${ready}_icon'),
                  icon: ready ? FluxIcons.check : FluxIcons.chip,
                  size: 26,
                ),
              ),
              const SizedBox(height: 8),
              Text(model.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(
                ready
                    ? L10n.of(context).onboardingInstallReadyForChat
                    : L10n.of(context).onboardingInstallModelWithComponent(
                        model.name, _formatBytes(totalBytes)),
                maxLines: 2,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: FluxColors.mutedOf(context),
                    ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration:
                    reduced ? Duration.zero : const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                child: error != null
                    ? Column(
                        key: const ValueKey('error'),
                        children: [
                          Text(
                            error!,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: FluxColors.mutedOf(context)),
                          ),
                          const SizedBox(height: 10),
                          Semantics(
                            button: true,
                            label: L10n.of(context).onboardingInstallRetryLabel,
                            child: Material(
                              color: FluxColors.surfaceOf(context),
                              borderRadius: BorderRadius.circular(99),
                              child: InkWell(
                                onTap: onRetry,
                                borderRadius: BorderRadius.circular(99),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 9,
                                  ),
                                  child: Text(
                                    L10n.of(context).commonRetry,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: FluxColors.inkOf(context),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        key: ValueKey(ready),
                        ready
                            ? L10n.of(context).onboardingInstallModelReady
                            : started
                                ? L10n.of(context)
                                    .onboardingInstallProgressStatus(
                                    localizedEngineStatus(
                                        context, statusKey, status),
                                    (effectiveProgress * 100)
                                        .round()
                                        .toString(),
                                  )
                                : L10n.of(context).onboardingInstallPreparing,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: FluxColors.mutedOf(context),
                                  height: 1.3,
                                ),
                      ),
              ),
              if (!ready && started) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: effectiveProgress,
                    minHeight: 4,
                    color: isDark ? FluxColors.darkInk : FluxColors.ink,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: .12)
                        : Colors.black.withValues(alpha: .08),
                  ),
                ),
                if (transferMeta.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    child: Text(
                      transferMeta,
                      key: ValueKey(transferMeta),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: FluxColors.mutedOf(context),
                          ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Precautions extends StatelessWidget {
  const _Precautions();

  @override
  Widget build(BuildContext context) {
    final items = [
      L10n.of(context).onboardingPrecautionOne,
      L10n.of(context).onboardingPrecautionTwo,
      L10n.of(context).onboardingPrecautionThree,
      L10n.of(context).onboardingPrecautionFour,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final cardWidth = (constraints.maxWidth - gap) / 2;
        return Stack(
          children: List.generate(4, (i) {
            final left = i.isOdd ? cardWidth + gap : 0.0;
            final top = i > 1 ? 112.0 : 0.0;
            return Positioned(
              left: left,
              top: top,
              width: cardWidth,
              height: 104,
              child: FluxGlass(
                radius: 10,
                color: FluxColors.surfaceOf(context).withValues(alpha: .82),
                child: Stack(
                  children: [
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: FluxColors.inkOf(context),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: FluxColors.canvasOf(context),
                                    fontSize: 13,
                                  ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      top: 49,
                      child: Text(
                        items[i],
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class SoftwareUpgradeScreen extends StatefulWidget {
  const SoftwareUpgradeScreen({super.key});

  @override
  State<SoftwareUpgradeScreen> createState() => _SoftwareUpgradeScreenState();
}

/// Blocking screen shown when a returning user's required model is missing —
/// for example after the app upgrades from the retired tiered catalog to the
/// single local model. It reuses the onboarding download panel and only
/// continues to the home screen once the new model is installed.
class _SoftwareUpgradeScreenState extends State<SoftwareUpgradeScreen> {
  final _inference = FinnInference.instance;
  bool _started = false;
  bool _ready = false;
  String? _error;
  double _progress = .02;

  @override
  void initState() {
    super.initState();
    _inference.addListener(_inferenceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => start());
  }

  @override
  void dispose() {
    _inference.removeListener(_inferenceChanged);
    super.dispose();
  }

  void _inferenceChanged() {
    if (!mounted) return;
    setState(() {
      final aggregate = _inference.installProgress;
      if (aggregate != null) {
        _progress = aggregate;
      }
    });
  }

  Future<void> start() async {
    if (_started || _ready) return;
    setState(() {
      _started = true;
      _error = null;
      _progress = .02;
    });
    _inference.useAutomaticSelection();
    // Resolved before the first await so no BuildContext is used across an
    // async gap.
    final verificationFailedMessage = L10n.of(
      context,
    ).onboardingInstallVerificationFailed;
    try {
      for (final model in _inference.requiredModels) {
        await _inference.install(model);
        if (!await _inference.isInstalled(model)) {
          throw FormatException(verificationFailedMessage);
        }
      }
      // Measure the best CPU/GPU/NPU backend now that the new model is ready.
      await _inference.optimizeForDevice();
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _ready = true;
      });
      unawaited(_inference.prewarm());
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 350),
            reverseTransitionDuration: const Duration(milliseconds: 280),
            pageBuilder: (_, animation, __) => const HomeShell(),
            transitionsBuilder: (context, animation, _, page) =>
                FadeTransition(opacity: animation, child: page),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _started = false;
        _error = _inference.status;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    L10n.of(context).onboardingUpgradeTitle,
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    L10n.of(context).onboardingUpgradeBody,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: FluxColors.mutedOf(context),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _AutomaticInstallPanel(
                    models: _inference.requiredModels,
                    progress: _progress,
                    ready: _ready,
                    started: _started,
                    error: _error,
                    statusKey: _inference.statusKey,
                    status: _inference.status,
                    onRetry: start,
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

class _FinishPage extends StatelessWidget {
  const _FinishPage({required this.onBack, required this.onDone});
  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => _SwipeAdvance(
        onAdvance: onDone,
        child: AmbientBackground(
          primaryColor: FluxColors.lime,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sy = constraints.maxHeight / 844;
              return Stack(
                children: [
                  Positioned(
                    left: 20,
                    top: 71 * sy,
                    child: BackControl(onTap: onBack),
                  ),
                  Positioned(
                    top: 415 * sy,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        L10n.of(context).onboardingReadyTitle,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(fontSize: 21),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 655 * sy,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        const _FloatingArrow(),
                        const SizedBox(height: 12),
                        Text(
                          L10n.of(context).onboardingReadySubtitle,
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: FluxColors.mutedOf(context),
                                    fontSize: 16,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
}

/// Compact human-readable size used by the download card, e.g. "1.28 GB" or
/// "668 MB".
String _formatBytes(int bytes) {
  if (bytes >= 1000 * 1000 * 1000) {
    return '${(bytes / 1000 / 1000 / 1000).toStringAsFixed(2)} GB';
  }
  return '${(bytes / 1000 / 1000).round()} MB';
}
