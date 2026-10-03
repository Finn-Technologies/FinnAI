/*
 * `plugins.flutter.io/path_provider` for OpenHarmony.
 *
 * `path_provider` ships no OHOS plugin, so its Dart side falls back to the
 * default method-channel implementation. `OpenHarmonyPathProvider` in
 * lib/src/platform/ reads this channel first and falls back to hard-coded
 * sandbox paths, so every getter must be answered with the *real* context
 * directory.
 */

import { BinaryMessenger, MethodCall, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';

const CHANNEL = 'plugins.flutter.io/path_provider';

export class PathProviderPlugin {
  static register(messenger: BinaryMessenger, context: common.UIAbilityContext): void {
    const channel = new MethodChannel(messenger, CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        PathProviderPlugin.handle(call, result, context);
      },
    });
  }

  static handle(
    call: MethodCall,
    result: MethodResult,
    context: common.UIAbilityContext,
  ): void {
    // tempDir is API 15+; cacheDir is its documented equivalent below that.
    const tempDir = context.tempDir !== undefined ? context.tempDir : context.cacheDir;
    const filesDir = context.filesDir;
    switch (call.method) {
      case 'getTemporaryDirectory':
      case 'getTemporaryPath':
        result.success(tempDir);
        break;
      case 'getApplicationDocumentsDirectory':
      case 'getApplicationDocumentsPath':
      case 'getApplicationSupportDirectory':
      case 'getApplicationSupportPath':
      case 'getLibraryDirectory':
      case 'getLibraryPath':
      case 'getExternalStorageDirectory':
      case 'getExternalStoragePath':
        result.success(filesDir);
        break;
      case 'getExternalCacheDirectories':
      case 'getExternalCachePaths':
        result.success([context.cacheDir]);
        break;
      case 'getExternalStorageDirectories':
      case 'getExternalStoragePaths':
        result.success([filesDir]);
        break;
      case 'getDownloadsPath':
        // HarmonyOS has no "Downloads" directory an app may name, and the
        // sandbox is the only writable place an app owns. Answering the
        // files dir keeps any default file location inside the sandbox.
        result.success(filesDir);
        break;
      default:
        result.notImplemented();
        break;
    }
  }
}