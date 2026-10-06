import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:finn_ai/src/app/app_mode_host.dart';
import 'package:finn_ai/src/features/onboarding/artwork_card.dart';
import 'package:finn_ai/src/features/onboarding/context_choose_page.dart';
import 'package:finn_ai/src/features/onboarding/step_transition.dart';
import 'package:finn_ai/src/features/onboarding/welcome_morph.dart';
import 'package:finn_ai/src/features/onboarding/wide_step.dart';
import 'package:finn_ai/src/features/onboarding/context_consent_store.dart';
import 'package:finn_ai/src/inference/device_profile.dart';
import 'package:finn_ai/src/features/onboarding/model_install.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/shared/config/legal_config.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    this.enableModelDownload = true,
    this.onComplete,
    this.consentStore,
    this.addons = const [],
  });

  final bool enableModelDownload;
  final Future<void> Function()? onComplete;

  /// Optional downloads fetched along with the language model.
  final List<InstallAddon> addons;

  /// Overrides the process-wide [ContextConsentStore]. The consent step reads
  /// and writes it, and a widget test needs to stand one up against a
  /// temporary directory rather than the real app-support path.
  final ContextConsentStore? consentStore;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();

  /// Welcome (0) to the first step (1): the welcome card growing into the
  /// step's artwork card. Its own motion, not the PageView's (see
  /// [WelcomeMorphPage]).
  /// The steps a running change goes between (see [StepTransition]).
  final _span = ValueNotifier<(int, int)?>(null);

  late final AnimationController _welcome = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  final _modelInstallerKey = GlobalKey<_AutomaticModelPageState>();
  bool _modelInstallRequested = false;

  void _to(int page) {
    if (page < 0) return;
    if (page > 5) {
      _finish();
      return;
    }
    HapticFeedback.selectionClick();
    final reduced = MediaQuery.disableAnimationsOf(context);
    final from = (_pageController.page ?? 0).round();
    if (!reduced && from == 0 && page == 1) {
      // The welcome card grows into the step's card, then the real step
      // takes over the frame it was already drawing.
      _welcome.animateTo(1, curve: Curves.easeOutCubic).whenComplete(() {
        if (mounted && _welcome.value == 1) _pageController.jumpToPage(1);
      });
    } else if (!reduced && from == 1 && page == 0) {
      _welcome.value = 1;
      _pageController.jumpToPage(0);
      _welcome.animateBack(0, curve: Curves.easeInOutCubic);
    } else {
      _span.value = (from, page);
      _pageController
          .animateToPage(
            page,
            duration:
                reduced ? Duration.zero : const Duration(milliseconds: 520),
            curve: Curves.easeInOutCubic,
          )
          .whenComplete(() => _span.value = null);
    }
    if (page == 2 && widget.enableModelDownload) {
      if (!_modelInstallRequested) {
        setState(() => _modelInstallRequested = true);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _modelInstallerKey.currentState?.start();
      });
    }
    if (page >= 3 && widget.enableModelDownload) {
      // Give the mmap-backed engine time to load before the first prompt on
      // devices with ample RAM; entry/low-memory devices skip the eager prewarm.
      final profile = FinnInference.instance.deviceProfile;
      if (profile == null || !DeviceProfiler.isLowEnd(profile)) {
        unawaited(FinnInference.instance.prewarm());
      }
    }
  }

  void _finish() {
    final persist = widget.onComplete;
    if (persist != null) unawaited(persist());
    Navigator.of(context).pushReplacement(_blurRoute(const AppModeHost()));
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
              child: ScaleTransition(
                scale: Tween<double>(begin: .985, end: 1).animate(curved),
                alignment: Alignment.bottomCenter,
                child: page,
              ),
            ),
          );
        },
      );

  @override
  void dispose() {
    _welcome.dispose();
    _span.dispose();
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
            WelcomeMorphPage(
              progress: _welcome,
              artwork: FigmaAssets.artworkPrivacy,
              stepTitle: L10n.of(context).onboardingPrivacyTitle,
              step: _PrivacyPage(onBack: () {}, onNext: () {}),
              onAdvance: () => _to(1),
            ),
            for (final (i, step) in <Widget>[
              _PrivacyPage(onBack: () => _to(0), onNext: () => _to(2)),
              _AutomaticModelPage(
                key: _modelInstallerKey,
                startRequested: _modelInstallRequested,
                addons: widget.addons,
                onBack: () => _to(1),
                onNext: () => _to(3),
              ),
              _ConsentPage(
                store: widget.consentStore,
                onBack: () => _to(2),
                // Choosing what to share only makes sense after a "Yes".
                onNext: () => _to(
                  (widget.consentStore ?? ContextConsentStore.instance).granted
                      ? 4
                      : 5,
                ),
              ),
              ContextChoosePage(
                store: widget.consentStore,
                onBack: () => _to(3),
                onNext: () => _to(5),
              ),
              _FinishPage(onDone: _finish),
            ].indexed)
              StepTransition(
                controller: _pageController,
                index: i + 1,
                span: _span,
                child: step,
              ),
          ],
        ),
      ),
    );
  }
}

