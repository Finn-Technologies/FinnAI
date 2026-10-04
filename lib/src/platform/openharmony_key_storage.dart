import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../features/conversations/conversation_crypto.dart';
import 'platform_target.dart';

/// [SecureKeyStorage] for HarmonyOS, backed by the app's private `filesDir`.
///
/// ## Why this is plain `dart:io` and not a method channel
///
/// This used to talk to `finn_ai/secure_key`, implemented in
/// `ohos/entry/src/main/ets/plugins/SecureKeyPlugin.ets`. That plugin did
/// nothing an ArkTS file API cannot do from Dart: open a file in the app's own
/// sandbox, read 32 bytes, write 32 bytes.
///
/// It also did not work. The Flutter OHOS fork (3.41.10-ohos-1.0.1, engine
/// `9161402dc0e1`) delivers some platform messages **twice under the same
/// response id**: the handler runs and its side effects land, but Dart receives
/// an empty reply and raises `MissingPluginException`. `finn_ai/secure_key` was
/// one of the two affected channels, so the key read-back verification in
/// `KeyedConversationCrypto.prepare` never saw a reply, `prepare()` threw, and
/// conversation history could not be persisted across restarts on HarmonyOS at
/// all — the store latched its read-only storage-error banner.
///
/// `path_provider` and `package_info_plus` answer reliably on the same engine,
/// which is the tell: it is the *number of channels touching a given area*, not
/// the platform, that decides whether the fork's bug bites. Removing this one
/// removes the failure mode instead of retrying around it, and it is the fix
/// `docs/guides/OHOS_BUILD.md` recommends. `finn_ai/flow_schedule` is still
/// exposed; see that document for what remains.
///
/// ## Why a file and not HUKS
///
/// HarmonyOS 6.1.1 (API 24) offers no sealed *and* usable symmetric key:
/// `huks` exposes key management but no `huks.encrypt`/`decrypt`,
/// `cryptoFramework`'s symmetric generator takes no parameters and returns an
/// ephemeral key, and `huks.importKeyItem`/`exportKeyItem` accept asymmetric
/// keys only. The key is therefore sealed by the per-app, per-user sandbox
/// instead — no other app and no other user can reach `filesDir`. The full
/// trade-off is in `docs/architecture/SECURITY_AND_PRIVACY_ARCHITECTURE.md`.
///
/// ## On-disk format
///
/// Raw key bytes, at `<filesDir>/finn_secure_key_<alias>`. That is byte-for-byte
/// what `SecureKeyPlugin.ets` wrote, so a key file left by an earlier build is
/// picked up by this implementation without a migration.
class OpenHarmonyKeyStorage implements SecureKeyStorage {
  OpenHarmonyKeyStorage({this.directoryOverride});

  /// Forces the key directory. Tests use this; production resolves the real
  /// sandbox directory at first use.
  @visibleForTesting
  final Directory? directoryOverride;

  /// `path_provider` has no OHOS plugin, so this channel is answered by
  /// `PathProviderPlugin.ets`, which returns `context.filesDir` for
  /// `getApplicationSupportPath`. Unlike `finn_ai/secure_key` it replies
  /// reliably on the OHOS fork, so it is worth one call to learn the true
  /// sandbox path; [ohosSandboxFilesDir] covers the case where it does not.
  static const MethodChannel _pathChannel =
      MethodChannel('plugins.flutter.io/path_provider');

  static const String _filePrefix = 'finn_secure_key_';

  Directory? _cachedDirectory;

  @override
  Future<Uint8List?> readKey(String alias) async {
    try {
      final file = await _fileFor(alias);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } on FileSystemException catch (error) {
      // An unreadable key reads as "absent" rather than throwing: `prepare()`
      // regenerates, and the read-back verification then decides whether the
      // store is usable.
      debugPrint('FINN_SECURE_KEY read failed for "$alias": ${error.message}');
      return null;
    }
  }

  @override
  Future<void> writeKey(String alias, Uint8List key) async {
    final file = await _fileFor(alias);
    // Temp file + rename, like `ConversationStore`'s envelope writes: a process
    // death mid-write must not leave a half-written key, because a truncated
    // key makes every existing conversation permanently unreadable.
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(key, flush: true);
    try {
      await temp.rename(file.path);
    } on FileSystemException {
      // Rename can fail if a previous temp file is still open somewhere; the
      // direct write is worse but still better than losing the write entirely.
      await file.writeAsBytes(key, flush: true);
      await _deleteQuietly(temp);
    }
  }

  @override
  Future<void> deleteKey(String alias) async {
    final file = await _fileFor(alias);
    await _deleteQuietly(file);
    await _deleteQuietly(File('${file.path}.tmp'));
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error) {
      debugPrint('FINN_SECURE_KEY delete failed for ${file.path}: '
          '${error.message}');
    }
  }

  Future<File> _fileFor(String alias) async {
    final directory = await _resolveDirectory();
    final safe = alias.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
    return File('${directory.path}/$_filePrefix$safe');
  }

  Future<Directory> _resolveDirectory() async {
    final directory = await _locateDirectory();
    // Applies to the injected directory too: `filesDir` is created by the
    // system, but a nested or test directory need not exist yet, and a write
    // into a missing directory would otherwise throw PathNotFoundException.
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> _locateDirectory() async {
    final override = directoryOverride;
    if (override != null) return override;
    final cached = _cachedDirectory;
    if (cached != null) return cached;

    var path = ohosSandboxFilesDir;
    try {
      final native = await _pathChannel.invokeMethod<String>(
        'getApplicationSupportPath',
      );
      if (native != null && native.isNotEmpty) path = native;
    } on PlatformException catch (error) {
      debugPrint('FINN_SECURE_KEY path_provider unavailable, using the '
          'documented sandbox path: ${error.code} ${error.message}');
    } on MissingPluginException {
      debugPrint('FINN_SECURE_KEY path_provider unavailable, using the '
          'documented sandbox path');
    }

    return _cachedDirectory = Directory(path);
  }
}
