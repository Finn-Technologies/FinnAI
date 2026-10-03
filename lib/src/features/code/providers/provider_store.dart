import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finn_ai/src/features/code/providers/code_model.dart';
import 'package:finn_ai/src/features/code/providers/code_provider.dart';
import 'package:finn_ai/src/features/code/providers/provider_client.dart';
import 'package:finn_ai/src/features/code/providers/provider_errors.dart';
import 'package:finn_ai/src/features/code/providers/secret_store.dart';

/// What FinnAI Code remembers about one provider. The key itself is not here:
/// it lives in [CodeSecretStore]; only its last four characters are kept so
/// the screen can show "••••1234" without ever reading the secret.
@immutable
class ProviderSettings {
  const ProviderSettings({
    this.baseUrl,
    this.keyHint,
    this.acknowledgedCloud = false,
    this.models = const [],
    this.modelsFetchedAt,
    this.allowance,
    this.wires = const {},
  });

  /// Only used by [CodeProvider.custom].
  final String? baseUrl;
  final String? keyHint;

  /// The user has seen that this provider receives their conversations.
  final bool acknowledgedCloud;
  final List<CodeModel> models;
  final DateTime? modelsFetchedAt;
  final ProviderAllowance? allowance;

  /// The request shape that last worked for a model, by model id.
  final Map<String, CodeWire> wires;

  bool get hasKey => keyHint != null;

  ProviderSettings copyWith({
    String? baseUrl,
    String? Function()? keyHint,
    bool? acknowledgedCloud,
    List<CodeModel>? models,
    DateTime? modelsFetchedAt,
    ProviderAllowance? Function()? allowance,
    Map<String, CodeWire>? wires,
  }) =>
      ProviderSettings(
        baseUrl: baseUrl ?? this.baseUrl,
        keyHint: keyHint != null ? keyHint() : this.keyHint,
        acknowledgedCloud: acknowledgedCloud ?? this.acknowledgedCloud,
        models: models ?? this.models,
        modelsFetchedAt: modelsFetchedAt ?? this.modelsFetchedAt,
        allowance: allowance != null ? allowance() : this.allowance,
        wires: wires ?? this.wires,
      );

  Map<String, Object?> toJson() => {
        if (baseUrl != null) 'baseUrl': baseUrl,
        if (keyHint != null) 'keyHint': keyHint,
        if (acknowledgedCloud) 'ack': true,
        if (models.isNotEmpty) 'models': [for (final m in models) m.toJson()],
        if (modelsFetchedAt != null)
          'modelsAt': modelsFetchedAt!.toIso8601String(),
        if (allowance != null) 'allowance': allowance!.toJson(),
        if (wires.isNotEmpty)
          'wires': {for (final e in wires.entries) e.key: e.value.name},
      };

  static ProviderSettings fromJson(CodeProvider provider, Object? json) {
    if (json is! Map) return const ProviderSettings();
    return ProviderSettings(
      baseUrl: json['baseUrl'] is String ? json['baseUrl'] as String : null,
      keyHint: json['keyHint'] is String ? json['keyHint'] as String : null,
      acknowledgedCloud: json['ack'] == true,
      models: [
        for (final raw in (json['models'] as List?) ?? const [])
          if (CodeModel.fromJson(provider, raw) case final model?) model,
      ],
      modelsFetchedAt: DateTime.tryParse('${json['modelsAt']}'),
      allowance: ProviderAllowance.fromJson(json['allowance']),
      wires: {
        if (json['wires'] is Map)
          for (final entry in (json['wires'] as Map).entries)
            if (entry.key is String)
              for (final wire in CodeWire.values)
                if (wire.name == entry.value) entry.key as String: wire,
      },
    );
  }
}

/// API keys, model lists, allowances and the model FinnAI Code is using.
class CodeProviderStore extends ChangeNotifier {
  CodeProviderStore({
    CodeSecretStore? secrets,
    CodeProviderClient? client,
    this.directoryProvider,
    DateTime Function()? clock,
  })  : _secrets = secrets ?? const PlatformCodeSecretStore(),
        _client = client ?? CodeProviderClient(),
        _clock = clock ?? DateTime.now;

  static final instance = CodeProviderStore();

  final CodeSecretStore _secrets;
  final CodeProviderClient _client;
  final DateTime Function() _clock;

  @visibleForTesting
  final Future<Directory> Function()? directoryProvider;

  final Map<CodeProvider, ProviderSettings> _settings = {};
  final Set<CodeProvider> _loadingModels = {};
  final Set<CodeProvider> _loadingAllowance = {};
  final Map<CodeProvider, ProviderException> _errors = {};
  CodeModelRef _active = CodeModelRef.local;
  bool _initialized = false;

  /// Models are refreshed when older than this.
  static const Duration modelsMaxAge = Duration(hours: 12);

  CodeProviderClient get client => _client;

  bool get initialized => _initialized;

  /// The model new messages go to. The on-device model until the user picks
  /// another.
  CodeModelRef get active => _active;

