/*
 * `finn_ai/share_file` for OpenHarmony — the export/share path used by
 * Settings > Data ("Export my data") and You > Privacy.
 *
 * HarmonyOS has no cross-app share intent equivalent to Android's
 * ACTION_SEND: sharing out of the sandbox means handing the user a system file
 * picker and letting them put the file where they want it. That is what
 * `DocumentViewPicker.save()` does, so the native half of
 * `HomeScreenService.shareFile` becomes "pick a destination and copy there".
 *
 * The method name and argument shape mirror the Kotlin implementation on
 * Android so the Dart side needs no branch.
 */

import { BinaryMessenger, MethodCall, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

const CHANNEL = 'finn_ai/share_file';
const TAG = 'FinnShare';

export class SharePlugin {
  static register(messenger: BinaryMessenger, context: common.UIAbilityContext): void {
    const channel = new MethodChannel(messenger, CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        SharePlugin.handle(call, result, context);
      },
    });
  }

  static handle(
    call: MethodCall,
    result: MethodResult,
    context: common.UIAbilityContext,
  ): void {
    if (call.method !== 'shareFile') {
      result.notImplemented();
      return;
    }
    const sourcePath = call.argument('path') as string;
    const suggestedName = call.argument('name') as string | null;
    const mimeType = call.argument('mimeType') as string | null;

    if (typeof sourcePath !== 'string' || sourcePath.length === 0) {
      result.error('bad_argument', 'path is required', null);
      return;
    }
    if (!fileIo.accessSync(sourcePath)) {
      result.error('not_found', `${sourcePath} does not exist`, null);
      return;
    }

    const viewPicker = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [SharePlugin.suggestedName(suggestedName, sourcePath)];
    const suffix = SharePlugin.extensionFor(mimeType);
    if (suffix !== null) {
      options.defaultFilePathUri = `file://${suffix}`;
    }

    viewPicker.save(options).then((uris: string[]): void => {
      if (uris === undefined || uris.length === 0) {
        result.success(false);
        return;
      }
      SharePlugin.copyTo(sourcePath, uris[0]).then((): void => {
        result.success(true);
      }).catch((error: BusinessError): void => {
        result.error('copy_failed', `${error.code}: ${error.message}`, null);
      });
    }).catch((error: BusinessError): void => {
      if (error.code === 13900012) {
        result.success(false);
        return;
      }
      console.error(`${TAG} save failed: ${error.code} ${error.message}`);
      result.error('save_failed', `${error.code}: ${error.message}`, null);
    });
  }

  private static copyTo(sourcePath: string, destinationUri: string): Promise<void> {
    return new Promise<void>((resolve: () => void, reject: (error: BusinessError) => void): void => {
      const srcFd = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
      try {
        const dstFd = fileIo.openSync(
          destinationUri,
          fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC,
        );
        try {
          fileIo.copyFileSync(srcFd.fd, dstFd.fd);
          fileIo.fsyncSync(dstFd.fd);
        } finally {
          fileIo.closeSync(dstFd.fd);
        }
      } catch (error) {
        reject(error as BusinessError);
        return;
      } finally {
        fileIo.closeSync(srcFd.fd);
      }
      resolve();
    });
  }

  private static suggestedName(suggested: string | null, sourcePath: string): string {
    if (suggested !== null && suggested !== undefined && suggested.length > 0) {
      return suggested;
    }
    const slash = sourcePath.lastIndexOf('/');
    return slash >= 0 ? sourcePath.substring(slash + 1) : sourcePath;
  }

  private static extensionFor(mimeType: string | null): string | null {
    if (mimeType === 'application/json') return '.json';
    if (mimeType === 'text/markdown' || mimeType === 'text/plain') return '.txt';
    return null;
  }
}