/// One step of the onboarding flow: artwork card, copy, bottom bar.
///
/// Laid out on the design's 420x912 canvas; the card keeps the 380x660 aspect
/// while the control bar stays pinned to the bottom edge.
class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.artwork,
    required this.title,
    this.onBack,
    this.twoLineTitle = false,
    this.body,
    this.bodyHeight = 100,
    this.scrollBody = true,
    this.bodyMaxFloor = 0,
    this.progress = 0,
    this.backEnabled = true,
    this.onNext,
    this.footer,
    this.footerHint,
  });

  final String artwork;
  final String title;
  final VoidCallback? onBack;

  /// Titles that wrap to two lines sit a little lower in the design's card.
  final bool twoLineTitle;

  /// Copy or controls shown between the card and the bottom bar.
  final Widget? body;

  /// Budget [body] is expected to fit in: longer copy shrinks the card
  /// rather than overflowing. Must over-estimate when the body holds the
  /// only tappable controls, or they land below the fold.
  final double bodyHeight;

  /// True wraps [body] in a scroll view (prose). A body with its own scroll
  /// region sets this false to avoid unbounded nested scroll views.
  final bool scrollBody;

  /// Smallest the body region may get: below this the card keeps shrinking
  /// instead, since losing artwork beats losing the answer.
  final double bodyMaxFloor;

  /// Filled quarters of the step bar (0 on the steps that carry no bar).
  final int progress;
  final bool backEnabled;
  final VoidCallback? onNext;

  /// Replaces the whole control bar. The final step ends on a single
  /// full-width action instead of step navigation.
  final Widget? footer;

  /// Shown directly above the control bar when the step cannot advance yet.
  final String? footerHint;

  @override
  Widget build(BuildContext context) {
    // Edge-to-edge draws under the system bars, so the page reserves them:
    // card below the status bar, controls above the nav bar plus a lift.
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomReserve = FluxBottomInset.bottomOf(context);
    const lift = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (wideStepFits(constraints)) {
          return WideStepLayout(
            artwork: artwork,
            title: title,
            body: this.body,
            scrollBody: scrollBody,
            twoLineTitle: twoLineTitle,
            progress: progress,
            backEnabled: backEnabled,
            onBack: onBack,
            onNext: onNext,
            footer: footer,
            footerHint: footerHint,
          );
        }
        final avail = constraints.maxHeight - topInset - bottomReserve;
        final sy = (avail / 912).clamp(.6, 1.0);
        final cardWidth = math.max(
          0.0,
          math.min(380.0, constraints.maxWidth - 40),
        );
        final hint = footerHint;
        final hintHeight = hint == null ? 0.0 : 20.0;
        const controlsHeight = 60.0;
        const gap = 20.0;
        // Card yields first: losing artwork is cosmetic, losing the answer
        // means the step cannot be completed.
        final chrome = topInset +
            bottomReserve +
            lift +
            3 * gap * sy +
            controlsHeight +
            hintHeight;
        final budget = math.max(0.0, constraints.maxHeight - chrome);
        final minCard = 120.0 * sy;
        final cardHeight = math.max(
          0.0,
          math.min(
              cardWidth * 660 / 380, math.max(minCard, budget - bodyHeight)),
        );
        final bodyMax =
            math.max(bodyMaxFloor, math.max(0.0, budget - cardHeight));
        final body = this.body;
        // Drawn under the welcome morph: its card stands in for this one.
        final reveal = StepReveal.maybeOf(context);
        Widget enter(Widget child, double start) =>
            reveal?.enter(child, start: start) ?? child;
        return ColoredBox(
          color: FluxColors.cardOf(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(height: topInset + gap * sy),
                Center(
                  child: SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    key: reveal?.cardKey,
                    child: Opacity(
                      opacity: reveal == null ? 1 : 0,
                      child: OnboardingArtworkCard(
                        artwork: artwork,
                        title: title,
                        twoLineTitle: twoLineTitle,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: gap * sy),
                if (body != null)
                  enter(
                      Center(
                        child: SizedBox(
                          width: cardWidth,
                          height: bodyMax,
                          child: scrollBody
                              ? Align(
                                  alignment: Alignment.topLeft,
                                  child: SingleChildScrollView(child: body),
                                )
                              : body,
                        ),
                      ),
                      .45),
                const Spacer(),
                if (hint != null)
                  SizedBox(
                    height: hintHeight,
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 13,
                          height: 1.2,
                          color: FluxColors.secondaryInkOf(context),
                        ),
                      ),
                    ),
                  ),
                enter(
                    Center(
                      child: SizedBox(
                        width: cardWidth,
                        child: footer ??
                            _StepControls(
                              progress: progress,
                              backEnabled: backEnabled,
                              onBack: onBack,
                              onNext: onNext,
                            ),
                      ),
                    ),
                    .6),
                SizedBox(height: gap * sy + bottomReserve + lift),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Back, step progress and next: the control bar every step shares.
class _StepControls extends StatelessWidget {
  const _StepControls({
    required this.progress,
    required this.backEnabled,
    required this.onBack,
    this.onNext,
  });

  final int progress;
  final bool backEnabled;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 60,
        child: Row(
          children: [
            _CircleControl(
              key: const ValueKey('onboarding-back'),
              semanticLabel: L10n.of(context).commonBack,
              onTap: backEnabled ? onBack : null,
              background: FluxColors.tileOf(context),
              foreground: FluxColors.inkOf(context),
              mirrored: true,
            ),
            Expanded(
              child: Center(
                // The design's bar is a fixed 200px; on narrow phones it
                // scales down rather than pushing the circles off the row.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _StepProgressBar(quarters: progress),
                ),
              ),
            ),
            _CircleControl(
              key: const ValueKey('onboarding-next'),
              semanticLabel: L10n.of(context).commonNext,
              onTap: onNext,
              background: FluxColors.actionOf(context),
              foreground: FluxColors.actionInkOf(context),
            ),
          ],
        ),
      );
}