  ProviderSettings settingsOf(CodeProvider provider) =>
      _settings[provider] ?? const ProviderSettings();

  bool hasKey(CodeProvider provider) => settingsOf(provider).hasKey;

  bool isLoadingModels(CodeProvider provider) =>
      _loadingModels.contains(provider);

  bool isLoadingAllowance(CodeProvider provider) =>
      _loadingAllowance.contains(provider);

  /// The last failure fetching [provider]'s models or allowance, until the
  /// next success.
  ProviderException? errorOf(CodeProvider provider) => _errors[provider];

  /// The API root to call for [provider]; null while a custom server has none.
  String? baseUrlOf(CodeProvider provider) => provider.baseUrlEditable
      ? settingsOf(provider).baseUrl
      : provider.defaultBaseUrl;

  /// A provider is ready to use once it has what it needs: a key, and for a
  /// custom server an address.
  bool isConfigured(CodeProvider provider) {
    if (provider.isLocal) return true;
    if (baseUrlOf(provider) == null) return false;
    return !provider.keyRequired || hasKey(provider);
  }

  CodeModel? modelFor(CodeModelRef ref) {
    for (final model in settingsOf(ref.provider).models) {
      if (model.id == ref.modelId) return model;
    }
    return null;
  }

  /// Models from every provider that is set up, for the picker.
  List<CodeModel> get availableModels => [
        for (final provider in CodeProvider.remote)
          if (isConfigured(provider)) ...settingsOf(provider).models,
      ];

  Future<String?> keyFor(CodeProvider provider) =>
      _secrets.read(_secretName(provider));

