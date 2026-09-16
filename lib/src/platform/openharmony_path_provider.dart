import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Implements [PathProviderPlatform] for OpenHarmony environments.
class OpenHarmonyPathProvider extends PathProviderPlatform {
  static const MethodChannel _channel =
      MethodChannel('plugins.flutter.io/path_provider');

  static void registerIfNeeded() {
    if (Platform.isLinux ||
        (!Platform.isAndroid &&
            !Platform.isIOS &&
            !Platform.isMacOS &&
            !Platform.isWindows)) {
      if (Directory('/data/storage/el2').existsSync() ||
          Directory('/data/storage/el1').existsSync() ||
          Directory('/data/app/el2').existsSync()) {
        PathProviderPlatform.instance = OpenHarmonyPathProvider();
      }
    }
  }

  @override
  Future<String?> getTemporaryPath() async {
    try {
      final path = await _channel.invokeMethod<String>('getTemporaryPath');
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}
    return '/data/storage/el2/base/haps/entry/cache';
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    try {
      final path =
          await _channel.invokeMethod<String>('getApplicationSupportPath');
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}
    return '/data/storage/el2/base/haps/entry/files';
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    try {
      final path =
          await _channel.invokeMethod<String>('getApplicationDocumentsPath');
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}
    return '/data/storage/el2/base/haps/entry/files';
  }

  @override
  Future<String?> getLibraryPath() async {
    try {
      final path = await _channel.invokeMethod<String>('getLibraryPath');
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}
    return '/data/storage/el2/base/haps/entry/files';
  }

  @override
  Future<String?> getExternalStoragePath() async {
    try {
      final path =
          await _channel.invokeMethod<String>('getExternalStoragePath');
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}
    return '/data/storage/el2/base/haps/entry/files';
  }

  @override
  Future<List<String>?> getExternalCachePaths() async {
    try {
      final paths =
          await _channel.invokeListMethod<String>('getExternalCachePaths');
      if (paths != null && paths.isNotEmpty) return paths;
    } catch (_) {}
    return const ['/data/storage/el2/base/haps/entry/cache'];
  }

  @override
  Future<List<String>?> getExternalStoragePaths(
      {StorageDirectory? type}) async {
    try {
      final paths =
          await _channel.invokeListMethod<String>('getExternalStoragePaths');
      if (paths != null && paths.isNotEmpty) return paths;
    } catch (_) {}
    return const ['/data/storage/el2/base/haps/entry/files'];
  }

  @override
  Future<String?> getDownloadsPath() async {
    try {
      final path = await _channel.invokeMethod<String>('getDownloadsPath');
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}
    return '/data/storage/el2/base/haps/entry/files';
  }
}
