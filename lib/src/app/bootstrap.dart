import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/l10n/l10n_helper.dart';

import 'package:finn_ai/src/app/app_state_store.dart';
import 'package:finn_ai/src/app/speech_model_addon.dart';
import 'package:finn_ai/src/app/tts_voices_addon.dart';
import 'package:finn_ai/src/app/app_mode_host.dart';
import 'package:finn_ai/src/features/onboarding/model_install.dart';
import 'package:finn_ai/src/features/voice/voice_sheet.dart'
    show voiceSupportedOnPlatform;
import 'package:finn_ai/src/features/onboarding/onboarding_flow.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/shared/config/app_mode.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/ambient_background.dart';
import 'package:finn_ai/src/shared/widgets/finn_window_frame.dart';
import 'package:finn_ai/src/shared/widgets/flux_controls.dart';

class FinnBootstrap extends StatefulWidget {
  const FinnBootstrap({super.key});

  @override
  State<FinnBootstrap> createState() => _FinnBootstrapState();
}

class _FinnBootstrapState extends State<FinnBootstrap> {
  late Future<void> _ready = _initialize();
  bool _modelInstalled = false;

  /// Optional downloads that ride along with the language model.
  ///
  /// Both exist for voice mode, so a platform without it (desktop Linux) skips
  /// them: that is about 560 MB nobody would use.
  final List<InstallAddon> _addons = [
    if (voiceSupportedOnPlatform) ...[
      SpeechModelAddon(),
      TtsVoicesAddon(
        deviceLanguage: PlatformDispatcher.instance.locale.languageCode,
      ),
    ],
  ];

  /// False when an upgrading user is missing an add-on they have not already
  /// been offered, which sends them through the install screen once.
  bool _addonsReady = true;

  Future<void> _initialize() async {
    await Future.wait([
      AppStateStore.instance.initialize(),
      FinnInference.instance.initialize(),
      // Which of FinnAI and FinnAI Code was last open, so the first frame is
      // the right one.
      AppModeController.instance.initialize(),
    ]);

    final inference = FinnInference.instance;
    if (inference.isDeviceSupported) {
      _modelInstalled = await inference.isInstalled(inference.selected);
      _addonsReady = true;
      for (final addon in _addons) {
        if (await addon.shouldOfferOnUpgrade()) _addonsReady = false;
      }
      // Run model download resumption and background accelerator benchmark
      // asynchronously in the background so the home screen boots instantly.
      unawaited(_backgroundWarmup(inference));
    }
  }

  void _retryInitialization() {
    setState(() {
      _ready = _initialize();
    });
  }

  Future<void> _backgroundWarmup(FinnInference inference) async {
    try {
      await inference.resumeInterruptedDownloads();
    } catch (error, stack) {
      debugPrint('FINN_RESUME failed: $error\n$stack');
    }
    if (_modelInstalled && AppStateStore.instance.onboardingComplete) {
      try {
        if (await inference.needsBenchmark()) {
          await inference.optimizeForDevice();
        }
      } catch (error, stack) {
        debugPrint('FINN_BENCH bootstrap failed: $error\n$stack');
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _ready,
        builder: (context, snapshot) {
          // Surface engine bootstrap failures instead of silently falling back
          // to the model-download screen and hiding the root cause.
          if (snapshot.hasError) {
            return MaterialApp(
              onGenerateTitle: (context) => L10n.of(context).appBrandFinnAI,
              debugShowCheckedModeBanner: false,
              theme: FluxTheme.light,
              darkTheme: FluxTheme.dark,
              themeMode: ThemeMode.system,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              builder: finnAppBuilder,
              home: _BootstrapErrorPage(
                error: snapshot.error!,
                onRetry: _retryInitialization,
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.done) {
            return FluxApp(
              onboardingComplete: AppStateStore.instance.onboardingComplete,
              modelInstalled: _modelInstalled && _addonsReady,
              addons: _addons,
            );
          }
          return MaterialApp(
            onGenerateTitle: (context) => L10n.of(context).appBrandFinnAI,
            debugShowCheckedModeBanner: false,
            theme: FluxTheme.light,
            darkTheme: FluxTheme.dark,
            themeMode: ThemeMode.system,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            builder: finnAppBuilder,
            home: Scaffold(
              body: AmbientBackground(
                child: Center(
                  child: ListenableBuilder(
                    listenable: FinnInference.instance,
                    builder: (context, _) {
                      final inference = FinnInference.instance;
                      // Engine statuses are localized at this display layer via
                      // the machine-readable statusKey; the raw engine text is
                      // only a fallback for dynamic/unmapped values.
                      final status = inference.statusKey == FinnStatusKey.ready
                          ? 'FinnAI'
                          : localizedEngineStatus(
                              context,
                              inference.statusKey,
                              inference.status,
                            );
                      return Text(
                        status,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'InstrumentSans',
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                          color:
                              FluxColors.inkOf(context).withValues(alpha: .65),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class FluxApp extends StatelessWidget {
  const FluxApp({
    super.key,
    this.enableModelDownload = true,
    this.onboardingComplete = false,
    this.modelInstalled = true,
    this.addons = const [],
  });

  final bool enableModelDownload;
  final bool onboardingComplete;
  final bool modelInstalled;
  final List<InstallAddon> addons;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => L10n.of(context).appBrandFinnAI,
      debugShowCheckedModeBanner: false,
      theme: FluxTheme.light,
      darkTheme: FluxTheme.dark,
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: finnAppBuilder,
      home: FinnInference.instance.isDeviceSupported
          ? onboardingComplete
              ? modelInstalled
                  ? const AppModeHost()
                  : SoftwareUpgradeScreen(addons: addons)
              : OnboardingFlow(
                  enableModelDownload: enableModelDownload,
                  addons: addons,
                  onComplete: AppStateStore.instance.completeOnboarding,
                )
          : const _UnsupportedDevicePage(),
    );
  }
}

class _UnsupportedDevicePage extends StatelessWidget {
  const _UnsupportedDevicePage();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AmbientBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: FluxColors.surfaceOf(context),
                      ),
                      child: const Center(
                        child: FluxIcon(icon: FluxIcons.cpu, size: 27),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      L10n.of(context).unsupportedTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      L10n.of(context).unsupportedBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: FluxColors.mutedOf(context),
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

/// Shown when engine bootstrap fails so the root cause is visible and the
/// user can re-run initialization.
class _BootstrapErrorPage extends StatelessWidget {
  const _BootstrapErrorPage({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: FluxColors.surfaceOf(context),
                    ),
                    child: Center(
                      child: FluxIcon(
                        icon: FluxIcons.error,
                        size: 27,
                        // destructiveOf, not the light constant: #B3261E
                        // measures 3.21:1 on the dark canvas, which is the
                        // one screen a user only sees when something is
                        // already broken.
                        color: FluxColors.destructiveOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    L10n.of(context).bootstrapErrorTitle,
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    L10n.of(context).bootstrapErrorBody,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: FluxColors.mutedOf(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: SingleChildScrollView(
                      child: Text(
                        '$error',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: FluxColors.mutedOf(context),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: FluxIcon(
                      icon: FluxIcons.refresh,
                      size: 18,
                      color: FluxColors.canvasOf(context),
                    ),
                    label: Text(L10n.of(context).commonTryAgain),
                    style: FilledButton.styleFrom(
                      backgroundColor: FluxColors.inkOf(context),
                      foregroundColor: FluxColors.canvasOf(context),
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