/// A single circular control from the design's bottom bar.
class _CircleControl extends StatelessWidget {
  const _CircleControl({
    super.key,
    required this.semanticLabel,
    required this.onTap,
    required this.background,
    required this.foreground,
    this.mirrored = false,
  });

  final String semanticLabel;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;

  /// Draws the arrow pointing left instead of right.
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : .38,
        child: FluxPressScale(
          enabled: enabled,
          child: Material(
            color: background,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox.square(
                dimension: 60,
                child: Center(
                  child: Transform.rotate(
                    angle: mirrored ? math.pi : 0,
                    child: FigmaSvg(
                      asset: FigmaAssets.stepNext,
                      width: 36,
                      height: 36,
                      color: foreground,
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
}

/// Step progress: the filled span, an 8px gap, then the remaining track.
class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({required this.quarters});

  /// Filled quarters of the 200px track, 1..4.
  final int quarters;

  static const double _track = 200;
  static const double _gap = 8;

  /// What the bar last showed. A step's bar grows on from the previous
  /// step's instead of from empty, so the bar reads as one bar filling up
  /// while the steps fade through each other.
  static double _shown = 0;

  @override
  Widget build(BuildContext context) {
    // The design carves the gap out of the fill so each step lands on a
    // quarter of the track: 46 / 96 / 146 px for steps one to three. The bar
    // fills up to that point as each step appears, so the flow reads as
    // progress rather than as a bar that is simply replaced.
    final target = (_track * quarters / 4 - 4).clamp(0.0, _track);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _shown, end: target),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, filled, _) {
        _shown = filled;
        final rest =
            (_track - filled - (filled > 0 && filled < _track ? _gap : 0))
                .clamp(0.0, _track);
        Widget bar(Color color) => ClipRRect(
              borderRadius: BorderRadius.circular(FluxRadius.pill),
              child: ColoredBox(color: color),
            );
        return SizedBox(
          width: _track,
          height: 6,
          child: Row(
            // Stretch so the bars fill the track's height: a childless
            // ColoredBox collapses to nothing under loose cross-axis
            // constraints.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (filled > 0)
                SizedBox(width: filled, child: bar(FluxColors.inkOf(context))),
              if (filled > 0 && rest > 0) const SizedBox(width: _gap),
              if (rest > 0)
                SizedBox(width: rest, child: bar(FluxColors.tileOf(context))),
            ],
          ),
        );
      },
    );
  }
}

/// Privacy: what leaves the device, and the link to the full policy.
class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage({required this.onBack, required this.onNext});

  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _StepPage(
        artwork: FigmaAssets.artworkPrivacy,
        title: L10n.of(context).onboardingPrivacyTitle,
        bodyHeight: 150,
        progress: 1,
        onBack: onBack,
        onNext: onNext,
        body: const _PrivacyBody(),
      );
}

