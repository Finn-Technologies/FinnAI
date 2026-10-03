/*
 * `miguelruivo.flutter.plugins.filepicker` for OpenHarmony.
 *
 * The Dart side calls `pickFiles(type: FileType.custom, allowedExtensions: [...])`,
 * which becomes a method call named `custom` with
 * `{ allowMultipleSelection, withData, compressionQuality, allowedExtensions }`
 * and expects a **JSON array** of `{ name, path, size, bytes, identifier }`
 * maps. Returning `[]` is how a cancelled picker is signalled (file_picker maps
 * that to `null`).
 *
 * HarmonyOS's DocumentViewPicker filters by suffix (`fileSuffixFilters`) and
 * hands back `file://` URIs, so each selection is copied into the app cache and
 * measured with fs.stat.
 */

import { BinaryMessenger, MethodCall, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

const CHANNEL = 'miguelruivo.flutter.plugins.filepicker';
const TAG = 'FinnFilePicker';

interface PickedFile {
  name: string;
  path: string;
  size: number;
  bytes: null;
  identifier: string;
}

export class FilePickerPlugin {
  static register(messenger: BinaryMessenger, context: common.UIAbilityContext): void {
    const channel = new MethodChannel(messenger, CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        FilePickerPlugin.handle(call, result, context);
      },
    });
  }

  static handle(
    call: MethodCall,
    result: MethodResult,
    context: common.UIAbilityContext,
  ): void {
    // The method name *is* the FileType: any/media/image/video/audio/custom.
    if (call.method !== 'custom' && call.method !== 'any' && call.method !== 'image') {
      result.notImplemented();
      return;
    }

    const allowed = call.argument('allowedExtensions') as string[] | null;
    const allowMultiple = (call.argument('allowMultipleSelection') as boolean | null) ?? false;

    const viewPicker = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSelectOptions();
    // file_picker sends extensions without the dot; HarmonyOS wants them with.
    const filters: string[] = [];
    if (allowed !== null && allowed !== undefined) {
      for (const ext of allowed) {
        filters.push(ext.startsWith('.') ? ext : `.${ext}`);
      }
    }
    if (call.method === 'image') {
      // For FileType.image the Dart side sends no filters; restrict to images so
      // the picker does not offer videos or arbitrary documents.
      filters.push('image/*');
    }
    if (filters.length > 0) {
      options.fileSuffixFilters = filters;
    }
    options.maxSelectNumber = allowMultiple ? 100 : 1;

    viewPicker.select(options).then((uris: string[]): void => {
      if (uris === undefined || uris.length === 0) {
        result.success([]);
        return;
      }
      const picked: PickedFile[] = [];
      try {
        for (const uri of uris) {
          picked.push(FilePickerPlugin.copyIntoCache(context, uri));
        }
      } catch (error) {
        const biz = error as BusinessError;
        result.error('copy_failed', `${biz.code}: ${biz.message}`, null);
        return;
      }
      result.success(picked);
    }).catch((error: BusinessError): void => {
      if (error.code === 13900012) {
        result.success([]);
        return;
      }
      console.error(`${TAG} select failed: ${error.code} ${error.message}`);
      result.error('pick_failed', `${error.code}: ${error.message}`, null);
    });
  }

  private static copyIntoCache(context: common.UIAbilityContext, uri: string): PickedFile {
    const name = FilePickerPlugin.displayName(uri);
    const target = `${context.cacheDir}/finn_file_${Date.now()}_${name}`;
    const srcFd = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    try {
      const dstFd = fileIo.openSync(
        target, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      try {
        fileIo.copyFileSync(srcFd.fd, dstFd.fd);
      } finally {
        fileIo.closeSync(dstFd.fd);
      }
    } finally {
      fileIo.closeSync(srcFd.fd);
    }
    let size = 0;
    try {
      size = fileIo.statSync(target).size;
    } catch (_) {
      // Unknown size is acceptable: PlatformFile.size is only used for display.
    }
    return {
      name: name,
      path: target,
      size: size,
      // withData is false in FinnAI, which reads the file from `path` instead.
      bytes: null,
      identifier: uri,
    };
  }

  private static displayName(uri: string): string {
    const decoded = decodeURIComponent(uri);
    const slash = decoded.lastIndexOf('/');
    return slash >= 0 ? decoded.substring(slash + 1) : decoded;
  }
}