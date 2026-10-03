import 'package:flutter/foundation.dart';

/// Where FinnAI Code gets its answers from.
///
/// [finn] is the on-device model and the default: nothing leaves the phone.
/// Every other provider is opt-in, needs the user's own API key, and sends the
/// conversation (including file contents and command output the agent reads)
/// to that provider's servers.
enum CodeProvider {
  finn,
  openRouter,
  commandCode,
  openCodeZen,
  openCodeGo,
  custom;

  String get id => name;

  static CodeProvider? fromId(String? id) {
    for (final value in values) {
      if (value.name == id) return value;
    }
    return null;
  }

  bool get isLocal => this == finn;

  /// Providers the user adds a key for.
  static List<CodeProvider> get remote =>
      values.where((provider) => !provider.isLocal).toList();

  /// Brand names are not translated. [custom] is named by the screen.
  String get displayName => switch (this) {
        finn => 'FinnAI',
        openRouter => 'OpenRouter',
        commandCode => 'Command Code',
        openCodeZen => 'OpenCode Zen',
        openCodeGo => 'OpenCode Go',
        custom => 'Custom',
      };

  /// The API root, without a trailing slash. Null for [finn] and for [custom],
  /// which the user types in.
  String? get defaultBaseUrl => switch (this) {
        finn => null,
        openRouter => 'https://openrouter.ai/api/v1',
        commandCode => 'https://api.commandcode.ai/provider/v1',
        openCodeZen => 'https://opencode.ai/zen/v1',
        openCodeGo => 'https://opencode.ai/zen/go/v1',
        custom => null,
      };

  bool get baseUrlEditable => this == custom;

  /// A page where the user creates an API key.
  Uri? get keyPage => switch (this) {
        openRouter => Uri.parse('https://openrouter.ai/settings/keys'),
        commandCode => Uri.parse('https://commandcode.ai/settings/keys'),
        openCodeZen => Uri.parse('https://opencode.ai/zen'),
        openCodeGo => Uri.parse('https://opencode.ai/go'),
        _ => null,
      };

  /// A page where the user sees usage and billing, for providers that have no
  /// API to read it from.
  Uri? get billingPage => switch (this) {
        openRouter => Uri.parse('https://openrouter.ai/settings/credits'),
        commandCode => Uri.parse('https://commandcode.ai/settings/billing'),
        openCodeZen => Uri.parse('https://opencode.ai/zen'),
        openCodeGo => Uri.parse('https://opencode.ai/go'),
        _ => null,
      };

  /// True when the provider has an API that reports what is left to spend.
  /// Only OpenRouter does; the others publish no usage endpoint, so the app
  /// says that instead of showing a number it does not have.
  bool get hasAllowanceApi => this == openRouter;

  /// A key is optional for [custom] (a local server may not want one).
  bool get keyRequired => !isLocal && this != custom;
}

/// A model, named well enough to select it and look it up again later.
@immutable
class CodeModelRef {
  const CodeModelRef(this.provider, this.modelId);

  /// The on-device model.
  static const local = CodeModelRef(CodeProvider.finn, 'finnai-on-device');

  final CodeProvider provider;
  final String modelId;

  bool get isLocal => provider.isLocal;

  String encode() => '${provider.id}:$modelId';

  static CodeModelRef? decode(String? value) {
    if (value == null) return null;
    final split = value.indexOf(':');
    if (split <= 0) return null;
    final provider = CodeProvider.fromId(value.substring(0, split));
    final id = value.substring(split + 1);
    if (provider == null || id.isEmpty) return null;
    return provider.isLocal ? local : CodeModelRef(provider, id);
  }

  @override
  bool operator ==(Object other) =>
      other is CodeModelRef &&
      other.provider == provider &&
      other.modelId == modelId;

  @override
  int get hashCode => Object.hash(provider, modelId);
}