/// The privacy paragraph: lead line in ink, body in muted ink and the policy
/// link in the design's blue, all flowing as one paragraph.
class _PrivacyBody extends StatefulWidget {
  const _PrivacyBody();

  @override
  State<_PrivacyBody> createState() => _PrivacyBodyState();
}

class _PrivacyBodyState extends State<_PrivacyBody> {
  late final TapGestureRecognizer _policyTap = TapGestureRecognizer()
    ..onTap = _openPolicy;

  @override
  void dispose() {
    _policyTap.dispose();
    super.dispose();
  }

  Future<void> _openPolicy() async {
    if (!LegalConfig.hasPrivacyPolicyUrl) return;
    final uri = Uri.parse(LegalConfig.privacyPolicyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final ink = FluxColors.inkOf(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: l10n.onboardingPrivacyLead, style: _bodyStyle(ink)),
          TextSpan(
            text: '\n${l10n.onboardingPrivacyBody}',
            style: _bodyStyle(ink.withValues(alpha: .5)),
          ),
          TextSpan(
            text: l10n.onboardingPrivacyLink,
            style: _bodyStyle(FluxColors.linkOf(context)),
            recognizer: _policyTap,
          ),
        ],
      ),
    );
  }
}

/// The step copy's typography: 20px Instrument Sans on a 1.2 line height.
TextStyle _bodyStyle(Color color) => TextStyle(
      fontFamily: 'Geist',
      fontSize: 20,
      height: 1.2,
      fontWeight: FontWeight.w400,
      color: color,
    );

class _AutomaticModelPage extends StatefulWidget {
  const _AutomaticModelPage({
    super.key,
    required this.startRequested,
    required this.addons,
    required this.onBack,
    required this.onNext,
  });

  final bool startRequested;
  final List<InstallAddon> addons;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  State<_AutomaticModelPage> createState() => _AutomaticModelPageState();
}

class _AutomaticModelPageState extends State<_AutomaticModelPage> {
  final _inference = FinnInference.instance;
  late final _install = ModelInstall(
    addons: widget.addons,
    onChanged: _changed,
  );
  bool _started = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _install.attach();
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
    _install.detach();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> start() async {
    debugPrint('FINN_START_CALLED: started=$_started, ready=$_ready');
    if (_started || _ready) return;
    setState(() {
      _started = true;
      _error = null;
      _install.progress = .02;
    });
    _inference.useAutomaticSelection();
    // Resolved before the first await so no BuildContext is used across an
    // async gap.
    final verificationFailedMessage = L10n.of(
      context,
    ).onboardingInstallVerificationFailed;
    try {
      await _install.run(
        verificationFailedMessage: verificationFailedMessage,
        isCancelled: () => !mounted,
      );
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
        _install.progress = 1;
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
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _StepPage(
      artwork: FigmaAssets.artworkDownload,
      title: _ready
          ? l10n.onboardingInstallTitleReady
          : l10n.onboardingInstallTitleInstalling,
      twoLineTitle: !_ready,
      bodyHeight: 160,
      progress: 2,
      onBack: widget.onBack,
      backEnabled: _ready,
      onNext: _ready ? widget.onNext : null,
      body: _DownloadStatus(
        install: _install,
        ready: _ready,
        started: _started,
        error: _error,
        statusKey: _inference.statusKey,
        status: _inference.status,
        onRetry: start,
      ),
    );
  }
}

/// The download step's live status: the lead line, the progress ring and the
/// transfer read-out (percent, speed, bytes, ETA) from the design.
class _DownloadStatus extends StatelessWidget {
  const _DownloadStatus({
    required this.install,
    required this.ready,
    required this.started,
    required this.error,
    required this.statusKey,
    required this.status,
    required this.onRetry,
  });

