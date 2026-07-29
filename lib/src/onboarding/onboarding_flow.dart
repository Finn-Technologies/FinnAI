import 'dart:async';
import 'package:flutter/material.dart';

import '../home/home_shell.dart';
import '../inference/bonsai_inference.dart';
import '../theme/flux_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/flux_controls.dart';

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
      // load before the user can type a first prompt.
      unawaited(BonsaiInference.instance.prewarm());
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
    pageBuilder: (_, animation, _) => child,
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
          bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 16),
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
              title: 'Finn AI is Privacy-First',
              onBack: () => _to(0),
              onNext: () => _to(2),
              child: Text(
                'Finn AI is designed to respect your privacy.\n\nAI processing and conversation history stay on this device. When a request needs fresh information, Finn AI may send only that request as a web search query and will show the sources it used. Your history and personal profile are never included.\n\nFinn AI is proprietary software and is not open source.',
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
              title: 'Before starting, read precautions',
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
                    'Welcome to Finn AI!',
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
                      'Swipe to start',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
                top: Radius.circular(20),
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
                        label: 'Next',
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
  final _inference = BonsaiInference.instance;
  bool _started = false;
  bool _ready = false;
  String? _error;
  double _progress = .02;
  int _installIndex = 0;
  int _installCount = 1;

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
    final reported = _inference.downloadProgress;
    setState(() {
      if (reported != null) {
        final aggregate = (_installIndex + reported) / _installCount;
        _progress = aggregate.clamp(_progress, .97);
      }
      if (_inference.phase == InferencePhase.loading && _started) {
        final aggregate = (_installIndex + .98) / _installCount;
        _progress = aggregate.clamp(_progress, .98);
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
    final models = _inference.requiredModels;
    _installCount = models.length;
    try {
      for (var index = 0; index < models.length; index++) {
        _installIndex = index;
        if (mounted) {
          setState(() => _progress = index / models.length);
        }
        final model = models[index];
        if (!await _inference.isInstalled(model)) {
          await _inference.install(model);
        }
        if (!await _inference.isInstalled(model)) {
          throw const FormatException('Model verification failed');
        }
      }
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _ready = true;
      });
    } catch (_) {
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
    title: _ready ? 'Best model installed' : 'Installing the best model',
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
    required this.status,
    required this.onRetry,
  });

  final List<BonsaiModel> models;
  final double progress;
  final bool ready;
  final bool started;
  final String? error;
  final String status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final model = models.last;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final effectiveProgress = ready ? 1.0 : progress.clamp(.02, .98);
    final isDark = FluxColors.isDark(context);

    return FluxGlass(
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 360),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: FluxIcon(
                key: ValueKey('${ready}_icon'),
                icon: ready ? FluxIcons.check : FluxIcons.chip,
                size: 28,
              ),
            ),
            const SizedBox(height: 10),
            Text(model.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              ready
                  ? 'Installed on this device'
                  : 'Best fit · ${model.parameterLabel} · ${model.sizeLabel}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: FluxColors.mutedOf(context),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              child: error != null
                  ? Column(
                      key: const ValueKey('error'),
                      children: [
                        Text(
                          error!,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: FluxColors.mutedOf(context)),
                        ),
                        const SizedBox(height: 10),
                        Semantics(
                          button: true,
                          label: 'Retry model download',
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
                                  'Retry',
                                  style: Theme.of(context).textTheme.labelMedium
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
                          ? 'Model ready'
                          : started
                          ? '$status · ${(effectiveProgress * 100).round()}%'
                          : 'Finding the best model for this device…',
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: FluxColors.mutedOf(context),
                      ),
                    ),
            ),
            if (!ready && started) ...[
              const SizedBox(height: 14),
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
            ],
          ],
        ),
      ),
    );
  }
}

class _Precautions extends StatelessWidget {
  const _Precautions();

  @override
  Widget build(BuildContext context) {
    final items = const [
      'On-device AI prompt processing',
      'Offline chat after model download',
      'Encrypted conversation storage',
      'Designed for battery efficiency',
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
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
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
                    'Finn AI is ready!',
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
                      "You're all set. Finn AI is ready.",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
