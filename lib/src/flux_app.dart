import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helper.dart';

import 'app_state_store.dart';
import 'home/home_shell.dart';
import 'onboarding/onboarding_flow.dart';
import 'inference/qwen_inference.dart';
import 'theme/flux_theme.dart';
import 'widgets/ambient_background.dart';

class FinnBootstrap extends StatefulWidget {
  const FinnBootstrap({super.key});

  @override
  State<FinnBootstrap> createState() => _FinnBootstrapState();
}

class _FinnBootstrapState extends State<FinnBootstrap> {
  late Future<void> _ready = _initialize();
  bool _modelInstalled = false;

  Future<void> _initialize() async {
    await Future.wait([
      AppStateStore.instance.initialize(),
      QwenInference.instance.initialize(),
    ]);

    final inference = QwenInference.instance;
    if (inference.isDeviceSupported) {
      _modelInstalled = await inference.isInstalled(inference.selected);
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

  Future<void> _backgroundWarmup(QwenInference inference) async {
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
          title: 'FinnAI',
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
          builder: FluxTheme.applySystemUi,
          home: _BootstrapErrorPage(
            error: snapshot.error!,
            onRetry: _retryInitialization,
          ),
        );
      }
      if (snapshot.connectionState == ConnectionState.done) {
        return FluxApp(
          onboardingComplete: AppStateStore.instance.onboardingComplete,
          modelInstalled: _modelInstalled,
        );
      }
      return MaterialApp(
        title: 'FinnAI',
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
        builder: FluxTheme.applySystemUi,
        home: Scaffold(
          body: AmbientBackground(
            child: Center(
              child: ListenableBuilder(
                listenable: QwenInference.instance,
                builder: (context, _) {
                  final status = QwenInference.instance.status;
                  return Text(
                    status == 'Ready' ? 'FinnAI' : status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'InstrumentSans',
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      color: FluxColors.inkOf(context).withValues(alpha: .65),
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
  });

  final bool enableModelDownload;
  final bool onboardingComplete;
  final bool modelInstalled;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinnAI',
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
      builder: FluxTheme.applySystemUi,
      home: QwenInference.instance.isDeviceSupported
          ? onboardingComplete
                ? modelInstalled
                      ? const HomeShell()
                      : const SoftwareUpgradeScreen()
                : OnboardingFlow(
                    enableModelDownload: enableModelDownload,
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
                  child: const Icon(Icons.memory_rounded, size: 27),
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
/// user can re-run initialization. English strings are intentional; the
/// localization pass happens in a separate branch.
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
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 27,
                      color: FluxColors.destructive,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'FinnAI could not start',
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Something went wrong while initializing the AI engine. '
                    'Your conversations are safe.',
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
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try again'),
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
