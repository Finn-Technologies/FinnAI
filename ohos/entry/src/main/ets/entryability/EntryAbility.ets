import { FlutterAbility, FlutterEngine, MethodCall, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);

    const channel = new MethodChannel(flutterEngine.getDartExecutor(), 'plugins.flutter.io/path_provider');
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult) => {
        const filesDir = this.context.filesDir;
        const cacheDir = this.context.cacheDir;
        const tempDir = this.context.tempDir ?? cacheDir;

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
