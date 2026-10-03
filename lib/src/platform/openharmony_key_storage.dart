import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../features/conversations/conversation_crypto.dart';

/// [SecureKeyStorage] for HarmonyOS, backed by the app's private `filesDir`
/// through the `finn_ai/secure_key` channel implemented in
/// `ohos/entry/src/main/ets/plugins/SecureKeyPlugin.ets`.
///
/// `flutter_secure_storage` cannot be used here: its Dart side throws
/// `UnsupportedError('unsupported_platform')` for every call on OpenHarmony,
/// because `_selectOptions` only knows about
/// Android/iOS/macOS/Linux/Windows/Web. That is why the conversation store did
/// not open at all on the first HarmonyOS run.
///
/// HUKS, HarmonyOS's equivalent of the AndroidKeyStore, cannot hold a *usable*
/// symmetric key on API 24 either — it exposes key management but no
/// `huks.encrypt`, and `cryptoFramework`'s symmetric generator produces only
/// ephemeral keys. The key is therefore sealed by the per-app, per-user sandbox
/// instead. The trade-off is written down in
/// docs/architecture/SECURITY_AND_PRIVACY_ARCHITECTURE.md rather than left
/// implied.
class OpenHarmonyKeyStorage implements SecureKeyStorage {
  const OpenHarmonyKeyStorage();

  static const MethodChannel _channel = MethodChannel('finn_ai/secure_key');

  /// Bounded retry on a dropped reply.
  ///
  /// The OHOS engine (3.41.10-ohos-1.0.1) intermittently loses the reply to a
  /// platform message: the handler runs on the native side (verified in hilog,
  /// including the file write) but Dart sees an empty reply and raises
  /// `MissingPluginException`. `path_provider` and `package_info_plus` reply
  /// reliably; `finn_ai/secure_key` and `finn_ai/flow_schedule` do not, and the
  /// engine's own `handlePlatformMessage` log shows one message being delivered
  /// twice under the same response id, which is consistent with the first reply
  /// consuming the id and the second being discarded.
  ///
  /// All three verbs are idempotent, so retrying cannot corrupt state. When the
  /// engine is fixed this ladder collapses to a single attempt.
  static const List<Duration> _backoff = <Duration>[
    Duration(milliseconds: 80),
    Duration(milliseconds: 200),
    Duration(milliseconds: 500),
  ];

  @override
  Future<Uint8List?> readKey(String alias) async {
    final b64 = await _invoke<String>('read', {'alias': alias});
    if (b64 == null || b64.isEmpty) return null;
    try {
      return Uint8List.fromList(base64Decode(b64));
    } on FormatException catch (error) {
      debugPrint('FINN_SECURE_KEY unreadable key for "$alias": $error');
      return null;
    }
  }

  @override
  Future<void> writeKey(String alias, Uint8List key) async {
    await _invoke<String>('write', {
      'alias': alias,
      'key': base64Encode(key),
    });
  }

  @override
  Future<void> deleteKey(String alias) async {
    await _invoke<String>('delete', {'alias': alias});
  }

  Future<T?> _invoke<T>(String method, Map<String, Object?> args) async {
    for (var attempt = 0; attempt <= _backoff.length; attempt++) {
      try {
        return await _channel.invokeMethod<T>(method, args);
      } on MissingPluginException {
        // A lost reply, not a missing handler: FinnPlugins registers this
        // channel and the native side logs it, so retry rather than give up.
        debugPrint('FINN_SECURE_KEY $method: empty reply, retrying');
        if (attempt < _backoff.length) {
          await Future<void>.delayed(_backoff[attempt]);
        }
      } on PlatformException catch (error) {
        debugPrint(
            'FINN_SECURE_KEY $method failed: ${error.code} ${error.message}');
        return null;
      }
    }
    return null;
  }
}
