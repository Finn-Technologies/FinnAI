import { BinaryMessenger, MethodCall, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';

const CHANNEL_NAME = 'plugins.flutter.io/path_provider';

export class PathProviderPlugin {
  private channel: MethodChannel | null = null;
  private context: common.Context | null = null;

  constructor(context: common.Context) {
    this.context = context;
  }

  setup(messenger: BinaryMessenger) {
    this.channel = new MethodChannel(messenger, CHANNEL_NAME);
    this.channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult) => {
        const filesDir = this.context?.filesDir ?? '/data/storage/el2/base/haps/entry/files';
        const cacheDir = this.context?.cacheDir ?? '/data/storage/el2/base/haps/entry/cache';
        const tempDir = this.context?.tempDir ?? cacheDir;

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
            result.success([cacheDir]);
            break;
          case 'getExternalStorageDirectories':
          case 'getExternalStoragePaths':
            result.success([filesDir]);
            break;
          default:
            result.notImplemented();
            break;
        }
      }
    });
  }
}
