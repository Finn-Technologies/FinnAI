import 'package:flutter/services.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'platform_target.dart';

/// Implements [PathProviderPlatform] for OpenHarmony environments.
///
/// `path_provider` has no OHOS implementation in the plugin registry, so the
/// generated [GeneratedPluginRegistrant] is empty and the plugin's default
/// method-channel implementation is used instead. `EntryAbility.ets` answers the
/// same `plugins.flutter.io/path_provider` channel with the sandbox's real
/// directories; every getter here consults that channel first and only falls
/// back to a hard-coded path if the native side is missing.
///
/// The fallbacks match HarmonyOS's documented layout for an `entry` module in
/// the `el2` sandbox: `<filesDir>` is `/data/storage/el2/base/haps/entry/files`
/// and the cache directory is its sibling `cache`.
class OpenHarmonyPathProvider extends PathProviderPlatform {
  static const MethodChannel _channel =
      MethodChannel('plugins.flutter.io/path_provider');

  static const _files = '/data/storage/el2/base/haps/entry/files';
  static const _cache = '/data/storage/el2/base/haps/entry/cache';

  static void registerIfNeeded() {
    if (isOpenHarmony) {
      PathProviderPlatform.instance = OpenHarmonyPathProvider();
    }
  }

  @override
  Future<String?> getTemporaryPath() async {
    try {
      final path = await _channel.invokeMethod<String>('getTemporaryPath');
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}
    return _cache;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    try {
      final path =
          await _channel.invokeMethod<String>('getApplicationSupportPath');
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}
    return _files;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    try {
      final path =
          await _channel.invokeMethod<String>('getApplicationDocumentsPath');
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}
    return _files;
  }

  @override
  Future<String?> getLibraryPath() async {
    try {
      final path = await _channel.invokeMethod<String>('getLibraryPath');
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}
    return _files;
  }

  @override
  Future<String?> getExternalStoragePath() async {
    try {
      final path =
          await _channel.invokeMethod<String>('getExternalStoragePath');
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}
    return _files;
  }

  @override
  Future<List<String>?> getExternalCachePaths() async {
    try {
      final paths =
          await _channel.invokeListMethod<String>('getExternalCachePaths');
      if (paths != null && paths.isNotEmpty) return paths;
    } catch (_) {}
    return const [_cache];
  }

  @override
  Future<List<String>?> getExternalStoragePaths(
      {StorageDirectory? type}) async {
    try {
      final paths =
          await _channel.invokeListMethod<String>('getExternalStoragePaths');
      if (paths != null && paths.isNotEmpty) return paths;
    } catch (_) {}
    return const [_files];
  }

  @override
  Future<String?> getDownloadsPath() async {
    try {
      final path = await _channel.invokeMethod<String>('getDownloadsPath');
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}
    return _files;
  }
}