  static String _secretName(CodeProvider provider) =>
      'finn_code_key_${provider.id}';

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final file = await _file();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          final providers = decoded['providers'];
          if (providers is Map) {
            for (final provider in CodeProvider.remote) {
              _settings[provider] =
                  ProviderSettings.fromJson(provider, providers[provider.id]);
            }
          }
          final active = CodeModelRef.decode(decoded['active'] as String?);
          if (active != null &&
              (active.isLocal || isConfigured(active.provider))) {
            _active = active;
          }
        }
      }
    } catch (_) {
      // Unreadable settings start empty; keys are untouched.
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- keys

  /// Stores [key] for [provider]. Whitespace is trimmed; an empty key is
  /// refused rather than saved.
  Future<void> saveKey(CodeProvider provider, String key) async {
    final trimmed = key.trim();
    if (provider.isLocal || trimmed.isEmpty) {
      throw ArgumentError('A key cannot be empty.');
    }
    await _secrets.write(_secretName(provider), trimmed);
    _put(
      provider,
      settingsOf(provider).copyWith(
        keyHint: () => trimmed.length <= 4
            ? trimmed
            : trimmed.substring(trimmed.length - 4),
        // A new key may belong to a different account.
        allowance: () => null,
      ),
    );
    _errors.remove(provider);
    await _persist();
  }

  Future<void> removeKey(CodeProvider provider) async {
    await _secrets.delete(_secretName(provider));
    _put(
      provider,
      settingsOf(provider).copyWith(
        keyHint: () => null,
        allowance: () => null,
        models: const [],
        wires: const {},
      ),
    );
    _errors.remove(provider);
    if (_active.provider == provider) _active = CodeModelRef.local;
    await _persist();
  }

  // ----------------------------------------------------------- base URL

  /// Normalises a server address typed by the user, or returns null when it
  /// is not acceptable.
  ///
  /// HTTPS is required, because the key travels in a header. Plain HTTP is
  /// allowed only for a machine on the user's own network or the phone itself
  /// (an Ollama or llama.cpp server), where there is no one to read it.
  static String? validateBaseUrl(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) return null;
    final https = uri.scheme == 'https';
    final http = uri.scheme == 'http';
    if (!https && !(http && isPrivateHost(uri.host))) return null;
    final path = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return uri.replace(path: path).toString();
  }

  /// Loopback, the emulator's host alias, `.local` names and the private IPv4
  /// ranges.
  static bool isPrivateHost(String host) {
    final name = host.toLowerCase();
    if (name == 'localhost' || name.endsWith('.local')) return true;
    final address = InternetAddress.tryParse(name);
    if (address == null) return false;
    if (address.isLoopback) return true;
    if (address.type != InternetAddressType.IPv4) return false;
    final b = address.rawAddress;
    return b[0] == 10 ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
        (b[0] == 192 && b[1] == 168);
  }

  Future<bool> setCustomBaseUrl(String input) async {
    final normalized = validateBaseUrl(input);
    if (normalized == null) return false;
    final current = settingsOf(CodeProvider.custom);
    if (current.baseUrl != normalized) {
      _put(
        CodeProvider.custom,
        ProviderSettings(
          baseUrl: normalized,
          keyHint: current.keyHint,
          acknowledgedCloud: current.acknowledgedCloud,
        ),
      );
      if (_active.provider == CodeProvider.custom) _active = CodeModelRef.local;
      await _persist();
    }
    return true;
  }

  // ------------------------------------------------------------- models

  /// Fetches [provider]'s model list live. On failure the previous list is
  /// kept, the error is recorded in [errorOf] and rethrown.
  Future<List<CodeModel>> refreshModels(CodeProvider provider) async {
    final baseUrl = baseUrlOf(provider);
    if (provider.isLocal || baseUrl == null) return const [];
    _loadingModels.add(provider);
    _errors.remove(provider);
    notifyListeners();
    try {
      final models = await _client.listModels(
        provider,
        baseUrl: baseUrl,
        apiKey: await keyFor(provider),
      );
      _put(
        provider,
        settingsOf(provider).copyWith(
          models: models,
          modelsFetchedAt: _clock(),
        ),
      );
      await _persist();
      return models;
    } on ProviderException catch (error) {
      _errors[provider] = error;
      rethrow;
    } finally {
      _loadingModels.remove(provider);
      notifyListeners();
    }
  }

  /// Refreshes the list only when it is missing or stale.
  Future<void> ensureModels(CodeProvider provider) async {
    final settings = settingsOf(provider);
    final at = settings.modelsFetchedAt;
    final fresh = settings.models.isNotEmpty &&
        at != null &&
        _clock().difference(at) < modelsMaxAge;
    if (fresh || isLoadingModels(provider)) return;
    try {
      await refreshModels(provider);
    } on ProviderException {
      // Recorded in errorOf; the cached list stays usable.
    }
  }

  // ---------------------------------------------------------- allowance

  /// Reads what is left to spend, for providers whose API says. Others have
  /// no endpoint, so this returns null for them.
  Future<ProviderAllowance?> refreshAllowance(CodeProvider provider) async {
    final baseUrl = baseUrlOf(provider);
    if (!provider.hasAllowanceApi || baseUrl == null) return null;
    final key = await keyFor(provider);
    if (key == null || key.isEmpty) return null;
    _loadingAllowance.add(provider);
    _errors.remove(provider);
    notifyListeners();
    try {
      final allowance =
          await _client.openRouterAllowance(baseUrl: baseUrl, apiKey: key);
      _put(
        provider,
        settingsOf(provider).copyWith(allowance: () => allowance),
      );
      await _persist();
      return allowance;
    } on ProviderException catch (error) {
      _errors[provider] = error;
      rethrow;
    } finally {
      _loadingAllowance.remove(provider);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------- selection

  Future<void> acknowledgeCloud(CodeProvider provider) async {
    if (settingsOf(provider).acknowledgedCloud) return;
    _put(provider, settingsOf(provider).copyWith(acknowledgedCloud: true));
    await _persist();
  }

  Future<void> select(CodeModelRef ref) async {
    if (!ref.isLocal && !isConfigured(ref.provider)) return;
    if (_active == ref) return;
    _active = ref;
    notifyListeners();
    await _persist();
  }

  /// Remembers which request shape worked for [modelId].
  void rememberWire(CodeProvider provider, String modelId, CodeWire wire) {
    final current = settingsOf(provider);
    if (current.wires[modelId] == wire) return;
    _put(provider, current.copyWith(wires: {...current.wires, modelId: wire}));
    _persist();
  }

  /// [model] with the remembered request shape moved to the front.
  CodeModel withRememberedWire(CodeModel model) {
    final wire = settingsOf(model.provider).wires[model.id];
    if (wire == null || !model.wires.contains(wire)) return model;
    return CodeModel(
      provider: model.provider,
      id: model.id,
      name: model.name,
      wires: [wire, ...model.wires.where((w) => w != wire)],
      contextLength: model.contextLength,
      free: model.free,
      promptPricePerMillion: model.promptPricePerMillion,
      completionPricePerMillion: model.completionPricePerMillion,
    );
  }

  // -------------------------------------------------------- persistence

  void _put(CodeProvider provider, ProviderSettings settings) {
    _settings[provider] = settings;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(
        jsonEncode({
          'version': 1,
          'active': _active.encode(),
          'providers': {
            for (final entry in _settings.entries)
              entry.key.id: entry.value.toJson(),
          },
        }),
        flush: true,
      );
      await temp.rename(file.path);
    } catch (_) {
      // The choice still applies for this run.
    }
  }

  /// Removes every key and every saved choice. Returns what could not be
  /// removed, for the delete-all report.
  Future<List<String>> deleteStorage() async {
    final failures = <String>[];
    for (final provider in CodeProvider.remote) {
      try {
        await _secrets.delete(_secretName(provider));
      } catch (error) {
        failures.add('FinnAI Code key ${provider.displayName} ($error)');
      }
    }
    _settings.clear();
    _errors.clear();
    _active = CodeModelRef.local;
    notifyListeners();
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (error) {
      failures.add('FinnAI Code providers ($error)');
    }
    return failures;
  }

  Future<File> _file() async {
    final directory = directoryProvider != null
        ? await directoryProvider!()
        : await getApplicationSupportDirectory();
    return File('${directory.path}/code/providers.json');
  }
}
