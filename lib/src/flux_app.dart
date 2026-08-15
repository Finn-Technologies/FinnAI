import 'package:flutter/material.dart';

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
  late final Future<void> _ready = Future.wait([
    AppStateStore.instance.initialize(),
    QwenInference.instance.initialize(),
  ]);

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done) {
        return FluxApp(
          onboardingComplete: AppStateStore.instance.onboardingComplete,
        );
      }
      return MaterialApp(
        title: 'Finn AI',
        debugShowCheckedModeBanner: false,
        theme: FluxTheme.light,
        darkTheme: FluxTheme.dark,
        themeMode: ThemeMode.system,
        builder: FluxTheme.applySystemUi,
        home: Scaffold(
          body: AmbientBackground(
            child: Center(
              child: Text(
                'Finn AI',
                style: TextStyle(
                  fontFamily: 'InstrumentSans',
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: FluxColors.inkOf(context).withValues(alpha: .65),
                ),
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
  });

  final bool enableModelDownload;
  final bool onboardingComplete;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finn AI',
      debugShowCheckedModeBanner: false,
      theme: FluxTheme.light,
      darkTheme: FluxTheme.dark,
      themeMode: ThemeMode.system,
      builder: FluxTheme.applySystemUi,
      home: QwenInference.instance.isDeviceSupported
          ? onboardingComplete
                ? const HomeShell()
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
                  'Finn AI cannot run on this device',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  'Finn AI requires at least 3 GB of RAM and a 64-bit ARM '
                  'processor to run local models reliably. No model has been '
                  'downloaded.',
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
