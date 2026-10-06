import 'package:finn_ai/src/features/code/agent/action_runner.dart';
import 'package:finn_ai/src/features/code/agent/code_agent.dart';
import 'package:finn_ai/src/features/code/container/container_installer.dart';
import 'package:finn_ai/src/features/code/container/container_shell.dart';
import 'package:finn_ai/src/features/code/linux/linux_installer.dart';
import 'package:finn_ai/src/features/code/linux/linux_sandbox.dart';
import 'package:finn_ai/src/features/code/providers/code_gateway.dart';
import 'package:finn_ai/src/features/code/providers/code_model.dart';
import 'package:finn_ai/src/features/code/providers/gateways.dart';
import 'package:finn_ai/src/features/code/providers/provider_store.dart';
import 'package:finn_ai/src/features/code/sessions/code_session_store.dart';
import 'package:finn_ai/src/features/code/settings/code_settings_store.dart';
import 'package:finn_ai/src/features/code/ui/code_terminal.dart';

/// Everything FinnAI Code is made of, in one place the screens share.
///
/// The screens take a [CodeServices] so a test can hand them fakes; the real
/// app uses [instance].
class CodeServices {
  CodeServices({
    CodeSessionStore? sessions,
    CodeProviderStore? providers,
    CodeSettingsStore? settings,
    CodeActionRunner? runner,
    CodeGatewayFactory? gatewayFactory,
    ContainerShell? container,
    LinuxSandbox? linux,
  })  : sessions = sessions ?? CodeSessionStore.instance,
        providers = providers ?? CodeProviderStore.instance,
        settings = settings ?? CodeSettingsStore.instance,
        container = container ??
            (runner == null
                ? ContainerShell(installer: ContainerInstaller.instance)
                // Tests that bring a runner never touch storage or a WebView.
                : ContainerShell(
                    installer: ContainerInstaller(artifacts: const []),
                    platformSupported: false,
                  )),
        linux = linux ??
            (runner == null
                ? LinuxSandbox(installer: LinuxInstaller.instance)
                : LinuxSandbox(
                    installer: LinuxInstaller(),
                    locate: () async => null,
                  )) {
    this.runner = runner ??
        WorkspaceActionRunner(
          sessions: this.sessions,
          settings: this.settings,
          container: this.container,
          linux: this.linux,
        );
    agent = CodeAgent(
      sessions: this.sessions,
      settings: this.settings,
      runner: this.runner,
      gatewayFactory: gatewayFactory ?? _gateway,
    );
  }

  static final instance = CodeServices();

  final CodeSessionStore sessions;
  final CodeProviderStore providers;
  final CodeSettingsStore settings;

  /// The emulated Linux container (v86), for platforms where [linux] cannot
  /// run, and its installer.
  final ContainerShell container;

  /// The native Linux sandbox (proot + Alpine), preferred wherever it runs.
  final LinuxSandbox linux;
  late final CodeActionRunner runner;
  late final CodeAgent agent;

  /// The user's own terminal and its scrollback, shared by the panel and the
  /// page.
  late final CodeTerminalLog terminal =
      CodeTerminalLog(sessions: sessions, runner: runner);

  Future<void> initialize() => Future.wait([
        sessions.initialize(),
        providers.initialize(),
        settings.initialize(),
        container.installer.refresh(),
        linux.prepare(),
      ]);

  /// The gateway for whichever model is selected right now.
  Future<CodeModelGateway> _gateway() async {
    final ref = providers.active;
    if (ref.isLocal) return LocalCodeGateway();
    final provider = ref.provider;
    final baseUrl = providers.baseUrlOf(provider);
    if (baseUrl == null) {
      throw StateError('${provider.displayName}: no address');
    }
    // A model picked from a list that has since been cleared still works:
    // its request shape is guessed from its id.
    final model = providers.modelFor(ref) ??
        CodeModel(
          provider: provider,
          id: ref.modelId,
          name: ref.modelId,
          wires: CodeModelParsers.guessWires(provider, ref.modelId),
        );
    return RemoteCodeGateway(
      model: providers.withRememberedWire(model),
      baseUrl: baseUrl,
      client: providers.client,
      apiKey: await providers.keyFor(provider),
      onWire: (wire) => providers.rememberWire(provider, model.id, wire),
    );
  }

  /// Everything FinnAI Code stored, for "delete all data". Returns what could
  /// not be removed.
  Future<List<String>> deleteAll() async {
    await agent.stop();
    await container.stop();
    return [
      ...await linux.installer.deleteStorage(),
      ...await container.installer.deleteStorage(),
      ...await providers.deleteStorage(),
      ...await settings.deleteStorage(),
      ...await sessions.deleteStorage(),
    ];
  }
}