  /// Progress and bytes from one place, so the read-out agrees with itself.
  final ModelInstall install;
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
    final l10n = L10n.of(context);
    final inference = FinnInference.instance;
    final ink = FluxColors.inkOf(context);
    final muted = ink.withValues(alpha: .5);

    if (error != null) {
      // The design's "Download paused": progress is kept, and it resumes.
      final pct = (install.progress * 100).round().clamp(0, 100);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.onboardingDownloadPausedBody, style: _bodyStyle(ink)),
          const SizedBox(height: 10),
          Text(
            '${l10n.onboardingProgressPercent('$pct')} '
            '${localizedEngineStatus(context, statusKey, status)}',
            style: _readoutStyle(muted),
          ),
          Text(l10n.onboardingDownloadPausedNote, style: _bodyStyle(muted)),
          const SizedBox(height: 16),
          _RetryPill(onTap: onRetry),
        ],
      );
    }

    final totalBytes = install.totalBytes;
    final downloading =
        started && inference.phase == InferencePhase.downloading;
    final percent =
        (ready ? 100 : (install.progress * 100).round()).clamp(0, 100);
    final speed = inference.downloadSpeedLabel;
    final meta = [
      if (downloading && speed != null) speed,
      if (started && !ready && install.receivedBytes > 0)
        '${_formatBytes(install.receivedBytes)}/'
            '${_formatBytes(totalBytes)}',
    ].join('. ');
    final eta = inference.downloadEta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: ready
                    ? l10n.onboardingInstallReadyForChat
                    : l10n.onboardingDownloadLead,
                style: _bodyStyle(ink),
              ),
              if (!ready)
                TextSpan(
                  text: ' ${l10n.onboardingDownloadNote}',
                  style: _bodyStyle(muted),
                ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DownloadRing(value: ready ? 1 : install.progress),
            const SizedBox(width: 16),
            Expanded(
              child: started
                  ? Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: l10n.onboardingProgressPercent(
                              percent.toString(),
                            ),
                            style: _readoutStyle(ink),
                          ),
                          if (meta.isNotEmpty)
                            TextSpan(
                              text: ' $meta',
                              style: _readoutStyle(muted),
                            ),
                          if (eta != null) ...[
                            TextSpan(
                              text: '\n${_formatEta(eta)}',
                              style: _readoutStyle(ink),
                            ),
                            TextSpan(
                              text: ' ${l10n.onboardingProgressEtaTail}',
                              style: _readoutStyle(muted),
                            ),
                          ],
                        ],
                      ),
                    )
                  : Text(
                      localizedEngineStatus(context, statusKey, status),
                      style: _readoutStyle(muted),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The design's download ring: a 44px donut with butt caps, drawn from the top
/// of the circle.
class _DownloadRing extends StatelessWidget {
  const _DownloadRing({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final ink = FluxColors.inkOf(context);
    return SizedBox.square(
      dimension: 44,
      child: CircularProgressIndicator(
        value: value.clamp(0.0, 1.0),
        strokeWidth: 7.5,
        strokeCap: StrokeCap.butt,
        color: ink,
        backgroundColor: ink.withValues(alpha: .1),
      ),
    );
  }
}

/// Dark pill used when a download failed and the user can start it again.
class _RetryPill extends StatelessWidget {
  const _RetryPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: L10n.of(context).onboardingInstallRetryLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: FluxColors.actionOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.pill),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(FluxRadius.pill),
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: Text(
                    L10n.of(context).commonRetry,
                    style: _readoutStyle(FluxColors.actionInkOf(context)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// The transfer read-out's typography: 18px on the design's 22px line box.
TextStyle _readoutStyle(Color color) => TextStyle(
      fontFamily: 'Geist',
      fontSize: 18,
      height: 1.22,
      fontWeight: FontWeight.w400,
      color: color,
    );

class SoftwareUpgradeScreen extends StatefulWidget {
  const SoftwareUpgradeScreen({super.key, this.addons = const []});

  /// Optional downloads fetched along with the language model.
  final List<InstallAddon> addons;

  @override
  State<SoftwareUpgradeScreen> createState() => _SoftwareUpgradeScreenState();
}

/// Blocking screen shown when a returning user's required model is missing —
/// for example after the app upgrades from the retired tiered catalog to the
/// single local model. It reuses the onboarding download panel and only
/// continues to the home screen once the new model is installed.
class _SoftwareUpgradeScreenState extends State<SoftwareUpgradeScreen> {
  final _inference = FinnInference.instance;
  late final _install = ModelInstall(
    addons: widget.addons,
    onChanged: _changed,
  );
  bool _started = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _install.attach();
    WidgetsBinding.instance.addPostFrameCallback((_) => start());
  }

  @override
  void dispose() {
    _install.detach();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> start() async {
    if (_started || _ready) return;
    setState(() {
      _started = true;
      _error = null;
      _install.progress = .02;
    });
    _inference.useAutomaticSelection();
    // Resolved before the first await so no BuildContext is used across an
    // async gap.
    final verificationFailedMessage = L10n.of(
      context,
    ).onboardingInstallVerificationFailed;
    try {
      await _install.run(
        verificationFailedMessage: verificationFailedMessage,
        isCancelled: () => !mounted,
      );
      // Measure the best CPU/GPU/NPU backend now that the new model is ready.
      // Bounded like the onboarding path so a slow benchmark cannot keep the
      // upgrade screen stuck before the user can chat.
      try {
        await _inference.optimizeForDevice().timeout(
              const Duration(seconds: 35),
            );
      } catch (e) {
        debugPrint('FINN_OPTIMIZE timed out or failed: $e');
      }
      if (!mounted) return;
      setState(() {
        _install.progress = 1;
        _ready = true;
      });
      unawaited(_inference.prewarm());
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted) _enterHome();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _started = false;
        _error = _inference.status;
      });
    }
  }

  void _enterHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, animation, __) => const AppModeHost(),
        transitionsBuilder: (context, animation, _, page) =>
            FadeTransition(opacity: animation, child: page),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      body: _StepPage(
        artwork: FigmaAssets.artworkDownload,
        title: _ready
            ? l10n.onboardingInstallTitleReady
            : l10n.onboardingInstallTitleInstalling,
        twoLineTitle: !_ready,
        bodyHeight: 160,
        progress: 2,
        backEnabled: false,
        onNext: _ready ? _enterHome : null,
        body: _DownloadStatus(
          install: _install,
          ready: _ready,
          started: _started,
          error: _error,
          statusKey: _inference.statusKey,
          status: _inference.status,
          onRetry: start,
        ),
      ),
    );
  }
}

/// Asks whether FinnAI may use context from this device and records the
/// answer. The question is the card's title; the two answers are the step's
/// body, with the flow's own Next control still doing the advancing.
class _ConsentPage extends StatefulWidget {
  const _ConsentPage({
    required this.onBack,
    required this.onNext,
    this.store,
  });

  final VoidCallback onBack;
  final VoidCallback onNext;
  final ContextConsentStore? store;

  @override
  State<_ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<_ConsentPage> {
  /// Null until the user answers, which gates the step's Next control: the
  /// step cannot be passed without a decision.
  bool? _granted;

  ContextConsentStore get _consent =>
      widget.store ?? ContextConsentStore.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_consent.initialize());
  }

  Future<void> _answer(bool granted) async {
    setState(() => _granted = granted);
    await _consent.setGranted(granted);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    // A required answer: the control is disabled until one is given, rather
    // than accepting the tap and quietly defaulting.
    final canAdvance = _granted != null;
    return _StepPage(
      artwork: FigmaAssets.artworkConsent,
      title: l10n.onboardingConsentTitle,
      twoLineTitle: true,
      // Measured: `_StepPage` gives the artwork whatever the body leaves, so
      // understating this pushes the answers below the fold.
      bodyHeight: 250,
      // This body pins the answers to the bottom of the region and scrolls the
      // explanation above them, so `_StepPage` must not wrap it again.
      scrollBody: false,
      // What the pinned answer row needs: 112 for the cards plus the 14px
      // gap above them. Below this the row overflows, so the artwork card has
      // to keep shrinking instead — a landscape phone's 390px of height cannot
      // hold a 250px body and a 160px card, and the row is what matters.
      bodyMaxFloor: 126,
      progress: 3,
      onBack: widget.onBack,
      onNext: canAdvance ? widget.onNext : null,
      footerHint: canAdvance ? null : l10n.onboardingConsentRequiredHint,
      // The answers are pinned to the bottom of the body region and the
      // explanation takes what is left, scrolling if it must. A plain Column
      // pushed them below the fold the moment the copy wrapped one line more —
      // which is what happened once this step grew a sentence, and would have
      // happened again in every language whose translation runs longer.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Text(
                l10n.onboardingConsentBody,
                style: _bodyStyle(FluxColors.secondaryInkOf(context)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ConsentChoice(
                  label: l10n.commonYes,
                  selected: _granted == true,
                  cornerRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                    bottomLeft: Radius.circular(25),
                    bottomRight: Radius.circular(10),
                  ),
                  onTap: () => _answer(true),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _ConsentChoice(
                  label: l10n.commonNo,
                  selected: _granted == false,
                  cornerRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(25),
                  ),
                  onTap: () => _answer(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One of the two consent answers: a large tappable card that fills in once it
/// is the recorded choice.
class _ConsentChoice extends StatelessWidget {
  const _ConsentChoice({
    required this.label,
    required this.selected,
    required this.cornerRadius,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final BorderRadius cornerRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background =
        selected ? FluxColors.actionOf(context) : FluxColors.tileOf(context);
    final foreground =
        selected ? FluxColors.actionInkOf(context) : FluxColors.inkOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: FluxPressScale(
        child: Material(
          color: background,
          borderRadius: cornerRadius,
          child: InkWell(
            onTap: onTap,
            borderRadius: cornerRadius,
            child: SizedBox(
              height: 112,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The single full-width action that ends the flow.
class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => StepEnterKey(
        onEnter: onTap,
        child: Semantics(
          button: true,
          label: label,
          onTap: onTap,
          excludeSemantics: true,
          child: FluxPressScale(
            child: Material(
              color: FluxColors.actionOf(context),
              borderRadius: BorderRadius.circular(60),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(60),
                child: SizedBox(
                  height: 60,
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.w400,
                        color: FluxColors.actionInkOf(context),
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

/// The final step: the artwork card, the ready copy and the single full-width
/// action that ends the flow.
class _FinishPage extends StatelessWidget {
  const _FinishPage({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final ink = FluxColors.inkOf(context);
    return _StepPage(
      artwork: FigmaAssets.artworkFinish,
      title: l10n.onboardingReadyTitle,
      bodyHeight: 116,
      backEnabled: false,
      body: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: l10n.onboardingReadyLead, style: _bodyStyle(ink)),
            TextSpan(
              text: '\n${l10n.onboardingReadyBody}',
              style: _bodyStyle(ink.withValues(alpha: .5)),
            ),
          ],
        ),
      ),
      footer: _PrimaryActionButton(
        label: l10n.onboardingStartUsing,
        onTap: onDone,
      ),
    );
  }
}

/// Compact human-readable size used by the download read-out, e.g. "1.28GB" or
/// "668MB" — the design sets the numbers tight against the slash.
String _formatBytes(int bytes) {
  if (bytes >= 1000 * 1000 * 1000) {
    return '${(bytes / 1000 / 1000 / 1000).toStringAsFixed(2)} GB';
  }
  return '${(bytes / 1000 / 1000).round()} MB';
}

/// Remaining download time in the design's clock form: "3:41", "1:05:12".
String _formatEta(Duration eta) {
  final seconds = (eta.inSeconds % 60).toString().padLeft(2, '0');
  if (eta.inHours > 0) {
    final minutes = (eta.inMinutes % 60).toString().padLeft(2, '0');
    return '${eta.inHours}:$minutes:$seconds';
  }
  return '${eta.inMinutes}:$seconds';
}
